import { Platform, StyleSheet, type ViewStyle } from 'react-native'
import { useTheme } from '@/store/theme/hook'

/** 液态玻璃主题 id */
export const LIQUID_GLASS_ID = 'liquid_glass'

/** 是否处于液态玻璃主题 */
export const useIsGlass = () => useTheme().id == LIQUID_GLASS_ID

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
