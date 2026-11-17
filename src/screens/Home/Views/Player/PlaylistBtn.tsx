import { memo, useRef } from 'react'
import { Animated, Easing, Image, TouchableOpacity } from 'react-native'
import { scaleSizeW } from '@/utils/pixelRatio'
import { haptic } from '@/utils/haptics'
import { GLASS_CIRCLE_SIZE, glassCircleStyle } from '@/screens/PlayDetail/Vertical/Player/components/MoreBtn/glassButton'

// eslint-disable-next-line @typescript-eslint/no-var-requires
const ICON_LIST = require('@/resources/images/icon_list.png')

/** 播放页操作行的「当前播放列表」按钮：与其它按钮共用同一套玻璃底和尺寸 */
export default memo(({ onPress }: { onPress: () => void }) => {
  const scale = useRef(new Animated.Value(1)).current
  const animateTo = (to: number) => {
    Animated.timing(scale, { toValue: to, duration: to < 1 ? 90 : 180, easing: Easing.out(Easing.cubic), useNativeDriver: true }).start()
  }
  return (
    <TouchableOpacity
      activeOpacity={0.7}
      onPress={() => { haptic.tap(); onPress() }}
      onPressIn={() => { animateTo(0.96) }}
      onPressOut={() => { animateTo(1) }}
    >
      <Animated.View style={[glassCircleStyle(GLASS_CIRCLE_SIZE), { transform: [{ scale }] }]}>
        <Image source={ICON_LIST} style={{ width: scaleSizeW(19), height: scaleSizeW(19) }} resizeMode="contain" />
      </Animated.View>
    </TouchableOpacity>
  )
})
