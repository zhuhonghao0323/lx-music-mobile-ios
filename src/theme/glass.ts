import { Platform, StyleSheet, type ViewStyle } from 'react-native'
import { useTheme } from '@/store/theme/hook'

/** 液态玻璃主题 id（深色） */
export const LIQUID_GLASS_ID = 'liquid_glass'
/** 液态玻璃主题 id（浅色） */
export const LIQUID_GLASS_LIGHT_ID = 'liquid_glass_light'
/** MD3 主题 id（移植自 md3Music 的 Material Design 3 设计语言） */
export const MD3_ID = 'md3'

/** 是否处于液态玻璃主题（深色或浅色都算） */
export const useIsGlass = () => {
  const id = useTheme().id
  return id == LIQUID_GLASS_ID || id == LIQUID_GLASS_LIGHT_ID
}
/** 是否处于浅色液态玻璃 */
export const useIsGlassLight = () => useTheme().id == LIQUID_GLASS_LIGHT_ID
/** 是否处于 MD3 主题 */
export const useIsMd3 = () => useTheme().id == MD3_ID

/**
 * 统一圆角 token。
 *
 * 玻璃主题下全站统一大圆角（弹窗 24 / 面板 18 / 控件 14），
 * 其它主题沿用项目原来的紧凑风格，避免影响既有主题观感。
 */
export const RADIUS = {
  /** 模态弹窗（Dialog / Popup） */
  dialog: 24,
  /** 浮层面板（下拉面板、菜单） */
  panel: 18,
  /** 控件（按钮、输入框、列表项） */
  control: 14,
  /** 小元素（徽标、缩略图） */
  small: 8,
} as const

/** 按当前主题取圆角：玻璃主题用统一大圆角，其它主题回落到传入的默认值 */
export const useRadius = () => {
  const isGlass = useIsGlass()
  return (fallback: number, token?: keyof typeof RADIUS): number =>
    isGlass ? RADIUS[token ?? 'control'] : fallback
}

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
 * 液态玻璃调色板（按设计交付说明还原）。
 * 背景模糊由原生 BlurView 提供；这里只负责描边、高光、阴影、文字色等光学层。
 * 数值来源：音乐播放器_iOS27_LiquidGlass 开发交付说明 §3 视觉规范。
 */
const GLASS = {
  // 面板降级底色（非 iOS 或降低透明度时）——暖黑
  surface: 'rgba(18, 14, 14, 0.62)',
  surfaceStrong: 'rgba(18, 14, 14, 0.78)',
  surfaceDim: 'rgba(18, 14, 14, 0.44)',
  control: 'rgba(255, 255, 255, 0.08)',
  controlActive: 'rgba(255, 255, 255, 0.16)',
  // 玻璃描边 rgba(255,255,255,0.22)，1px 以内
  border: 'rgba(255, 255, 255, 0.22)',
  borderSoft: 'rgba(255, 255, 255, 0.12)',
  // 玻璃高光 rgba(255,255,255,0.12)
  highlight: 'rgba(255, 255, 255, 0.12)',
  shadow: 'rgba(6, 4, 4, 0.55)',
  scrim: 'rgba(11, 9, 10, 0.46)',
  // 强调色 #F27868
  tint: 'rgba(242, 120, 104, 0.95)',
  // 主文字 #F5F2F1 / 次级文字 #B8B0B0
  text: '#F5F2F1',
  textDim: '#B8B0B0',
} as const

/**
 * 环境背景光斑：设计稿要求由「封面放大模糊 + 黑色遮罩」形成环境底色，
 * 这里保留一组暖色光斑作为封面上色前的兜底层，色相与暖黑基调一致。
 */
export const GLASS_AURORA = [
  { color: 'rgba(242, 120, 104, 0.28)', size: 0.9, top: -0.12, left: -0.18 },
  { color: 'rgba(232, 178, 125, 0.22)', size: 0.75, top: 0.08, left: 0.55 },
  { color: 'rgba(155, 176, 196, 0.16)', size: 0.8, top: 0.48, left: -0.12 },
  { color: 'rgba(242, 120, 104, 0.18)', size: 0.7, top: 0.66, left: 0.5 },
  { color: 'rgba(120, 90, 80, 0.20)', size: 0.6, top: 0.82, left: 0.1 },
] as const

export const GLASS_BASE = '#0B090A'
export const GLASS_DEEP = '#070505'

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
