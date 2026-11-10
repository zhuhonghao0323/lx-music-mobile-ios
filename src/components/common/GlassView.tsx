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
  ultraThin: 'rgba(24, 18, 18, 0.40)',
  thin: 'rgba(24, 18, 18, 0.56)',
  regular: 'rgba(24, 18, 18, 0.70)',
  thick: 'rgba(24, 18, 18, 0.84)',
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
  // radius <= 0 表示「铺满、不要圆角轮廓」：此时必须连描边和高光一起关掉，
  // 否则会在满屏容器边缘留下一条可见的框线（之前播放页顶部就出现了这种情况）。
  const isFullBleed = radius <= 0
  const r = isFullBleed ? 0 : Math.max(8, scaleSizeW(radius))
  const showBorder = border && !isFullBleed
  const showHighlight = highlight && !isFullBleed

  const frameStyle = useMemo(() => ({
    borderRadius: r,
    ...(isGlass && shadow ? Platform.select({
      ios: {
        // 暖黑基调下的柔和阴影（设计规范：不做强烈霓虹感）
        shadowColor: 'rgba(6, 4, 4, 0.55)',
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
              // 满屏容器（radius<=0，多为 Header/Aside 这类通栏）不铺任何材质：
              // 系统材质在浅色环境底上会泛出一整块浅色横带，正是「浅色框」的来源。
              blurType={isFullBleed ? 'dark' : IOS_BLUR_TYPE[material]}
              blurAmount={isFullBleed ? 0 : (material == 'thick' ? 24 : material == 'regular' ? 18 : 12)}
              reducedTransparencyFallbackColor={isFullBleed ? 'transparent' : FALLBACK_BG[material]}
            />
          : <View style={[StyleSheet.absoluteFill, layerStyle, { backgroundColor: isFullBleed ? 'transparent' : FALLBACK_BG[material] }]} />
      }
      {isFullBleed
        ? null
        : (
            <View pointerEvents="none" style={[StyleSheet.absoluteFill, layerStyle, { backgroundColor: tint ?? 'rgba(255, 255, 255, 0.05)' }]} />
          )}
      {/* 玻璃光泽：上半部叠一层由亮到透的渐变，模拟玻璃受光后的柔和反射。
          分三段做阶梯渐变（工程未引入渐变库），视觉上足够平滑且开销极低。 */}
      {showHighlight
        ? (
            <View pointerEvents="none" style={[StyleSheet.absoluteFill, layerStyle, { overflow: 'hidden' }]}>
              <View style={[styles.sheen, { height: '34%', opacity: 0.10 }]} />
              <View style={[styles.sheen, { top: '22%', height: '22%', opacity: 0.05 }]} />
              <View style={[styles.sheen, { top: '44%', height: '12%', opacity: 0.02 }]} />
            </View>
          )
        : null}
      {showBorder
        ? <View pointerEvents="none" style={[StyleSheet.absoluteFill, styles.border, layerStyle]} />
        : null}
      {showHighlight
        ? <View pointerEvents="none" style={[styles.highlight, { left: r * 0.7, right: r * 0.7 }]} />
        : null}
      {children}
    </View>
  )
})

const styles = StyleSheet.create({
  sheen: {
    position: 'absolute',
    left: 0,
    right: 0,
    top: 0,
    backgroundColor: '#FFFFFF',
  },
  border: {
    borderWidth: StyleSheet.hairlineWidth,
    // 设计规范：玻璃描边 rgba(255,255,255,0.22)，顶部略亮形成受光感
    borderTopColor: 'rgba(255, 255, 255, 0.28)',
    borderLeftColor: 'rgba(255, 255, 255, 0.20)',
    borderRightColor: 'rgba(255, 255, 255, 0.14)',
    borderBottomColor: 'rgba(255, 255, 255, 0.10)',
  },
  highlight: {
    position: 'absolute',
    top: 0,
    height: 1,
    // 设计规范：玻璃高光 rgba(255,255,255,0.12)，不做强烈霓虹
    backgroundColor: 'rgba(255, 255, 255, 0.16)',
  },
})

export default GlassView
