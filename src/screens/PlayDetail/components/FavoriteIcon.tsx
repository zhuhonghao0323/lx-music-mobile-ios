import { memo, useEffect, useRef } from 'react'
import { Animated, Easing, Image, StyleSheet } from 'react-native'
import { addFavoriteArriveListener } from './FavoriteDockAnimation'

// eslint-disable-next-line @typescript-eslint/no-var-requires
const ICON_STAR_NORMAL = require('@/resources/images/star_normal.png')
// eslint-disable-next-line @typescript-eslint/no-var-requires
const ICON_STAR_FILLED = require('@/resources/images/star_filled.png')

export const FAVORITE_COLOR = '#ff4d6d'

/**
 * 收藏状态图标（星形）：
 * - 已收藏：实心红色星
 * - 未收藏：空心灰色星
 * - 封面飞到星形时：收藏(add) 播放晃动 + 弹跳；取消(remove) 播放收缩回弹。
 *   两个方向都有反馈，未收藏态同样用 Animated.View 承载动画。
 */
const FavoriteIcon = memo(({ favorited, iconSize }: {
  favorited: boolean
  iconSize: number
  emptyColor?: string
}) => {
  const shake = useRef(new Animated.Value(0)).current
  const pop = useRef(new Animated.Value(1)).current

  // 订阅「封面已到达星形」，收藏 / 取消收藏都给出图标反馈
  useEffect(() => {
    return addFavoriteArriveListener((direction) => {
      shake.setValue(0)
      pop.setValue(1)
      if (direction == 'add') {
        Animated.parallel([
          Animated.sequence([
            Animated.timing(shake, { toValue: 1, duration: 60, useNativeDriver: true }),
            Animated.timing(shake, { toValue: -1, duration: 60, useNativeDriver: true }),
            Animated.timing(shake, { toValue: 0.7, duration: 55, useNativeDriver: true }),
            Animated.timing(shake, { toValue: -0.5, duration: 55, useNativeDriver: true }),
            Animated.timing(shake, { toValue: 0, duration: 60, easing: Easing.out(Easing.quad), useNativeDriver: true }),
          ]),
          Animated.sequence([
            Animated.timing(pop, { toValue: 1.45, duration: 130, easing: Easing.out(Easing.quad), useNativeDriver: true }),
            Animated.spring(pop, { toValue: 1, friction: 4, tension: 160, useNativeDriver: true }),
          ]),
        ]).start()
      } else {
        // 取消收藏：短促收缩回弹，明确给出「已移除」反馈
        Animated.sequence([
          Animated.timing(pop, { toValue: 0.72, duration: 110, easing: Easing.out(Easing.quad), useNativeDriver: true }),
          Animated.spring(pop, { toValue: 1, friction: 5, tension: 180, useNativeDriver: true }),
        ]).start()
      }
    })
  }, [shake, pop])

  const rotate = shake.interpolate({ inputRange: [-1, 0, 1], outputRange: ['-14deg', '0deg', '14deg'] })
  const source = favorited ? ICON_STAR_FILLED : ICON_STAR_NORMAL

  return (
    <Animated.View style={[styles.container, { transform: [{ rotate }, { scale: pop }] }]} pointerEvents="none">
      <Image source={source} style={[styles.star, { width: iconSize, height: iconSize }]} resizeMode="contain" />
    </Animated.View>
  )
})

const styles = StyleSheet.create({
  container: {
    justifyContent: 'center',
    alignItems: 'center',
  },
  star: {
    resizeMode: 'contain',
  },
})

export default FavoriteIcon
