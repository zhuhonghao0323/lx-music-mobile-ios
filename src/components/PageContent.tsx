import { useMemo } from 'react'
import { Platform, SafeAreaView, StyleSheet, View } from 'react-native'
import ImageBackground from '@/components/common/ImageBackground'
import { defaultHeaders } from './common/Image'
import { useTheme } from '@/store/theme/hook'
import { useWindowSize } from '@/utils/hooks'
import { useBgPic } from '@/store/common/hook'
import { scaleSizeAbsHR } from '@/utils/pixelRatio'
import SizeView from './SizeView'
import { GLASS_AURORA, GLASS_BASE, GLASS_DEEP, useIsGlass } from '@/theme/glass'
import { useSettingValue } from '@/store/setting/hook'

interface Props {
  children: React.ReactNode
}

const BLUR_RADIUS = Math.max(scaleSizeAbsHR(18), 10)

/**
 * 液态玻璃主题的环境底：
 * 暖黑底 + 缓和的暖色光斑（不再是旧版的冷蓝极光）。
 * 设计规范要求底部整体是暖黑调，光斑只做极轻的氛围点缀。
 */
const GlassAmbient = ({ width, height }: { width: number, height: number }) => {
  const blobs = useMemo(() => GLASS_AURORA.map((blob, index) => {
    const size = Math.max(width, height) * blob.size
    return (
      <View
        key={index}
        pointerEvents="none"
        style={{
          position: 'absolute',
          width: size,
          height: size,
          borderRadius: size / 2,
          top: height * blob.top,
          left: width * blob.left,
          backgroundColor: blob.color,
          opacity: 0.4,
        }}
      />
    )
  }), [width, height])

  return (
    <View pointerEvents="none" style={[StyleSheet.absoluteFill, { backgroundColor: GLASS_BASE, overflow: 'hidden' }]}>
      <View pointerEvents="none" style={[StyleSheet.absoluteFill, { backgroundColor: GLASS_DEEP, opacity: 0.6 }]} />
      {blobs}
    </View>
  )
}

const ContentContainer = ({ children }: Props) => {
  if (Platform.OS == 'ios') return <SafeAreaView style={{ flex: 1 }}>{children}</SafeAreaView>
  return <>{children}</>
}

/**
 * 页面背景（统一决策，避免三套分支互相打架）。
 *
 * 优先级：
 * 1. 液态玻璃主题：
 *    - 开「动态背景」且有封面 → 模糊封面 + 74% 暖黑遮罩（保证基调仍是暖黑）
 *    - 否则 → 暖黑底 + 极轻暖色光斑
 * 2. 其它主题：
 *    - 有动态背景封面 → 模糊封面 + 主题色遮罩
 *    - 否则 → 主题背景图（受「隐藏黑色主题背景」控制）
 */
export default ({ children }: Props) => {
  const theme = useTheme()
  const isGlass = useIsGlass()
  const windowSize = useWindowSize()
  const pic = useBgPic()
  const isHideBgDark = useSettingValue('theme.hideBgDark')

  const background = useMemo(() => {
    const w = windowSize.width
    const h = windowSize.height

    // ---------- 液态玻璃主题 ----------
    if (isGlass) {
      // 有动态背景封面：以封面做氛围，但压在暖黑底上并加 74% 遮罩
      if (pic) {
        return (
          <View style={[StyleSheet.absoluteFill, { overflow: 'hidden' }]}>
            <View style={[StyleSheet.absoluteFill, { backgroundColor: GLASS_BASE }]} />
            <ImageBackground
              style={{ position: 'absolute', left: 0, top: 0, width: w, height: h }}
              source={{ uri: pic, headers: defaultHeaders }}
              resizeMode="cover"
              blurRadius={BLUR_RADIUS}
            />
            <View pointerEvents="none" style={[StyleSheet.absoluteFill, { backgroundColor: GLASS_BASE, opacity: 0.74 }]} />
          </View>
        )
      }
      return <GlassAmbient width={w} height={h} />
    }

    // ---------- 其它主题：动态背景 ----------
    if (pic) {
      return (
        <View style={[StyleSheet.absoluteFill, { overflow: 'hidden' }]}>
          <ImageBackground
            style={{ position: 'absolute', left: 0, top: 0, width: w, height: h, backgroundColor: theme['c-content-background'] }}
            source={{ uri: pic, headers: defaultHeaders }}
            resizeMode="cover"
            blurRadius={BLUR_RADIUS}
          />
          <View pointerEvents="none" style={[StyleSheet.absoluteFill, { backgroundColor: theme['c-content-background'], opacity: 0.76 }]} />
        </View>
      )
    }

    // ---------- 其它主题：主题背景图 ----------
    // 「隐藏黑色主题背景」开启时，深色主题不使用背景图，直接铺纯色
    const bgImage = theme['bg-image']
    const useBgImage = !!bgImage && !(theme.isDark && isHideBgDark)
    return (
      <View style={[StyleSheet.absoluteFill, { overflow: 'hidden' }]}>
        {useBgImage
          ? <ImageBackground
              style={{ position: 'absolute', left: 0, top: 0, width: w, height: h, backgroundColor: theme['c-content-background'] }}
              source={bgImage}
              resizeMode="cover"
            />
          : <View style={[StyleSheet.absoluteFill, { backgroundColor: theme['c-content-background'] }]} />}
        <View pointerEvents="none" style={[StyleSheet.absoluteFill, { backgroundColor: theme['c-main-background'], opacity: useBgImage ? 1 : 0.001 }]} />
      </View>
    )
  }, [isGlass, pic, theme, windowSize.width, windowSize.height, isHideBgDark])

  return (
    <>
      <SizeView />
      <View style={{ flex: 1 }}>
        {background}
        <ContentContainer>
          <View style={{ flex: 1, flexDirection: 'column' }}>
            {children}
          </View>
        </ContentContainer>
      </View>
    </>
  )
}
