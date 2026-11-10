import { Animated, Easing, TouchableOpacity, StyleSheet } from 'react-native'
import { useCallback, useRef } from 'react'
import { Icon } from '@/components/common/Icon'
import { createStyle } from '@/utils/tools'
import { useTheme } from '@/store/theme/hook'
import { scaleSizeW } from '@/utils/pixelRatio'
import { useIsGlass } from '@/theme/glass'
import { haptic } from '@/utils/haptics'
import { GLASS_CIRCLE_SIZE, glassCircleStyle } from './glassButton'

export const BTN_WIDTH = scaleSizeW(36)
export const BTN_ICON_SIZE = 24

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
          styles.cotrolBtn,
          isGlass ? glassCircleStyle(glassSize) : { width: BTN_WIDTH, height: BTN_WIDTH },
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
