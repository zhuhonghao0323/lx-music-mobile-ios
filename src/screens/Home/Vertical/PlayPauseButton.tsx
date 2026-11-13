import { memo, useCallback, useRef } from 'react'
import { Animated, Easing, TouchableOpacity, View } from 'react-native'
import { Icon } from '@/components/common/Icon'
import { useTheme } from '@/store/theme/hook'
import { useIsPlay } from '@/store/player/hook'
import { createStyle } from '@/utils/tools'
import { scaleSizeW } from '@/utils/pixelRatio'
import { useIsGlass } from '@/theme/glass'
import { haptic } from '@/utils/haptics'
import { togglePlay } from '@/core/player/player'
import { markTimeoutExitInteraction } from '@/core/player/timeoutExit'

/**
 * 播放页底部中间的播放/暂停按钮（对标波点的大椭圆胶囊）。
 * 由 BottomNavBar 的中间插槽承载，与左右两个圆形图标组成「三个按钮」一行。
 */
export default memo(() => {
  const theme = useTheme()
  const isPlay = useIsPlay()
  const isGlass = useIsGlass()
  const scale = useRef(new Animated.Value(1)).current

  const animateTo = (to: number) => {
    Animated.timing(scale, {
      toValue: to,
      duration: to < 1 ? 90 : 180,
      easing: Easing.out(Easing.cubic),
      useNativeDriver: true,
    }).start()
  }

  const handlePress = useCallback(() => {
    haptic.playToggle()
    markTimeoutExitInteraction()
    togglePlay()
  }, [])

  return (
    <TouchableOpacity
      activeOpacity={1}
      onPress={handlePress}
      onPressIn={() => { animateTo(0.94) }}
      onPressOut={() => { animateTo(1) }}
      accessibilityRole="button"
      accessibilityLabel={isPlay ? '暂停' : '播放'}
    >
      <Animated.View style={[styles.pill, {
        transform: [{ scale }],
        backgroundColor: isGlass ? 'rgba(255,255,255,0.14)' : theme['c-primary-light-500-alpha-800'],
        borderTopColor: 'rgba(255,255,255,0.38)',
        borderLeftColor: 'rgba(255,255,255,0.22)',
        borderRightColor: 'rgba(255,255,255,0.16)',
        borderBottomColor: 'rgba(0,0,0,0.28)',
      }]}>
        {/* 顶部高光：3D 液态质感 */}
        <View pointerEvents="none" style={styles.sheen} />
        <Icon name={isPlay ? 'pause' : 'play'} size={26} color={theme['c-font']} />
      </Animated.View>
    </TouchableOpacity>
  )
})

const styles = createStyle({
  pill: {
    width: '100%',
    height: scaleSizeW(56),
    borderRadius: scaleSizeW(28),
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 0.5,
    shadowColor: 'rgba(0,0,0,0.45)',
    shadowOffset: { width: 0, height: 8 },
    shadowOpacity: 0.4,
    shadowRadius: 14,
    elevation: 8,
    overflow: 'hidden',
  },
  sheen: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    height: '52%',
    backgroundColor: 'rgba(255,255,255,0.12)',
  },
})
