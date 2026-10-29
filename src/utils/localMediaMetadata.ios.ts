/**
 * iOS 本地媒体元数据实现
 *
 * 上游依赖 react-native-local-media-metadata（只有 Android 实现），
 * 已在 react-native.config.js 里对 ios 关闭 autolinking。
 * iOS 侧改由 LXMobileNative 里的 LXMediaMetadataModule（AVFoundation）提供，
 * 原生模块名沿用 LocalMediaMetadata，接口与 Android 版保持一致。
 *
 * 已知能力差异（见风险清单）：
 *   - writeMetadata / writePic / writeLyric：iOS 无法原地改写音频标签，降级为 no-op
 *   - 内嵌歌词（ID3 USLT）：iOS 没有稳定的通用读取路径，只能读同名 .lrc
 */

import { NativeModules } from 'react-native'
import { temporaryDirectoryPath, readDir, unlink, extname } from '@/utils/fs'

export interface MusicMetadata {
  albumName: string
  singer: string
  name: string
}

export interface MusicMetadataFull {
  type: 'mp3' | 'flac' | 'ogg' | 'wav'
  bitrate: string
  interval: number
  size: number
  ext: 'mp3' | 'flac' | 'ogg' | 'wav'
  albumName: string
  singer: string
  name: string
}

const LocalMediaMetadata = NativeModules.LocalMediaMetadata as {
  readMetadata: (filePath: string) => Promise<MusicMetadataFull | null>
  writeMetadata: (filePath: string, metadata: MusicMetadata, isOverwrite: boolean) => Promise<void>
  readPic: (filePath: string, picDir: string) => Promise<string>
  writePic: (filePath: string, picPath: string) => Promise<void>
  readLyric: (filePath: string, isReadLrcFile: boolean) => Promise<string>
  writeLyric: (filePath: string, lyric: string) => Promise<void>
} | undefined

const requireModule = () => {
  if (!LocalMediaMetadata) {
    throw new Error('LocalMediaMetadata 原生模块未链接，请重新执行 pod install 并重新构建')
  }
  return LocalMediaMetadata
}

export const readMetadata = async(filePath: string): Promise<MusicMetadataFull | null> => {
  return requireModule().readMetadata(filePath)
}

// 与上游行为一致：同一文件的写入串行化，避免并发写坏
const writeQueue = new Map<string, Promise<void>>()
const waitQueuePromise = async(key: string, run: () => Promise<void>): Promise<void> => {
  const previous = writeQueue.get(key) ?? Promise.resolve()
  const next = previous.finally(run).finally(() => {
    if (writeQueue.get(key) === next) writeQueue.delete(key)
  })
  writeQueue.set(key, next)
  return next
}

export const writeMetadata = async(filePath: string, metadata: MusicMetadata, isOverwrite = false): Promise<void> => {
  return waitQueuePromise(filePath, async() => { await requireModule().writeMetadata(filePath, metadata, isOverwrite) })
}

export const writePic = async(filePath: string, picPath: string): Promise<void> => {
  return waitQueuePromise(filePath, async() => { await requireModule().writePic(filePath, picPath) })
}

export const writeLyric = async(filePath: string, lyric: string): Promise<void> => {
  return waitQueuePromise(filePath, async() => { await requireModule().writeLyric(filePath, lyric) })
}

export const readLyric = async(filePath: string, isReadLrcFile: boolean = true): Promise<string> => {
  return requireModule().readLyric(filePath, isReadLrcFile)
}

let cleared = false
const picCachePath = temporaryDirectoryPath + '/local-media-metadata'

const clearPicCache = async() => {
  await unlink(picCachePath)
  cleared = true
}

export const readPic = async(filePath: string): Promise<string> => {
  if (!cleared) await clearPicCache()
  return requireModule().readPic(filePath, picCachePath)
}

export const scanAudioFiles = async(dirPath: string) => {
  const files = await readDir(dirPath)
  return files.filter(file => {
    // iOS 侧 readDir 会按扩展名推断 mimeType，audio/* 与 ogg 都要保留
    if (file.mimeType?.startsWith('audio/')) return true
    if (extname(file?.name ?? '') === 'ogg') return true
    return false
  })
}
