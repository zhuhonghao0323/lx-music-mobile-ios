import { memo } from 'react'
import { StyleSheet, View, Text } from 'react-native'
import { Icon } from '@/components/common/Icon'
import { scaleSizeW } from '@/utils/pixelRatio'

export const FAVORITE_COLOR = '#ff4d6d'

/**
 * 收藏状态图标：
 * - 已收藏：实心红色爱心（用系统字体的 ♥ 字形，iOS / Android 都能可靠显示为实心）
 * - 未收藏：原来的「添加收藏」图标（空心爱心 + 加号）
 */
const FavoriteIcon = memo(({ favorited, iconSize, emptyColor }: {
  favorited: boolean
  iconSize: number
  emptyColor?: string
}) => {
  if (!favorited) return <Icon name="add-music" color={emptyColor} size={iconSize} />
  return (
    <View style={styles.container} pointerEvents="none">
      <Text style={[styles.heart, { fontSize: scaleSizeW(iconSize), lineHeight: scaleSizeW(iconSize) * 1.2, color: FAVORITE_COLOR }]}>♥</Text>
    </View>
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
