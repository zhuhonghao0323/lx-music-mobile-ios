import { StyleSheet } from 'react-native'
import { scaleSizeW } from '@/utils/pixelRatio'

/**
 * 播放页底部辅助按钮的圆形玻璃底（收藏 / 随机 / 评论 / 音质 共用）。
 *
 * 设计规范：
 * - 直径 48–54，四个等宽分布
 * - 半透明白玻璃 + rgba(255,255,255,0.22) 细描边 + 顶部受光
 * - 暖黑基调下的柔和投影，不做强烈霓虹
 *
 * 抽成共享样式是为了保证四个按钮的玻璃质感完全一致，
 * 之前音质按钮是唯一没有圆形底的一个，视觉上非常突兀。
 */
export const GLASS_CIRCLE_SIZE = Math.max(44, scaleSizeW(46))

/** 玻璃主题下的圆形底样式 */
export const glassCircleStyle = (size: number) => ({
  width: size,
  height: size,
  borderRadius: size / 2,
  backgroundColor: 'rgba(255, 255, 255, 0.09)',
  borderWidth: StyleSheet.hairlineWidth,
  borderTopColor: 'rgba(255, 255, 255, 0.30)',
  borderLeftColor: 'rgba(255, 255, 255, 0.20)',
  borderRightColor: 'rgba(255, 255, 255, 0.16)',
  borderBottomColor: 'rgba(255, 255, 255, 0.10)',
  shadowColor: 'rgba(6, 4, 4, 0.55)',
  shadowOffset: { width: 0, height: 8 },
  shadowOpacity: 0.4,
  shadowRadius: 18,
})

/**
 * 音质按钮的文字尺寸：
 * 圆形直径约 46，去掉描边与内边距后可用宽度约 36，
 * 「320k」4 个字符在 11 号字下刚好排满，再大会被裁掉。
 */
export const QUALITY_TEXT_SIZE = 11
