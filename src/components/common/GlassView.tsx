import { memo, useMemo } from 'react'
import { Platform, StyleSheet, View, type ViewProps, type StyleProp, type ViewStyle } from 'react-native'
import { BlurView } from '@react-native-community/blur'
import { useIsGlass } from '@/theme/glass'
import { scaleSizeW } from '@/utils/pixelRatio'

/**
 * 原生毛玻璃容器（iOS 13+ 全可用，含 iOS 17）。
 * 基于 UIVisualEffectView 的 systemMaterial 实时背景模糊，
 * 叠加玻璃光学层：上沿高光、内发光描边、连续圆角、外阴影。
 * 各绝对定位层都带 borderRadius 自行裁剪，因此不设 overflow:hidden，
 * 避免 iOS 上 shadow 被裁掉。
 * 非液态玻璃主题 / 非 iOS / 开启「降低透明度」时自动回退为普通 View。
 */
export interface GlassViewProps extends ViewProps {
  material?: 'ultraThin' | 'thin' | 'regular' | 'thick'
  radius?: number
  highlight?: boolean
  border?: boolean
  tint?: string
  shadow?: boolean
  children?: React.ReactNode
  style?: StyleProp<ViewStyle>
}

const IOS_BLUR_TYPE = {
  ultraThin: 'ultraThinMaterialDark',
  thin: 'thinMaterialDark',
  regular: 'materialDark',
  thick: 'thickMaterialDark',
} as const

const FALLBACK_BG = {
  ultraThin: 'rgba(28, 34, 58, 0.42)',
  thin: 'rgba(28, 34, 58, 0.58)',
  regular: 'rgba(28, 34, 58, 0.72)',
  thick: 'rgba(28, 34, 58, 0.86)',
} as const

const GlassView = memo(({
  material = 'thin',
  radius = 20,
  highlight = true,
  border = true,
  tint,
  shadow = true,
  children,
  style,
  ...props
}: GlassViewProps) => {
  const isGlass = useIsGlass()
  const r = radius <= 0 ? 0 : Math.max(8, scaleSizeW(radius))

  const frameStyle = useMemo(() => ({
    borderRadius: r,
    ...(isGlass && shadow ? Platform.select({
      ios: {
        shadowColor: 'rgba(4, 8, 24, 0.6)',
        shadowOffset: { width: 0, height: 10 },
        shadowOpacity: 0.45,
        shadowRadius: 24,
      },
      android: { elevation: 8 },
    }) : {}),
  }), [isGlass, shadow, r])

  // 非玻璃主题：渲染普通 View，零额外开销
  if (!isGlass) {
    return <View style={[frameStyle, style]} {...props}>{children}</View>
  }

  const layerStyle = { borderRadius: r }

  return (
    <View style={[frameStyle, style]} {...props}>
      {
        Platform.OS == 'ios'
          ? <BlurView
              style={[StyleSheet.absoluteFill, layerStyle]}
              blurType={IOS_BLUR_TYPE[material]}
              blurAmount={material == 'thick' ? 24 : material == 'regular' ? 18 : 12}
              reducedTransparencyFallbackColor={FALLBACK_BG[material]}
            />
          : <View style={[StyleSheet.absoluteFill, layerStyle, { backgroundColor: FALLBACK_BG[material] }]} />
      }
      <View pointerEvents="none" style={[StyleSheet.absoluteFill, layerStyle, { backgroundColor: tint ?? 'rgba(120, 170, 255, 0.06)' }]} />
      {border
        ? <View pointerEvents="none" style={[StyleSheet.absoluteFill, styles.border, layerStyle]} />
        : null}
      {highlight
        ? <View pointerEvents="none" style={[styles.highlight, { left: r * 0.7, right: r * 0.7 }]} />
        : null}
      {children}
    </View>
  )
})

const styles = StyleSheet.create({
  border: {
    borderWidth: StyleSheet.hairlineWidth,
    borderTopColor: 'rgba(255, 255, 255, 0.55)',
    borderLeftColor: 'rgba(255, 255, 255, 0.28)',
    borderRightColor: 'rgba(255, 255, 255, 0.16)',
    borderBottomColor: 'rgba(255, 255, 255, 0.10)',
  },
  highlight: {
    position: 'absolute',
    top: 0,
    height: 1,
    backgroundColor: 'rgba(255, 255, 255, 0.6)',
  },
})

export default GlassView
