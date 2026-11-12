import { Platform, StyleSheet, type ViewStyle } from 'react-native'
import { useIsGlass, useIsGlassLight } from './glass'

/**
 * Beans Music 设计语言 token。
 *
 * 数值全部提取自 XIaodou0416/Beans-Music 源码：
 *   - Theme.swift      → 配色（beansBackground / beansCard / beansAmber / BeansAccent.amber）
 *   - Components.swift → GlassCard(cornerRadius 24 / padding 16 / shadow radius 9 y 3)
 *   - RootView.swift   → 底栏间距（horizontal 18 / bottom 12 / VStack 8）
 *
 * 本项目是 React Native，无法使用 iOS 26 原生 Liquid Glass，
 * 这里用「半透明玻璃底 + 顶部高光 + 细描边 + 柔和阴影」近似还原其光学质感。
 */

/** 深色主题配色（Beans 默认深色态） */
export const BEANS_DARK = {
  /** 页面底色 #0A0A0C */
  background: '#0A0A0C',
  /** 面板/卡片底 #1C1C1E */
  card: '#1C1C1E',
  /** 浮层玻璃底（在 card 之上再叠半透明白） */
  glass: 'rgba(255, 255, 255, 0.08)',
  glassStrong: 'rgba(255, 255, 255, 0.13)',
  glassDim: 'rgba(255, 255, 255, 0.05)',
  /** 主文字（纯白） */
  text: '#FFFFFF',
  /** 次要文字 #98989F */
  textSecondary: '#98989F',
  /** 三级/说明文字 */
  textTertiary: '#6C6C70',
  /** 分隔线 */
  divider: 'rgba(255, 255, 255, 0.10)',
  /** 玻璃描边 */
  border: 'rgba(255, 255, 255, 0.14)',
  borderSoft: 'rgba(255, 255, 255, 0.08)',
  /** 顶部受光高光 */
  highlight: 'rgba(255, 255, 255, 0.12)',
  /** 阴影 */
  shadow: 'rgba(0, 0, 0, 0.55)',
} as const

/** 浅色主题配色（Beans 浅色态） */
export const BEANS_LIGHT = {
  /** 页面底色 #F2F2F7 */
  background: '#F2F2F7',
  card: '#FFFFFF',
  glass: 'rgba(255, 255, 255, 0.72)',
  glassStrong: 'rgba(255, 255, 255, 0.86)',
  glassDim: 'rgba(255, 255, 255, 0.50)',
  text: '#000000',
  textSecondary: '#6C6C70',
  textTertiary: '#8E8E93',
  divider: 'rgba(0, 0, 0, 0.08)',
  border: 'rgba(0, 0, 0, 0.10)',
  borderSoft: 'rgba(0, 0, 0, 0.06)',
  highlight: 'rgba(255, 255, 255, 0.90)',
  shadow: 'rgba(0, 0, 0, 0.12)',
} as const

/**
 * 琥珀暖金（BeansAccent.amber）——默认强调色。
 * 深色态 tintDark = rgb(0.96,0.70,0.35) ≈ #F5B359
 * 渐变 gradientColors = #F2A33C → #C07A0A
 * 浅色态 tintLight = rgb(0.72,0.44,0.03) ≈ #B87008
 */
export const BEANS_AMBER = {
  /** 深色模式主强调色（图标/文字/进度点） */
  dark: '#F5B359',
  /** 浅色模式主强调色（深琥珀，保证对比度） */
  light: '#B87008',
  /** 渐变起色 #F2A33C */
  gradientFrom: '#F2A33C',
  /** 渐变终色 #C07A0A */
  gradientTo: '#C07A0A',
  /** 高亮色（歌词高亮 / 光斑） */
  highlight: '#F2A33C',
  /** 强调色半透明底（选中态） */
  tintFill: 'rgba(242, 163, 60, 0.18)',
  tintFillStrong: 'rgba(242, 163, 60, 0.30)',
} as const

/** 网易云红：平台切换胶囊选中态 / VIP 徽标 */
export const BEANS_NETEASE_RED = {
  primary: '#E8402A',
  light: '#F04A34',
  vip: '#F5503A',
} as const

/** 排行榜彩色图标（Beans 首页榜单） */
export const BEANS_CHART_COLORS = {
  hot: { from: '#FA6E6E', to: '#FB8E8E' },
  soar: { from: '#7B6BF0', to: '#9B8BF5' },
  new: { from: '#4FD08A', to: '#7BDDAA' },
} as const

/** 圆角 token（Components.swift GlassCard 默认 24） */
export const BEANS_RADIUS = {
  /** 大卡片 / 弹窗 */
  card: 24,
  /** 中等容器（榜单卡片、平台切换条） */
  panel: 20,
  /** 控件（按钮、输入框、热搜 chip） */
  control: 14,
  /** 小元素（封面缩略图） */
  small: 10,
  /** 胶囊（平台切换、标签） */
  pill: 999,
} as const

/** 间距 token（RootView / Components） */
export const BEANS_SPACING = {
  xxs: 4,
  xs: 8,
  sm: 10,
  md: 12,
  lg: 16,
  xl: 18,
  xxl: 24,
  /** 页面左右边距 */
  page: 18,
  /** 卡片内边距 */
  card: 16,
} as const

/** 按当前主题（深/浅）取 Beans 配色 */
export const useBeansColors = () => {
  const isGlassLight = useIsGlassLight()
  return isGlassLight ? BEANS_LIGHT : BEANS_DARK
}

/** 按当前主题取强调色（深色亮金 / 浅色深琥珀） */
export const useBeansAccent = () => {
  const isGlassLight = useIsGlassLight()
  return isGlassLight ? BEANS_AMBER.light : BEANS_AMBER.dark
}

/**
 * Beans 玻璃卡片样式：半透明底 + 细描边 + 顶部受光 + 柔和阴影。
 * 对应 SwiftUI 的 GlassCard(.ultraThinMaterial + beansCardShadow(radius:9,y:3))。
 */
export const beansCard = (colors: typeof BEANS_DARK | typeof BEANS_LIGHT, radius = BEANS_RADIUS.card): ViewStyle => ({
  backgroundColor: colors.glass,
  borderRadius: radius,
  borderWidth: StyleSheet.hairlineWidth,
  borderColor: colors.border,
  ...Platform.select({
    ios: {
      shadowColor: colors.shadow,
      shadowOffset: { width: 0, height: 3 },
      shadowOpacity: 1,
      shadowRadius: 9,
    },
    android: { elevation: 3 },
  }),
})

/** Beans 圆形玻璃按钮（收藏/更多/上一曲/下一曲等） */
export const beansCircleButton = (colors: typeof BEANS_DARK | typeof BEANS_LIGHT, size: number): ViewStyle => ({
  width: size,
  height: size,
  borderRadius: size / 2,
  backgroundColor: colors.glass,
  borderWidth: StyleSheet.hairlineWidth,
  borderColor: colors.border,
  alignItems: 'center',
  justifyContent: 'center',
  ...Platform.select({
    ios: {
      shadowColor: colors.shadow,
      shadowOffset: { width: 0, height: 3 },
      shadowOpacity: 0.6,
      shadowRadius: 9,
    },
    android: { elevation: 2 },
  }),
})

/** 顶部受光高光层（叠在玻璃卡片/按钮内） */
export const beansSheen = (colors: typeof BEANS_DARK | typeof BEANS_LIGHT, radius: number): ViewStyle => ({
  position: 'absolute',
  top: 0,
  left: 0,
  right: 0,
  height: '50%',
  backgroundColor: colors.highlight,
  borderTopLeftRadius: radius,
  borderTopRightRadius: radius,
})

/** 是否在 Beans 风格主题（液态玻璃深色/浅色）下 */
export { useIsGlass }
