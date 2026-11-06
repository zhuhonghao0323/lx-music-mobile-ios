import { Platform, StyleSheet, type ViewStyle } from 'react-native'
import { useTheme } from '@/store/theme/hook'

/** 液态玻璃主题 id */
export const LIQUID_GLASS_ID = 'liquid_glass'
/** MD3 主题 id（移植自 md3Music 的 Material Design 3 设计语言） */
export const MD3_ID = 'md3'

/** 是否处于液态玻璃主题 */
export const useIsGlass = () => useTheme().id == LIQUID_GLASS_ID
/** 是否处于 MD3 主题 */
export const useIsMd3 = () => useTheme().id == MD3_ID

/**
 * md3Music 的尺寸 token（4dp 基准、8dp 节奏），按需在这里集中取用。
 * 数值直接来自其 lib/core/theme/app_dimens.dart，保证与源项目的视觉节奏一致。
 */
export const MD3_SPACING = { none: 0, xxs: 2, xs: 4, sm: 8, md: 12, lg: 16, xl: 24, xxl: 32, xxxl: 48 } as const
export const MD3_RADIUS = { xs: 4, cover: 6, sm: 8, md: 12, lg: 16, dropdownPanel: 20, xl: 28, full: 999 } as const

/** MD3 深色 surface 层级（对应 M3 ColorScheme.dark 的 surfaceContainer*） */
export const MD3_SURFACE = {
  base: '#121318',
  containerLowest: '#0D0E13',
  containerLow: '#1A1B21',
  container: '#1E1F25',
  containerHigh: '#282A2F',
  containerHighest: '#33353A',
  outline: '#8E9099',
  outlineVariant: '#44474F',
  primary: '#A1C9FF',
  onPrimaryContainer: '#D4E3FF',
  primaryContainer: '#2C3A4E',
  secondaryContainer: '#42455C',
} as const

/** MD3 卡片样式：M3 规范 elevation 1 + 16dp 圆角 + surfaceContainer */
export const md3Card = (): ViewStyle => ({
  backgroundColor: MD3_SURFACE.container,
  borderRadius: MD3_RADIUS.lg,
  ...Platform.select({
    ios: {
      shadowColor: '#000000',
      shadowOffset: { width: 0, height: 1 },
      shadowOpacity: 0.3,
      shadowRadius: 3,
    },
    android: { elevation: 1 },
  }),
})

/** MD3 按钮/输入：12dp 圆角 */
export const md3Control = (): ViewStyle => ({
  backgroundColor: MD3_SURFACE.primaryContainer,
  borderRadius: MD3_RADIUS.md,
})

export const useMd3 = () => {
  const isMd3 = useIsMd3()
  return {
    isMd3,
    card: (): ViewStyle => (isMd3 ? md3Card() : {}),
    control: (): ViewStyle => (isMd3 ? md3Control() : {}),
    surface: MD3_SURFACE,
    radius: MD3_RADIUS,
    spacing: MD3_SPACING,
  }
}

/** 是否使用原生毛玻璃（BlusView / UIVisualEffectView），iOS 全版本可用 */
export const isNativeBlurAvailable = Platform.OS == 'ios'

/**
 * 液态玻璃调色板。
 * 背景模糊由原生 BlurView 提供；这里只负责描边、高光、阴影、文字色等光学层。
 */
const GLASS = {
  // 面板降级底色（非 iOS 或降低透明度时）
  surface: 'rgba(28, 34, 58, 0.62)',
  surfaceStrong: 'rgba(28, 34, 58, 0.78)',
  surfaceDim: 'rgba(28, 34, 58, 0.44)',
  control: 'rgba(255, 255, 255, 0.10)',
  controlActive: 'rgba(255, 255, 255, 0.22)',
  border: 'rgba(255, 255, 255, 0.38)',
  borderSoft: 'rgba(255, 255, 255, 0.16)',
  highlight: 'rgba(255, 255, 255, 0.6)',
  shadow: 'rgba(4, 8, 24, 0.6)',
  scrim: 'rgba(6, 10, 26, 0.46)',
  tint: 'rgba(120, 190, 255, 0.95)',
  text: '#f4f8ff',
  textDim: 'rgba(226, 236, 255, 0.66)',
} as const

/** 极光背景光斑（供 PageContent 绘制，被原生玻璃真实虚化） */
export const GLASS_AURORA = [
  { color: 'rgba(86, 130, 255, 0.55)', size: 0.9, top: -0.12, left: -0.18 },
  { color: 'rgba(198, 112, 255, 0.45)', size: 0.75, top: 0.08, left: 0.55 },
  { color: 'rgba(64, 220, 200, 0.40)', size: 0.8, top: 0.48, left: -0.12 },
  { color: 'rgba(255, 138, 190, 0.38)', size: 0.7, top: 0.66, left: 0.5 },
  { color: 'rgba(90, 170, 255, 0.35)', size: 0.6, top: 0.82, left: 0.1 },
] as const

export const GLASS_BASE = '#0b1024'
export const GLASS_DEEP = '#070a18'

/**
 * 面板样式占位：原生毛玻璃的描边/高光/阴影/圆角全部由 GlassView 提供，
 * 这里保留空实现，供仍用旧路径（非 GlassView）的调用方无侵入地组合。
 */
export const glassPanel = (): ViewStyle => ({})

/** 控件样式（按钮、输入、菜单项）——仅描边与圆角，不铺底色 */
export const glassControl = (active = false): ViewStyle => ({
  borderWidth: StyleSheet.hairlineWidth,
  borderColor: active ? GLASS.border : GLASS.borderSoft,
  borderRadius: 14,
  ...(active ? { backgroundColor: GLASS.controlActive } : {}),
})

/** 顶部高光条 */
export const glassHighlight = (): ViewStyle => ({
  position: 'absolute',
  top: 0,
  left: 0,
  right: 0,
  height: 1,
  backgroundColor: GLASS.highlight,
  opacity: 0.6,
})

export const useGlass = () => {
  const isGlass = useIsGlass()
  return {
    isGlass,
    /** 是否走原生模糊 */
    nativeBlur: isGlass && isNativeBlurAvailable,
    panel: (): ViewStyle => (isGlass ? glassPanel() : {}),
    control: (active = false): ViewStyle => (isGlass ? glassControl(active) : {}),
    scrim: (): string | undefined => (isGlass ? GLASS.scrim : undefined),
    divider: (): string | undefined => (isGlass ? GLASS.borderSoft : undefined),
    highlight: (): ViewStyle => (isGlass ? glassHighlight() : {}),
    textColor: (): string | undefined => (isGlass ? GLASS.text : undefined),
    textDimColor: (): string | undefined => (isGlass ? GLASS.textDim : undefined),
    tint: (): string | undefined => (isGlass ? GLASS.tint : undefined),
    aurora: () => (isGlass ? GLASS_AURORA : []),
  }
}
