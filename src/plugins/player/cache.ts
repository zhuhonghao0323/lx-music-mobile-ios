/**
 * 播放缓存
 *
 * 背景：react-native-track-player 的缓存 API（isCached / getCacheSize / clearCache）
 * 在 v4 里只有 Android 原生实现，iOS 的 RNTrackPlayerBridge 里根本没有导出这三个方法
 * （已核对 fork 的 ios/RNTrackPlayer/RNTrackPlayerBridge.m）。
 * 直接调用会抛 "isCached is not a function"，缓存设置页也会直接崩。
 *
 * iOS 替代方案：自建文件级缓存。
 *   - 命中缓存：用 file:// 路径播放，和 Android 的磁盘缓存效果一致
 *   - 未命中：先用原始 URL 流式播放（保证起播速度与 Android 一致，不额外等待），
 *     同时后台把整首歌下载进缓存，下次播放即走本地
 *   - 容量上限沿用设置项 player.cacheSize，超出后按「最久未访问」淘汰
 *
 * Android 侧完全不受影响：所有导出在非 iOS 平台都直接转调 TrackPlayer 的原生实现。
 */

import { Platform } from 'react-native'
import TrackPlayer from 'react-native-track-player'
import RNFS from 'react-native-fs'
import { stringMd5 } from 'react-native-quick-md5'
import { privateStorageDirectoryPath } from '@/utils/fs'
import settingState from '@/store/setting/state'

const isIOS = Platform.OS === 'ios'

/// 与 Android 侧 RNTP 的缓存目录保持一致（见 utils.ts 的 migratePlayerCache）
const CACHE_DIR = `${privateStorageDirectoryPath}/TrackPlayer`
const PART_SUFFIX = '.part'

/// 同一时间最多并行下载几首，避免把移动网络和 IO 打满
const MAX_CONCURRENT_DOWNLOADS = 2
/// 正在下载的 URL，防止同一首歌被重复排队
const inFlight = new Set<string>()
let activeDownloads = 0
const waiting: Array<() => void> = []

const defaultUserAgent = 'Mozilla/5.0 (Linux; Android 10; Pixel 3) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/79.0.3945.79 Mobile Safari/537.36'

const extFromUrl = (url: string) => {
  const matched = /\.(mp3|flac|m4a|aac|wav|ogg|opus|ape|wma)(?:\?|#|$)/i.exec(url)
  return matched ? `.${matched[1].toLowerCase()}` : '.mp3'
}

const cachePathOf = (url: string) => `${CACHE_DIR}/${stringMd5(url)}${extFromUrl(url)}`

const ensureDir = async() => {
  if (!await RNFS.exists(CACHE_DIR)) await RNFS.mkdir(CACHE_DIR)
}

const fileSizeOf = async(path: string): Promise<number> => {
  try {
    const info = await RNFS.stat(path)
    return Number(info.size) || 0
  } catch {
    return 0
  }
}

const iosIsCached = async(url: string): Promise<boolean> => {
  if (!url.startsWith('http')) return false
  return await fileSizeOf(cachePathOf(url)) > 0
}

const iosGetCacheSize = async(): Promise<number> => {
  if (!await RNFS.exists(CACHE_DIR)) return 0
  const files = await RNFS.readDir(CACHE_DIR)
  let total = 0
  for (const file of files) {
    if (!file.isFile()) continue
    total += Number(file.size) || 0
  }
  return total
}

const iosClearCache = async(): Promise<void> => {
  if (!await RNFS.exists(CACHE_DIR)) return
  const files = await RNFS.readDir(CACHE_DIR)
  await Promise.all(files.map(async file => {
    await RNFS.unlink(file.path).catch(() => {})
  }))
}

/// 设置里的 cacheSize 以 MB 为单位
const maxCacheBytes = () => {
  const size = Number(settingState.setting['player.cacheSize'])
  return (Number.isFinite(size) && size > 0 ? size : 1024) * 1024 * 1024
}

/// 超出容量上限时，按访问时间从旧到新删除，直到回到上限的 90%
const enforceCacheLimit = async() => {
  try {
    const limit = maxCacheBytes()
    if (!await RNFS.exists(CACHE_DIR)) return
    const files = await RNFS.readDir(CACHE_DIR)
    const entries = await Promise.all(files
      .filter(file => file.isFile() && !file.name.endsWith(PART_SUFFIX))
      .map(async file => ({
        path: file.path,
        size: Number(file.size) || 0,
        mtime: new Date(file.mtime as unknown as string).getTime() || 0,
      })))

    let total = entries.reduce((sum, entry) => sum + entry.size, 0)
    if (total <= limit) return

    entries.sort((a, b) => a.mtime - b.mtime)
    const target = limit * 0.9
    for (const entry of entries) {
      if (total <= target) break
      await RNFS.unlink(entry.path).catch(() => {})
      total -= entry.size
    }
  } catch {
    // 缓存清理失败不应该影响播放
  }
}

const acquireSlot = async() => {
  if (activeDownloads < MAX_CONCURRENT_DOWNLOADS) {
    activeDownloads += 1
    return
  }
  await new Promise<void>(resolve => waiting.push(resolve))
  activeDownloads += 1
}

const releaseSlot = () => {
  activeDownloads -= 1
  const next = waiting.shift()
  if (next) next()
}

/**
 * 后台预取：把整首歌下载进缓存目录。
 * 失败只影响「下次是否命中缓存」，不影响当前播放，所以全程吞掉异常。
 */
const prefetch = async(url: string) => {
  if (!url.startsWith('http') || inFlight.has(url)) return
  inFlight.add(url)

  try {
    await acquireSlot()
    await ensureDir()

    const target = cachePathOf(url)
    if (await fileSizeOf(target) > 0) return

    const temp = `${target}${PART_SUFFIX}`
    const result = await RNFS.downloadFile({
      fromUrl: url,
      toFile: temp,
      headers: { 'User-Agent': defaultUserAgent },
      // 已经下过一半就接着下，避免反复从头开始
      // （resume 只在 iOS 上支持，Android 侧这段代码不会执行）
    }).promise

    if (result.statusCode >= 200 && result.statusCode < 300) {
      if (await RNFS.exists(target)) await RNFS.unlink(target)
      await RNFS.moveFile(temp, target)
      void enforceCacheLimit()
    } else {
      await RNFS.unlink(temp).catch(() => {})
    }
  } catch {
    // 网络中断 / 空间不足等，静默失败
  } finally {
    inFlight.delete(url)
    releaseSlot()
  }
}

/**
 * 把「待播放的 URL」转换成实际交给播放器的 URL。
 *   - 已缓存 -> file://...
 *   - 未缓存 -> 原 URL，并触发后台预取
 * Android 上直接返回原 URL（RNTP 自己有缓存机制）。
 */
export const resolvePlayableUrl = async(url: string): Promise<string> => {
  if (!isIOS) return url
  if (!url.startsWith('http')) return url

  const path = cachePathOf(url)
  if (await fileSizeOf(path) > 0) {
    // 命中缓存：直接用本地文件播放，省掉一次网络请求
    return `file://${path}`
  }

  void prefetch(url)
  return url
}

export const isCached = async(url: string): Promise<boolean> => {
  return isIOS ? iosIsCached(url) : TrackPlayer.isCached(url)
}

export const getCacheSize = async(): Promise<number> => {
  return isIOS ? iosGetCacheSize() : TrackPlayer.getCacheSize()
}

export const clearCache = async(): Promise<void> => {
  return isIOS ? iosClearCache() : TrackPlayer.clearCache()
}

/// 供播放器初始化时调用：确保缓存目录存在（iOS）
export const initCacheDir = async() => {
  if (!isIOS) return
  await ensureDir()
}
