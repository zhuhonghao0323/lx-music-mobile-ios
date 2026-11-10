import { useCallback, useRef } from 'react'
import { Animated, Easing, TouchableOpacity, View, StyleSheet } from 'react-native'
import { Icon } from '@/components/common/Icon'
import { createStyle } from '@/utils/tools'
import { scaleSizeH, scaleSizeW } from '@/utils/pixelRatio'
import { HEADER_HEIGHT as _HEADER_HEIGHT } from '@/config/constant'
import { useIsGlass } from '@/theme/glass'
import { haptic } from '@/utils/haptics'

export const HEADER_HEIGHT = scaleSizeH(_HEADER_HEIGHT)

/** 顶部圆形玻璃按钮直径（设计规范：44–48，触控热区至少 44×44） */
const GLASS_BTN_SIZE = Math.max(38, scaleSizeW(40))

/**
 * 顶部快捷按钮。
 * 液态玻璃主题下渲染为圆形玻璃按钮（半透明白底 + 细描边 + 顶部高光），
 * 其余主题保持原来的纯图标样式。
 */
export default ({ icon, size = 18, color, onPress }: {
  icon: string
  size?: number
  color?: string
  onPress: () => void
}) => {
  const isGlass = useIsGlass()
  // 设计稿顶部按钮为细线图标，玻璃主题下略收一档更接近线框观感
  const iconSize = isGlass ? Math.max(14, size - 2) : size
  // 设计规范：按钮按下缩至 0.96，松开回弹至 1.0
  const pressScale = useRef(new Animated.Value(1)).current
  const animateTo = useCallback((to: number) => {
    Animated.timing(pressScale, {
      toValue: to,
      duration: to < 1 ? 90 : 180,
      easing: Easing.out(Easing.cubic),
      useNativeDriver: true,
    }).start()
  }, [pressScale])

  const handlePress = () => {
    haptic.tap()
    onPress()
  }

  if (!isGlass) {
    return (
      <TouchableOpacity onPress={handlePress} style={{ ...styles.button, width: HEADER_HEIGHT }}>
        <Icon name={icon} color={color} size={iconSize} />
      </TouchableOpacity>
    )
  }

  return (
    <TouchableOpacity
      onPress={handlePress}
      onPressIn={() => { animateTo(0.96) }}
      onPressOut={() => { animateTo(1) }}
      activeOpacity={1}
      style={styles.glassWrap}
      // 触控热区至少 44×44
      hitSlop={{ top: 6, bottom: 6, left: 4, right: 4 }}
    >
      <Animated.View style={{ transform: [{ scale: pressScale }] }}>
        <View style={styles.glassCircle}>
          {/* 顶部柔和高光，模拟玻璃受光 */}
          <View pointerEvents="none" style={styles.glassHighlight} />
          <Icon name={icon} color={color ?? 'rgba(245,242,241,0.92)'} size={iconSize} />
        </View>
      </Animated.View>
    </TouchableOpacity>
  )
}

const styles = createStyle({
  button: {
    justifyContent: 'center',
    alignItems: 'center',
    height: '100%',
    flex: 0,
  },
  glassWrap: {
    justifyContent: 'center',
    alignItems: 'center',
    height: '100%',
    flex: 0,
    paddingHorizontal: scaleSizeW(3),
  },
  glassCircle: {
    width: GLASS_BTN_SIZE,
    height: GLASS_BTN_SIZE,
    borderRadius: GLASS_BTN_SIZE / 2,
    // 设计规范：玻璃底 半透明白 + 描边 rgba(255,255,255,0.22)
    backgroundColor: 'rgba(255,255,255,0.09)',
    borderWidth: StyleSheet.hairlineWidth,
    borderTopColor: 'rgba(255,255,255,0.30)',
    borderLeftColor: 'rgba(255,255,255,0.20)',
    borderRightColor: 'rgba(255,255,255,0.16)',
    borderBottomColor: 'rgba(255,255,255,0.10)',
    justifyContent: 'center',
    alignItems: 'center',
    overflow: 'hidden',
  },
  glassHighlight: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    height: '52%',
    backgroundColor: 'rgba(255,255,255,0.07)',
  },
})
