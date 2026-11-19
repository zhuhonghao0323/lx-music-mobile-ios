import { memo, useMemo } from 'react'
import { Platform, StyleSheet, View, type ViewProps, type StyleProp, type ViewStyle } from 'react-native'
import { BlurView } from '@react-native-community/blur'
import { useIsGlass, useIsGlassLight } from '@/theme/glass'
import { useGlassParams, type GlassMaterialName } from '@/theme/glassMaterial'
import { scaleSizeW } from '@/utils/pixelRatio'

/**
 * 原生毛玻璃容器（iOS 13+ 全可用，含 iOS 17）。
 *
 * 材质分级来自 glassMaterial.ts 的统一参数表（thin/regular/thick/floating），
 * 深浅色自适应；iOS 17/18 用 UIVisualEffectView 模拟 Liquid Glass。
 * 业务页面不要直接写 blur 参数，全部走 material 名称。
 *
 * 各绝对定位层都带 borderRadius 自行裁剪，因此不设 overflow:hidden，
 * 避免 iOS 上 shadow 被裁掉。
 * 非液态玻璃主题 / 非 iOS / 开启「降低透明度」时自动回退为普通 View。
 */
export interface GlassViewProps extends ViewProps {
  material?: GlassMaterialName
  radius?: number
  /** 关闭高光/描边/阴影（用于纯模糊层，如播放页动态背景） */
  plain?: boolean
  /** 色彩倾向注入（如封面主色），叠加在材质之上 */
  tint?: string
  /** 兼容旧 API：单独控制高光/描边/阴影（plain 会整体关闭） */
  highlight?: boolean
  border?: boolean
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

const IOS_BLUR_TYPE_LIGHT = {
  ultraThin: 'ultraThinMaterialLight',
  thin: 'thinMaterialLight',
  regular: 'materialLight',
  thick: 'thickMaterialLight',
} as const

/** material → 系统 blurType 映射 */
const MATERIAL_BLUR: Record<GlassMaterialName, keyof typeof IOS_BLUR_TYPE> = {
  ultraThin: 'ultraThin',
  thin: 'thin',
  regular: 'regular',
  thick: 'thick',
  floating: 'regular',
}

const GlassView = memo(({
  material = 'regular',
  radius,
  plain = false,
  tint,
  highlight: highlightProp,
  border: borderProp,
  shadow: shadowProp,
  children,
  style,
  ...props
}: GlassViewProps) => {
  const isGlass = useIsGlass()
  const isLight = useIsGlassLight()
  const params = useGlassParams(material)

  // radius 未显式传入时用材质推荐圆角
  const r = Math.max(0, scaleSizeW(radius ?? params.radius))
  const isFullBleed = r <= 0

  // 兼容旧布尔 props：默认 true，plain 整体关闭，显式 false 单独关闭
  const showBorder = (borderProp ?? true) && !plain && !isFullBleed
  const showHighlight = (highlightProp ?? true) && !plain && !isFullBleed
  const showShadow = (shadowProp ?? true) && !plain && isGlass

  const frameStyle = useMemo(() => {
    const s: ViewStyle = { borderRadius: r }
    if (showShadow && params.shadow) {
      if (Platform.OS == 'ios') {
        s.shadowColor = isLight ? 'rgba(0,0,0,0.28)' : 'rgba(0, 0, 0, 0.55)'
        s.shadowOffset = { width: 0, height: params.shadow.offsetY }
        s.shadowOpacity = params.shadow.opacity
        s.shadowRadius = params.shadow.radius
      } else {
        s.elevation = 6
      }
    }
    return s
  }, [isLight, params, r, showShadow])

  // 非玻璃主题：渲染普通 View，零额外开销
  if (!isGlass) {
    return <View style={[frameStyle, style]} {...props}>{children}</View>
  }

  const layerStyle = { borderRadius: r }
  const blurKey = MATERIAL_BLUR[material]
  const blurType = isFullBleed
    ? (isLight ? 'light' : 'dark')
    : isLight ? IOS_BLUR_TYPE_LIGHT[blurKey] : IOS_BLUR_TYPE[blurKey]
  const fallbackBg = isLight
    ? `rgba(244, 244, 248, ${Math.min(0.96, 0.5 + params.tintAlpha)})`
    : `rgba(24, 22, 24, ${Math.min(0.96, 0.5 + params.tintAlpha)})`

  return (
    <View style={[frameStyle, style]} {...props}>
      {
        Platform.OS == 'ios'
          ? <BlurView
              style={[StyleSheet.absoluteFill, layerStyle]}
              blurType={isFullBleed ? blurType : blurType}
              blurAmount={isFullBleed ? 0 : params.blurAmount}
              reducedTransparencyFallbackColor={isFullBleed ? 'transparent' : fallbackBg}
            />
          : <View style={[StyleSheet.absoluteFill, layerStyle, { backgroundColor: isFullBleed ? 'transparent' : fallbackBg }]} />
      }
      {/* 色彩倾向层：半透明白（浅色）/白（深色），制造材质体积感；可用 tint 注入封面主色 */}
      {!isFullBleed
        ? (
            <View
              pointerEvents="none"
              style={[StyleSheet.absoluteFill, layerStyle, {
                backgroundColor: tint ?? (isLight ? `rgba(255,255,255,${params.tintAlpha})` : `rgba(255,255,255,${params.tintAlpha})`),
              }]}
            />
          )
        : null}
      {/* 玻璃光泽：上半部叠一层由亮到透的阶梯渐变，模拟玻璃受光后的柔和反射 */}
      {showHighlight
        ? (
            <View pointerEvents="none" style={[StyleSheet.absoluteFill, layerStyle, { overflow: 'hidden' }]}>
              <View style={[styles.sheen, { height: '32%', opacity: params.highlightAlpha }]} />
              <View style={[styles.sheen, { top: '24%', height: '18%', opacity: params.highlightAlpha * 0.5 }]} />
            </View>
          )
        : null}
      {showBorder
        ? (
            <View
              pointerEvents="none"
              style={[StyleSheet.absoluteFill, layerStyle, {
                borderWidth: StyleSheet.hairlineWidth,
                borderTopColor: isLight ? `rgba(255,255,255,${params.borderAlpha + 0.35})` : `rgba(255,255,255,${params.borderAlpha + 0.10})`,
                borderLeftColor: isLight ? `rgba(255,255,255,${params.borderAlpha + 0.2})` : `rgba(255,255,255,${params.borderAlpha + 0.04})`,
                borderRightColor: isLight ? `rgba(255,255,255,${params.borderAlpha + 0.2})` : `rgba(255,255,255,${params.borderAlpha + 0.02})`,
                borderBottomColor: isLight ? `rgba(120,120,128,${params.borderAlpha})` : `rgba(255,255,255,${params.borderAlpha * 0.6})`,
              }]}
            />
          )
        : null}
      {/* 上缘细高光（floating 材质更亮，形成悬浮感） */}
      {showHighlight
        ? (
            <View
              pointerEvents="none"
              style={[styles.highlight, {
                left: r * 0.6,
                right: r * 0.6,
                backgroundColor: `rgba(255,255,255,${material == 'floating' ? 0.22 : 0.12})`,
              }]}
            />
          )
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
  highlight: {
    position: 'absolute',
    top: 0,
    height: 1,
  },
})

export default GlassView
