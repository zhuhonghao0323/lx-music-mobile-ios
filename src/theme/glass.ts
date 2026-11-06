import { Platform, StyleSheet, type ViewStyle } from 'react-native'
import { useTheme } from '@/store/theme/hook'

/** 液态玻璃主题 id */
export const LIQUID_GLASS_ID = 'liquid_glass'

/** 是否处于液态玻璃主题 */
export const useIsGlass = () => useTheme().id == LIQUID_GLASS_ID

/**
 * 液态玻璃调色板。
 * 由于工程没有引入原生模糊/渐变库，这里用「半透明底色 + 高光描边 + 内外阴影 +
 * 顶部高光渐变层」的组合来还原 iOS 27 的液态玻璃观感，纯 JS 实现、三端一致。
 */
const GLASS = {
  // 面板 / 卡片：偏冷的中性半透明，叠加后可透出背景极光
  surface: 'rgba(255, 255, 255, 0.14)',
  surfaceStrong: 'rgba(255, 255, 255, 0.22)',
  surfaceDim: 'rgba(255, 255, 255, 0.08)',
  // 控件（按钮、输入、菜单项）
  control: 'rgba(255, 255, 255, 0.16)',
  controlActive: 'rgba(255, 255, 255, 0.30)',
  // 描边：上亮下暗，制造「玻璃边缘折射」
  border: 'rgba(255, 255, 255, 0.38)',
  borderSoft: 'rgba(255, 255, 255, 0.16)',
  // 顶部高光
  highlight: 'rgba(255, 255, 255, 0.55)',
  // 阴影
  shadow: 'rgba(6, 10, 30, 0.55)',
  // 遮罩
  scrim: 'rgba(8, 12, 32, 0.42)',
  // 强调色
  tint: 'rgba(120, 190, 255, 0.95)',
  text: '#f4f8ff',
  textDim: 'rgba(226, 236, 255, 0.62)',
} as const

/** 极光背景光斑（供 PageContent 绘制） */
export const GLASS_AURORA = [
  { color: 'rgba(86, 130, 255, 0.55)', size: 0.9, top: -0.12, left: -0.18 },
  { color: 'rgba(198, 112, 255, 0.45)', size: 0.75, top: 0.08, left: 0.55 },
  { color: 'rgba(64, 220, 200, 0.40)', size: 0.8, top: 0.48, left: -0.12 },
  { color: 'rgba(255, 138, 190, 0.38)', size: 0.7, top: 0.66, left: 0.5 },
  { color: 'rgba(90, 170, 255, 0.35)', size: 0.6, top: 0.82, left: 0.1 },
] as const

export const GLASS_BASE = '#0b1024'
export const GLASS_DEEP = '#070a18'

/** 通用玻璃面板样式（卡片、弹窗、菜单等） */
export const glassPanel = (strong = false): ViewStyle => ({
  backgroundColor: strong ? GLASS.surfaceStrong : GLASS.surface,
  borderWidth: StyleSheet.hairlineWidth,
  borderColor: GLASS.border,
  borderRadius: 22,
  ...Platform.select({
    ios: {
      shadowColor: GLASS.shadow,
      shadowOffset: { width: 0, height: 12 },
      shadowOpacity: 0.5,
      shadowRadius: 28,
    },
    android: { elevation: 10 },
  }),
  // 防止子内容溢出圆角
  overflow: 'hidden',
})

/** 控件样式（按钮、输入、列表项） */
export const glassControl = (active = false): ViewStyle => ({
  backgroundColor: active ? GLASS.controlActive : GLASS.control,
  borderWidth: StyleSheet.hairlineWidth,
  borderColor: active ? GLASS.border : GLASS.borderSoft,
  borderRadius: 14,
})

/** 顶部高光条（叠在面板最上层，制造玻璃反光） */
export const glassHighlight = (): ViewStyle => ({
  position: 'absolute',
  top: 0,
  left: 0,
  right: 0,
  height: 1,
  backgroundColor: GLASS.highlight,
  opacity: 0.6,
})

/**
 * 供组件使用的玻璃样式集合；isGlass 为 false 时返回空对象，
 * 调用方用 StyleSheet.compose 叠加即可无侵入地兼容普通主题。
 */
export const useGlass = () => {
  const isGlass = useIsGlass()
  return {
    isGlass,
    /** 面板（弹窗、Popup、Dialog） */
    panel: (strong = false): ViewStyle => (isGlass ? glassPanel(strong) : {}),
    /** 控件（按钮、输入、菜单项） */
    control: (active = false): ViewStyle => (isGlass ? glassControl(active) : {}),
    /** 遮罩背景色 */
    scrim: (): string | undefined => (isGlass ? GLASS.scrim : undefined),
    /** 分割线颜色 */
    divider: (): string | undefined => (isGlass ? GLASS.borderSoft : undefined),
    /** 高光条样式 */
    highlight: (): ViewStyle => (isGlass ? glassHighlight() : {}),
    /** 文本主色 */
    textColor: (): string | undefined => (isGlass ? GLASS.text : undefined),
    /** 文本次色 */
    textDimColor: (): string | undefined => (isGlass ? GLASS.textDim : undefined),
    /** 强调色 */
    tint: (): string | undefined => (isGlass ? GLASS.tint : undefined),
    /** 极光背景 */
    aurora: () => (isGlass ? GLASS_AURORA : []),
  }
}
