import { memo, useRef } from 'react'
import { Animated, Easing, Image, TouchableOpacity } from 'react-native'
import { scaleSizeW } from '@/utils/pixelRatio'
import { haptic } from '@/utils/haptics'
import { GLASS_CIRCLE_SIZE, glassCircleStyle } from '@/screens/PlayDetail/Vertical/Player/components/MoreBtn/glassButton'

// eslint-disable-next-line @typescript-eslint/no-var-requires
const ICON_LIST = require('@/resources/images/icon_list.png')

/**
 * 播放页操作行的「当前播放列表」按钮。
 * 层级结构与 MoreBtn/Btn 完全一致（Animated.View > TouchableOpacity > 图标），
 * 保证四个按钮尺寸、圆底、对齐完全相同。
 */
export default memo(({ onPress }: { onPress: () => void }) => {
  const pressScale = useRef(new Animated.Value(1)).current
  const animateTo = (to: number) => {
    Animated.timing(pressScale, { toValue: to, duration: to < 1 ? 90 : 180, easing: Easing.out(Easing.cubic), useNativeDriver: true }).start()
  }

  return (
    <Animated.View style={{ transform: [{ scale: pressScale }] }}>
      <TouchableOpacity
        style={glassCircleStyle(GLASS_CIRCLE_SIZE)}
        activeOpacity={1}
        onPressIn={() => { animateTo(0.96) }}
        onPressOut={() => { animateTo(1) }}
        onPress={() => { haptic.tap(); onPress() }}
      >
        <Image
          source={ICON_LIST}
          style={{ width: scaleSizeW(19), height: scaleSizeW(19), alignSelf: 'center' }}
          resizeMode="contain"
        />
      </TouchableOpacity>
    </Animated.View>
  )
})
