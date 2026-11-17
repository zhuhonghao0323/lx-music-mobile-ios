import { getTotalPlayTime, saveTotalPlayTime } from '@/utils/data'
import { throttle } from '@/utils/common'

/**
 * 累计播放时长统计（单位：秒，持久化）。
 *
 * 统计方式：定时读取底层 position，只累加「合理的正增量」：
 * - 增量必须 > 0（排除回退）
 * - 增量必须 < 5 秒（排除拖动进度条、切歌等跳跃）
 * 这样得到的就是真实播放过的时长。
 */
let totalSeconds = 0
let lastPosition = 0
let loaded = false

export const initTotalPlayTime = () => {
  if (loaded) return
  loaded = true
  void getTotalPlayTime().then(v => { totalSeconds = v })
}

/** 用当前播放位置更新累计时长（在正常播放轮询里调用） */
export const trackPlayTime = (position: number, isPlaying: boolean) => {
  if (!loaded) initTotalPlayTime()
  if (!isPlaying) {
    lastPosition = position
    return
  }
  const delta = position - lastPosition
  if (delta > 0 && delta < 5) totalSeconds += delta
  lastPosition = position
}

/** 切歌/seek 时重置基准，避免把跳跃算进累计 */
export const resetPlayTimeAnchor = (position = 0) => {
  lastPosition = position
}

/** 切歌时把上一首剩余部分结算掉（pos 已被重置为 0 时不用） */
export const flushTotalPlayTime = throttle(() => {
  void saveTotalPlayTime(totalSeconds)
}, 3000)

export const getTotalPlayTimeSeconds = () => totalSeconds

/** 格式化为「X小时Y分」 */
export const formatTotalPlayTime = (seconds: number) => {
  const mins = Math.floor(seconds / 60)
  const hours = Math.floor(mins / 60)
  if (hours > 0) return `${hours}小时${mins % 60}分`
  return `${mins}分钟`
}
