import { useCallback, useRef } from 'react'
import { Animated, Easing, StyleSheet, View, TouchableOpacity } from 'react-native'
import FavoriteBtn from '@/screens/PlayDetail/components/FavoriteBtn'
import FavoriteIcon from '@/screens/PlayDetail/components/FavoriteIcon'
import { createStyle } from '@/utils/tools'
import { useTheme } from '@/store/theme/hook'
import { useIsGlass } from '@/theme/glass'
import { BTN_ICON_SIZE } from './Btn'
import { GLASS_CIRCLE_SIZE, glassCircleStyle } from './glassButton'


export default () => {
  const theme = useTheme()
  const isGlass = useIsGlass()
  const boxSize = GLASS_CIRCLE_SIZE
  // 与其它三个按钮一致的按压缩放反馈
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
    <FavoriteBtn>
      {({ favorited, onPress, onLongPress, setAnchorRef }) => (
        // 外层 View 作为测量锚点：尺寸恒等于按钮，避免不同父容器下 measure 偏差
        <View ref={setAnchorRef} style={{ width: boxSize, height: boxSize }}>
          <Animated.View style={{ transform: [{ scale: pressScale }] }}>
            <TouchableOpacity
              style={StyleSheet.compose(
                styles.cotrolBtn,
                glassCircleStyle(boxSize),
              )}
              activeOpacity={1}
              onPressIn={() => { animateTo(0.96) }}
              onPressOut={() => { animateTo(1) }}
              onPress={onPress}
              onLongPress={onLongPress}
            >
              <FavoriteIcon favorited={favorited} iconSize={BTN_ICON_SIZE - 5} emptyColor={isGlass ? '#F5F2F1' : theme['c-font-label']} />
            </TouchableOpacity>
          </Animated.View>
        </View>
      )}
    </FavoriteBtn>
  )
}

const styles = createStyle({
  cotrolBtn: {
    justifyContent: 'center',
    alignItems: 'center',
  },
})
