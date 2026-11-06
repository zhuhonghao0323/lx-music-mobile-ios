import { memo, useEffect, useRef } from 'react'
import { Animated, Easing, StyleSheet, Text } from 'react-native'
import { Icon } from '@/components/common/Icon'
import { scaleSizeW } from '@/utils/pixelRatio'
import { setFavoriteArriveListener } from './FavoriteDockAnimation'

export const FAVORITE_COLOR = '#ff4d6d'

/**
 * 收藏状态图标：
 * - 已收藏：实心红色爱心
 * - 未收藏：空心爱心 + 加号
 * - 封面收进心形时：晃动 + 弹跳 + 变红，作为「已收藏」的动效反馈
 */
const FavoriteIcon = memo(({ favorited, iconSize, emptyColor }: {
  favorited: boolean
  iconSize: number
  emptyColor?: string
}) => {
  const shake = useRef(new Animated.Value(0)).current
  const pop = useRef(new Animated.Value(1)).current

  // 订阅「封面已到达心形」，播放晃动反馈
  useEffect(() => {
    setFavoriteArriveListener((direction) => {
      if (direction != 'add') return
      shake.setValue(0)
      pop.setValue(1)
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
    })
    return () => { setFavoriteArriveListener(null) }
  }, [shake, pop])

  const rotate = shake.interpolate({ inputRange: [-1, 0, 1], outputRange: ['-14deg', '0deg', '14deg'] })

  if (!favorited) return <Icon name="add-music" color={emptyColor} size={iconSize} />

  return (
    <Animated.View style={[styles.container, { transform: [{ rotate }, { scale: pop }] }]} pointerEvents="none">
      <Text style={[styles.heart, { fontSize: scaleSizeW(iconSize), lineHeight: scaleSizeW(iconSize) * 1.2, color: FAVORITE_COLOR }]}>♥</Text>
    </Animated.View>
  )
})

const styles = StyleSheet.create({
  container: {
    justifyContent: 'center',
    alignItems: 'center',
  },
  heart: {
    textAlign: 'center',
    fontWeight: 'bold',
  },
})

export default FavoriteIcon
