import { Animated, Easing, TouchableOpacity, StyleSheet } from 'react-native'
import { useCallback, useRef } from 'react'
import { Icon } from '@/components/common/Icon'
import { createStyle } from '@/utils/tools'
import { useTheme } from '@/store/theme/hook'
import { scaleSizeW } from '@/utils/pixelRatio'
import { useIsGlass } from '@/theme/glass'
import { haptic } from '@/utils/haptics'

export const BTN_WIDTH = scaleSizeW(36)
export const BTN_ICON_SIZE = 24

/** 玻璃主题下底部辅助按钮的圆形底（设计规范：48–54，四个等宽分布） */
const GLASS_CIRCLE_SIZE = Math.max(44, scaleSizeW(46))

export default ({ icon, color, onPress, onLongPress }: {
  icon: string
  color?: string
  onPress: () => void
  onLongPress?: () => void
}) => {
  const theme = useTheme()
  const isGlass = useIsGlass()
  const glassSize = GLASS_CIRCLE_SIZE
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

  return (
    <Animated.View style={isGlass ? { transform: [{ scale: pressScale }] } : undefined}>
      <TouchableOpacity
        style={StyleSheet.compose(
          { ...styles.cotrolBtn, width: isGlass ? glassSize : BTN_WIDTH, height: isGlass ? glassSize : BTN_WIDTH },
          isGlass ? {
            // 设计规范：半透明白玻璃 + rgba(255,255,255,0.22) 细描边 + 顶部受光
            backgroundColor: 'rgba(255, 255, 255, 0.09)',
            borderWidth: StyleSheet.hairlineWidth,
            borderTopColor: 'rgba(255, 255, 255, 0.30)',
            borderLeftColor: 'rgba(255, 255, 255, 0.20)',
            borderRightColor: 'rgba(255, 255, 255, 0.16)',
            borderBottomColor: 'rgba(255, 255, 255, 0.10)',
            borderRadius: glassSize / 2,
            shadowColor: 'rgba(6, 4, 4, 0.55)',
            shadowOffset: { width: 0, height: 8 },
            shadowOpacity: 0.4,
            shadowRadius: 18,
          } : {},
        )}
        activeOpacity={isGlass ? 1 : 0.55}
        onPressIn={isGlass ? () => { animateTo(0.96) } : undefined}
        onPressOut={isGlass ? () => { animateTo(1) } : undefined}
        onPress={() => { haptic.tap(); onPress() }}
        onLongPress={onLongPress ? () => { haptic.longPress(); onLongPress() } : undefined}
      >
        <Icon name={icon} color={color ?? (isGlass ? '#F5F2F1' : theme['c-font-label'])} size={isGlass ? BTN_ICON_SIZE - 5 : BTN_ICON_SIZE} />
      </TouchableOpacity>
    </Animated.View>
  )
}

const styles = createStyle({
  cotrolBtn: {
    justifyContent: 'center',
    alignItems: 'center',

    // backgroundColor: '#ccc',
  },
})
