import { type ViewStyle } from 'react-native'
import { scaleSizeW } from '@/utils/pixelRatio'

/**
 * 播放页底部辅助按钮的圆形玻璃底（收藏 / 播放模式 / 评论 / 列表 共用）。
 *
 * 设计规范：
 * - 直径 46，四个等宽分布
 * - 半透明白玻璃 + 非对称描边（顶亮底暗，模拟受光）+ 柔和投影，形成立体圆形质感
 * - 图标由 justifyContent/alignItems 保证落在圆的正中
 *
 * 抽成共享样式是为了保证四个按钮的玻璃质感完全一致，
 * 无论当前是否液态玻璃主题，这四个按钮都统一使用该圆形玻璃底。
 */
export const GLASS_CIRCLE_SIZE = Math.max(44, scaleSizeW(46))

/**
 * 液态玻璃圆形底样式（四个按钮共用）。
 * - 立体感：顶部偏亮的描边 + 底部偏暗的描边 + 柔和投影
 * - 居中：embed 的图标/文字都会落在圆的正中
 */
export const glassCircleStyle = (size: number): ViewStyle => ({
  width: size,
  height: size,
  borderRadius: size / 2,
  justifyContent: 'center',
  alignItems: 'center',
  backgroundColor: 'rgba(255, 255, 255, 0.13)',
  borderWidth: 1,
  borderTopColor: 'rgba(255, 255, 255, 0.42)',
  borderLeftColor: 'rgba(255, 255, 255, 0.24)',
  borderRightColor: 'rgba(255, 255, 255, 0.18)',
  borderBottomColor: 'rgba(255, 255, 255, 0.08)',
  shadowColor: 'rgba(0, 0, 0, 0.55)',
  shadowOffset: { width: 0, height: 5 },
  shadowOpacity: 0.42,
  shadowRadius: 12,
})

/**
 * 音质按钮的文字尺寸：
 * 圆形直径约 46，去掉描边与内边距后可用宽度约 36，
 * 「320k」4 个字符在 11 号字下刚好排满，再大会被裁掉。
 */
export const QUALITY_TEXT_SIZE = 11
