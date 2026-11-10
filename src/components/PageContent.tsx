// import { useEffect, useState } from 'react'
import { Platform, SafeAreaView, StyleSheet, View } from 'react-native'
import { useTheme } from '@/store/theme/hook'
import ImageBackground from '@/components/common/ImageBackground'
import { useWindowSize } from '@/utils/hooks'
import { useMemo } from 'react'
import { scaleSizeAbsHR } from '@/utils/pixelRatio'
import { defaultHeaders } from './common/Image'
import SizeView from './SizeView'
import { useBgPic } from '@/store/common/hook'
import { GLASS_AURORA, GLASS_BASE, GLASS_DEEP, useIsGlass } from '@/theme/glass'

interface Props {
  children: React.ReactNode
}

const BLUR_RADIUS = Math.max(scaleSizeAbsHR(18), 10)

const ContentContainer = ({ children }: Props) => {
  if (Platform.OS == 'ios') return <SafeAreaView style={{ flex: 1 }}>{children}</SafeAreaView>
  return <>{children}</>
}

/** 液态玻璃主题专属：深色底 + 多团柔和极光光斑，供上层半透明玻璃折射 */
const AuroraBackground = ({ width, height }: { width: number, height: number }) => {
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
          // 用多层同心半透明圈模拟柔和径向渐变（工程未引入渐变库）
          backgroundColor: blob.color,
          opacity: 0.55,
        }}
      />
    )
  }), [width, height])
  return (
    <View pointerEvents="none" style={[StyleSheet.absoluteFill, { backgroundColor: GLASS_BASE, overflow: 'hidden' }]}>
      <View pointerEvents="none" style={[StyleSheet.absoluteFill, { backgroundColor: GLASS_DEEP, opacity: 0.5 }]} />
      {blobs}
      {/* 顶部与底部的冷色雾，增加纵深 */}
      <View pointerEvents="none" style={{ position: 'absolute', left: 0, right: 0, top: 0, height: height * 0.35, backgroundColor: 'rgba(90, 140, 255, 0.10)' }} />
      <View pointerEvents="none" style={{ position: 'absolute', left: 0, right: 0, bottom: 0, height: height * 0.35, backgroundColor: 'rgba(10, 8, 30, 0.35)' }} />
    </View>
  )
}

export default ({ children }: Props) => {
  const theme = useTheme()
  const isGlass = useIsGlass()
  const windowSize = useWindowSize()
  const pic = useBgPic()

  const themeComponent = useMemo(() => (
    <View style={{ flex: 1, overflow: 'hidden' }}>
      <ImageBackground
        style={{ position: 'absolute', left: 0, top: 0, height: windowSize.height, width: windowSize.width, backgroundColor: theme['c-content-background'] }}
        source={theme['bg-image']}
        resizeMode="cover"
      />
      <View
        pointerEvents="none"
        style={[
          StyleSheet.absoluteFill,
          {
            backgroundColor: theme['c-main-background'],
          },
        ]}
      />
      <ContentContainer>
        <View style={{ flex: 1, flexDirection: 'column' }}>
          {children}
        </View>
      </ContentContainer>
    </View>
  ), [children, theme, windowSize.height, windowSize.width])

  const glassComponent = useMemo(() => (
    <View style={{ flex: 1, overflow: 'hidden' }}>
      <AuroraBackground width={windowSize.width} height={windowSize.height} />
      <ContentContainer>
        <View style={{ flex: 1, flexDirection: 'column' }}>
          {children}
        </View>
      </ContentContainer>
    </View>
  ), [children, windowSize.height, windowSize.width])

  const picComponent = useMemo(() => {
    // 液态玻璃主题：设计规范要求「封面放大模糊 + 黑色遮罩 65%~78%」形成暖黑环境底，
    // 因此这里在模糊封面之上再压一层暖黑遮罩，保证整体基调是 #0B090A 的暖黑，
    // 而不是直接把封面糊成一片粉灰。
    if (isGlass) {
      return (
        <View style={{ flex: 1, overflow: 'hidden' }}>
          <View style={[StyleSheet.absoluteFill, { backgroundColor: GLASS_BASE }]} />
          <ImageBackground
            style={{ position: 'absolute', left: 0, top: 0, height: windowSize.height, width: windowSize.width }}
            source={{ uri: pic!, headers: defaultHeaders }}
            resizeMode="cover"
            blurRadius={BLUR_RADIUS}
          />
          {/* 暖黑遮罩：规范 65%~78%，让文字与控件始终清晰 */}
          <View
            pointerEvents="none"
            style={[StyleSheet.absoluteFill, { backgroundColor: GLASS_BASE, opacity: 0.74 }]}
          />
          <ContentContainer>
            <View style={{ flex: 1, flexDirection: 'column' }}>
              {children}
            </View>
          </ContentContainer>
        </View>
      )
    }
    return (
      <View style={{ flex: 1, overflow: 'hidden' }}>
        <ImageBackground
          style={{ position: 'absolute', left: 0, top: 0, height: windowSize.height, width: windowSize.width, backgroundColor: theme['c-content-background'] }}
          source={{ uri: pic!, headers: defaultHeaders }}
          resizeMode="cover"
          blurRadius={BLUR_RADIUS}
        />
        <View
          pointerEvents="none"
          style={[
            StyleSheet.absoluteFill,
            {
              backgroundColor: theme['c-content-background'],
              opacity: 0.76,
            },
          ]}
        />
        <ContentContainer>
          <View style={{ flex: 1, flexDirection: 'column' }}>
            {children}
          </View>
        </ContentContainer>
      </View>
    )
  }, [children, pic, theme, isGlass, windowSize.height, windowSize.width])

  return (
    <>
      <SizeView />
      {pic ? picComponent : isGlass ? glassComponent : themeComponent}
    </>
  )
}
