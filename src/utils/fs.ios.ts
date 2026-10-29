/**
 * iOS 文件系统实现
 *
 * 为什么需要这个文件：
 *   上游的 src/utils/fs.ts 依赖 react-native-file-system（lyswhut 自研 fork），
 *   该包只有 Android 原生实现，iOS 上无法使用，已在 react-native.config.js 里
 *   对 ios 关闭 autolinking。
 *
 * 替换方案：用 react-native-fs（RNFS，两端都支持）重写同一套接口。
 *   Metro 会按平台后缀优先解析 fs.ios.ts，因此 fs.ts 保持原样即可，
 *   Android 行为完全不受影响。
 *
 * 接口契约必须与 fs.ts 严格一致（同样的导出名、同样的返回结构），
 * 否则 @/utils/fs 的调用方会编译不过或运行时报错。
 */

import RNFS from 'react-native-fs'
import { NativeModules, Platform } from 'react-native'
import { Buffer } from '@craftzdog/react-native-buffer'
import { gzip, ungzip } from 'pako'

export interface FileType {
  name: string
  path: string
  isDirectory: boolean
  isFile: boolean
  lastModified: number
  canRead: boolean
  data: string
  mimeType: string
  size: number
}

export type Encoding = 'base64' | 'utf8'
export type HashAlgorithm = 'md5' | 'sha1' | 'sha224' | 'sha256' | 'sha384' | 'sha512'

/**
 * iOS 目录映射：
 *   - CacheDir  -> NSCachesDirectory（系统可清理，对应 Android getCacheDir）
 *   - DocumentDir -> NSDocumentDirectory（持久化，对应 Android filesDir）
 *   - SDCardDir -> iOS 没有外置存储，退化为 Documents，避免调用方拿到 undefined
 */
export const Dirs: {
  CacheDir: string
  DocumentDir: string
  MainBundleDir: string
  SDCardDir: string
} = {
  CacheDir: RNFS.CachesDirectoryPath,
  DocumentDir: RNFS.DocumentDirectoryPath,
  MainBundleDir: RNFS.MainBundlePath,
  SDCardDir: RNFS.DocumentDirectoryPath,
}

export const extname = (name: string) => name.lastIndexOf('.') > 0 ? name.substring(name.lastIndexOf('.') + 1) : ''

export const temporaryDirectoryPath = Dirs.CacheDir
export const externalStorageDirectoryPath = Dirs.SDCardDir
export const privateStorageDirectoryPath = Dirs.DocumentDir

/// iOS 没有「本地音乐目录」的概念，这里约定一个固定目录，
/// 用户通过「文件」App 把音乐放进 洛雪音乐/Documents/Music 即可被扫描到。
const LOCAL_MUSIC_DIR = `${Dirs.DocumentDir}/Music`

const MIME_BY_EXT: Record<string, string> = {
  mp3: 'audio/mpeg',
  flac: 'audio/flac',
  m4a: 'audio/mp4',
  aac: 'audio/aac',
  wav: 'audio/wav',
  ogg: 'audio/ogg',
  opus: 'audio/opus',
  ape: 'audio/x-ape',
  wma: 'audio/x-ms-wma',
  jpg: 'image/jpeg',
  jpeg: 'image/jpeg',
  png: 'image/png',
  webp: 'image/webp',
  gif: 'image/gif',
  txt: 'text/plain',
  lrc: 'text/plain',
  json: 'application/json',
  js: 'application/javascript',
  lxmc: 'application/octet-stream',
}

const mimeTypeOf = (name: string) => MIME_BY_EXT[extname(name).toLowerCase()] ?? 'application/octet-stream'

/**
 * RNFS 的 stat / readDir 返回值形状。
 * 这里不直接引用 RNFS.StatResult：react-native-fs 的 d.ts 只有命名导出，
 * 通过默认导入拿到的值不能当命名空间访问其类型，写成内联结构更稳。
 */
interface RNFSStatLike {
  name?: string
  size?: number | string
  mtime?: Date | number
  isFile?: (() => boolean) | boolean
  isDirectory?: (() => boolean) | boolean
}

const toFileType = (path: string, info: RNFSStatLike): FileType => {
  const name = info.name ?? path.split('/').pop() ?? ''
  const isDirectory = typeof info.isDirectory === 'function' ? info.isDirectory() : Boolean(info.isDirectory)
  const isFile = typeof info.isFile === 'function' ? info.isFile() : Boolean(info.isFile)
  const lastModified = info.mtime ? new Date(info.mtime).getTime() : 0
  return {
    name,
    path,
    isDirectory,
    isFile,
    lastModified,
    canRead: true,
    data: '',
    mimeType: isDirectory ? 'inode/directory' : mimeTypeOf(name),
    size: Number(info.size ?? 0),
  }
}

export const getExternalStoragePaths = async(_is_removable?: boolean): Promise<string[]> => [Dirs.DocumentDir]

/**
 * 「选择并持久化授权目录」是 Android SAF 的概念，iOS 没有对应机制。
 * 这里退化为固定的 Documents/Music 目录：用户通过「文件」App 拖入音频即可。
 */
export const selectManagedFolder = async(_isPersist: boolean = false): Promise<FileType> => {
  if (!await RNFS.exists(LOCAL_MUSIC_DIR)) {
    await RNFS.mkdir(LOCAL_MUSIC_DIR)
  }
  const info = await RNFS.stat(LOCAL_MUSIC_DIR)
  return toFileType(LOCAL_MUSIC_DIR, info)
}

/**
 * 选择文件：走 LXDocumentPicker（UIDocumentPickerViewController），
 * 这是 iOS 原生的文件选择器，等价于 Android 的 ACTION_OPEN_DOCUMENT。
 *
 * 注意返回值约定（与 Android openDocument 一致）：
 *   - `data` 字段存放的是**文件路径**，不是文件内容。
 *     调用方（ChoosePath）会用 file.data 做 unlink / 扩展名判断 / 回传选中路径，
 *     这里如果返回文件内容会直接把逻辑打断。
 *   - 传了 toPath 时，把临时副本搬到 toPath 并返回该路径。
 */
export const selectFile = async(options: {
  mimeTypes?: string[]
  extTypes?: string[]
  multi?: boolean
  toPath?: string
  encoding?: Encoding
}): Promise<FileType> => {
  const picker = NativeModules.LXDocumentPickerModule
  if (!picker) throw new Error('文件选择器不可用')

  const result = await picker.pick({
    extTypes: options.extTypes ?? [],
    mimeTypes: options.mimeTypes ?? [],
    multi: options.multi ?? false,
  }) as { name: string, path: string, size: number } | null
  if (!result) throw new Error('canceled')

  let finalPath = result.path
  if (options.toPath) {
    // 选择器 asCopy 给的是临时目录里的副本，搬到调用方指定的位置
    const parent = options.toPath.substring(0, options.toPath.lastIndexOf('/'))
    if (parent && !await RNFS.exists(parent)) await RNFS.mkdir(parent)
    if (await RNFS.exists(options.toPath)) await RNFS.unlink(options.toPath)
    await RNFS.moveFile(result.path, options.toPath)
    finalPath = options.toPath
  }

  const info = await RNFS.stat(finalPath)
  return {
    ...toFileType(finalPath, info),
    name: result.name,
    data: finalPath,
  }
}

/// iOS 没有 URI 持久授权，删除操作无实际意义
export const removeManagedFolder = async(_path: string) => {}

export const getManagedFolders = async(): Promise<string[]> => {
  return await RNFS.exists(LOCAL_MUSIC_DIR) ? [LOCAL_MUSIC_DIR] : []
}

export const getPersistedUriList = async(): Promise<string[]> => getManagedFolders()

export const readDir = async(path: string): Promise<FileType[]> => {
  const items = await RNFS.readDir(path)
  return items.map(item => toFileType(item.path, item))
}

export const unlink = async(path: string): Promise<boolean> => {
  // RNFS.unlink 在路径不存在时会抛错，这里对齐 Android 的「尽力删除」
  try {
    if (await RNFS.exists(path)) await RNFS.unlink(path)
    return true
  } catch {
    return false
  }
}

export const mkdir = async(path: string): Promise<FileType> => {
  await RNFS.mkdir(path)
  const info = await RNFS.stat(path)
  return toFileType(path, info)
}

export const stat = async(path: string): Promise<FileType> => {
  const info = await RNFS.stat(path)
  const result = toFileType(path, info)
  // RNFS 不返回权限位，用可读性探测代替 canRead
  try {
    await RNFS.read(path, 1, 0, 'utf8')
    result.canRead = true
  } catch {
    result.canRead = result.isDirectory
  }
  return result
}

export const hash = async(path: string, algorithm: HashAlgorithm): Promise<string> => {
  // RNFS.hash 只支持 md5 / sha1 / sha256 / sha512
  if (algorithm === 'sha224' || algorithm === 'sha384') {
    throw new Error(`iOS 不支持 ${algorithm} 文件摘要`)
  }
  return RNFS.hash(path, algorithm)
}

export const readFile = async(path: string, encoding?: Encoding): Promise<string> => {
  return RNFS.readFile(path, encoding ?? 'utf8')
}

export const moveFile = async(fromPath: string, toPath: string): Promise<boolean> => {
  await RNFS.moveFile(fromPath, toPath)
  return true
}

export const rename = async(path: string, name: string): Promise<boolean> => {
  const parent = path.substring(0, path.lastIndexOf('/'))
  await RNFS.moveFile(path, `${parent}/${name}`)
  return true
}

export const existsFile = async(path: string): Promise<boolean> => RNFS.exists(path)

export const writeFile = async(path: string, data: string, encoding?: Encoding): Promise<void> => {
  await RNFS.writeFile(path, data, encoding ?? 'utf8')
}

export const appendFile = async(path: string, data: string, encoding?: Encoding): Promise<void> => {
  await RNFS.appendFile(path, data, encoding ?? 'utf8')
}

/// 文件级 gzip：RNFS 没有内置能力，读入内存后用 pako 处理
export const gzipFile = async(fromPath: string, toPath: string): Promise<void> => {
  const base64 = await RNFS.readFile(fromPath, 'base64')
  const compressed = gzip(Buffer.from(base64, 'base64'))
  await RNFS.writeFile(toPath, Buffer.from(compressed).toString('base64'), 'base64')
}

export const unGzipFile = async(fromPath: string, toPath: string): Promise<void> => {
  const base64 = await RNFS.readFile(fromPath, 'base64')
  const decompressed = ungzip(Buffer.from(base64, 'base64'))
  await RNFS.writeFile(toPath, Buffer.from(decompressed).toString('base64'), 'base64')
}

/**
 * 字符串级 gzip。
 * 返回 base64(gzip(bytes))，与 Android FileSystem.gzipString 完全一致，
 * 同步功能依赖这个格式与桌面端互通。
 */
export const gzipString = async(data: string, encoding?: Encoding): Promise<string> => {
  const raw = encoding === 'base64' ? Buffer.from(data, 'base64') : Buffer.from(data, 'utf8')
  return Buffer.from(gzip(raw)).toString('base64')
}

export const unGzipString = async(data: string, encoding?: Encoding): Promise<string> => {
  const decompressed = ungzip(Buffer.from(data, 'base64'))
  const buffer = Buffer.from(decompressed)
  return encoding === 'base64' ? buffer.toString('base64') : buffer.toString('utf8')
}

export const downloadFile = (url: string, path: string, options: Omit<RNFS.DownloadFileOptions, 'fromUrl' | 'toFile'> = {}) => {
  if (!options.headers) {
    // 与 Android 侧保持同一个 UA：部分音源会按 UA 返回不同的音频地址
    options.headers = {
      'User-Agent': 'Mozilla/5.0 (Linux; Android 10; Pixel 3) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/79.0.3945.79 Mobile Safari/537.36',
    }
  }
  return RNFS.downloadFile({
    fromUrl: url,
    toFile: path,
    ...options,
  })
}

export const stopDownload = (jobId: number) => {
  RNFS.stopDownload(jobId)
}

/// 供调用方判断运行平台（fs.ts 里没有，但 iOS 侧实现常用）
export const isIOSPlatform = Platform.OS === 'ios'
