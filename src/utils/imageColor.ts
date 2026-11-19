import { NativeModules, Platform } from 'react-native'

/**
 * 封面平均色提取（动态背景用）。
 *
 * iOS 走原生 LXImageColor 模块（CIAreaAverage，官方 API，性能好）。
 * Android 无此模块，返回 null，走兜底中性色。
 *
 * 缓存策略：进程级 Map，按 url 缓存，避免同一封面重复计算；
 * 播放器背景是高频切换场景，这里限制缓存大小防止内存膨胀。
 */
const NativeColorModule = NativeModules.LXImageColor as {
  averageColor?: (url: string) => Promise<{ r: number, g: number, b: number } | null>
} | undefined

const cache = new Map<string, string | null>()
const CACHE_LIMIT = 40

const hasMethod = () => Platform.OS == 'ios' && typeof NativeColorModule?.averageColor == 'function'

/** 取封面平均色，返回 '#RRGGBB' 或 null */
export const getAverageColor = async(url?: string | null): Promise<string | null> => {
  if (!url || !hasMethod()) return null
  const cached = cache.get(url)
  if (cached !== undefined) return cached

  try {
    const res = await NativeColorModule?.averageColor?.(url)
    const result = res ? rgbToHex(res.r, res.g, res.b) : null
    if (cache.size >= CACHE_LIMIT) {
      const firstKey = cache.keys().next().value
      if (firstKey) cache.delete(firstKey)
    }
    cache.set(url, result)
    return result
  } catch {
    return null
  }
}

export const rgbToHex = (r: number, g: number, b: number) => {
  const to = (v: number) => Math.max(0, Math.min(255, Math.round(v))).toString(16).padStart(2, '0')
  return `#${to(r)}${to(g)}${to(b)}`
}

/** 把主色压暗/提亮，用于背景遮罩（保持文字可读） */
export const darken = (hex: string, amount = 0.62) => {
  const r = parseInt(hex.slice(1, 3), 16)
  const g = parseInt(hex.slice(3, 5), 16)
  const b = parseInt(hex.slice(5, 7), 16)
  return rgbToHex(r * amount, g * amount, b * amount)
}

/** 转 rgba 字符串（遮罩用） */
export const toRgba = (hex: string, alpha: number) => {
  const r = parseInt(hex.slice(1, 3), 16)
  const g = parseInt(hex.slice(3, 5), 16)
  const b = parseInt(hex.slice(5, 7), 16)
  return `rgba(${r}, ${g}, ${b}, ${alpha})`
}
