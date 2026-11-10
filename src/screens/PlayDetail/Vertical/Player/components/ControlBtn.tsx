import { Animated, Easing, TouchableOpacity, View, StyleSheet } from 'react-native'
import { Icon } from '@/components/common/Icon'
import { useTheme } from '@/store/theme/hook'
// import { useIsPlay } from '@/store/player/hook'
import { playNext, playPrev, togglePlay } from '@/core/player/player'
import { useIsPlay } from '@/store/player/hook'
import { createStyle } from '@/utils/tools'
import { useWindowSize } from '@/utils/hooks'
import { BTN_WIDTH } from './MoreBtn/Btn'
import { useEffect, useMemo, useRef } from 'react'
import { markTimeoutExitInteraction } from '@/core/player/timeoutExit'
import { useIsGlass } from '@/theme/glass'
import { haptic } from '@/utils/haptics'

const glassButton = (size: number) => ({
  width: size,
  height: size,
  borderRadius: size / 2,
  backgroundColor: 'rgba(255, 255, 255, 0.10)',
  borderWidth: StyleSheet.hairlineWidth,
  borderTopColor: 'rgba(255, 255, 255, 0.30)',
  borderLeftColor: 'rgba(255, 255, 255, 0.20)',
  borderRightColor: 'rgba(255, 255, 255, 0.16)',
  borderBottomColor: 'rgba(255, 255, 255, 0.10)',
  shadowColor: 'rgba(6, 4, 4, 0.55)',
  shadowOffset: { width: 0, height: 10 },
  shadowOpacity: 0.45,
  shadowRadius: 22,
  elevation: 4,
})

/**
 * 主播放键的玻璃样式（设计规范：76–84，最大视觉焦点，
 * 圆形玻璃按钮 + 轻微的暖色 tint 强调）。
 */
const glassPlayButton = (size: number) => ({
  width: size,
  height: size,
  borderRadius: size / 2,
  // 暖色 tint：珊瑚色低透明度，与强调色呼应但不抢主次
  backgroundColor: 'rgba(242, 120, 104, 0.18)',
  borderWidth: StyleSheet.hairlineWidth,
  borderTopColor: 'rgba(255, 220, 214, 0.42)',
  borderLeftColor: 'rgba(255, 200, 192, 0.26)',
  borderRightColor: 'rgba(255, 200, 192, 0.18)',
  borderBottomColor: 'rgba(255, 200, 192, 0.12)',
  shadowColor: 'rgba(242, 120, 104, 0.35)',
  shadowOffset: { width: 0, height: 8 },
  shadowOpacity: 0.5,
  shadowRadius: 24,
  elevation: 6,
})
const useCtrlStyle = (size: number) => {
  const isGlass = useIsGlass()
  return useMemo(() => StyleSheet.compose(
    { ...styles.cotrolBtn, width: size, height: size },
    isGlass ? glassButton(size) : {},
  ), [size, isGlass])
}

/** 主播放键：玻璃主题下用更大的圆形 + 暖色 tint，其余主题沿用普通按钮样式 */
const usePlayStyle = (size: number) => {
  const isGlass = useIsGlass()
  return useMemo(() => StyleSheet.compose(
    { ...styles.cotrolBtn, width: size, height: size },
    isGlass ? glassPlayButton(size) : {},
  ), [size, isGlass])
}

const PrevBtn = ({ size }: { size: number }) => {
  const theme = useTheme()
  const btnStyle = useCtrlStyle(size)
  const isGlass = useIsGlass()
  const handlePlayPrev = () => {
    haptic.trackChange()
    markTimeoutExitInteraction()
    void playPrev()
  }
  return (
    <TouchableOpacity style={btnStyle} activeOpacity={0.5} onPress={handlePlayPrev}>
      <Icon name='prevMusic' color={isGlass ? '#F5F2F1' : theme['c-button-font']} rawSize={size * 0.7} />
    </TouchableOpacity>
  )
}
const NextBtn = ({ size }: { size: number }) => {
  const theme = useTheme()
  const btnStyle = useCtrlStyle(size)
  const isGlass = useIsGlass()
  const handlePlayNext = () => {
    haptic.trackChange()
    markTimeoutExitInteraction()
    void playNext()
  }
  return (
    <TouchableOpacity style={btnStyle} activeOpacity={0.5} onPress={handlePlayNext}>
      <Icon name='nextMusic' color={isGlass ? '#F5F2F1' : theme['c-button-font']} rawSize={size * 0.7} />
    </TouchableOpacity>
  )
}

const TogglePlayBtn = ({ size }: { size: number }) => {
  const theme = useTheme()
  const isPlay = useIsPlay()
  const isGlass = useIsGlass()
  // 玻璃主题下主播放键放大到规范的 76–84 区间
  const playSize = isGlass ? Math.min(Math.max(size * 1.18, 76), 84) : size
  const btnStyle = usePlayStyle(playSize)

  // 设计规范：播放/暂停切换时图标轻微缩放 + 淡变，约 140–180ms，不改变布局
  const iconAnim = useRef(new Animated.Value(1)).current
  useEffect(() => {
    iconAnim.setValue(0.82)
    Animated.timing(iconAnim, {
      toValue: 1,
      duration: 160,
      easing: Easing.out(Easing.cubic),
      useNativeDriver: true,
    }).start()
  }, [isPlay, iconAnim])

  return (
    <TouchableOpacity style={btnStyle} activeOpacity={0.6} onPress={() => {
      haptic.playToggle()
      markTimeoutExitInteraction()
      togglePlay()
    }}>
      <Animated.View style={{ transform: [{ scale: iconAnim }], opacity: iconAnim }}>
        <Icon name={isPlay ? 'pause' : 'play'} color={isGlass ? '#F5F2F1' : theme['c-button-font']} rawSize={playSize * (isGlass ? 0.5 : 0.7)} />
      </Animated.View>
    </TouchableOpacity>
  )
}

const MAX_SIZE = BTN_WIDTH * 1.6
const MIN_SIZE = BTN_WIDTH * 1.2

export default () => {
  const winSize = useWindowSize()
  const maxHeight = Math.max(winSize.height * 0.11, MIN_SIZE)
  const containerStyle = useMemo(() => {
    return {
      ...styles.conatiner,
      maxHeight,
    }
  }, [maxHeight])
  const size = Math.min(Math.max(winSize.width * 0.33 * global.lx.fontSize * 0.4, MIN_SIZE), MAX_SIZE, maxHeight)

  return (
    <View style={containerStyle}>
      <PrevBtn size={size} />
      <TogglePlayBtn size={size}/>
      <NextBtn size={size} />
    </View>
  )
}


const styles = createStyle({
  conatiner: {
    flexDirection: 'row',
    justifyContent: 'space-evenly',
    alignItems: 'center',
    flexGrow: 1,
    flexShrink: 1,
    paddingHorizontal: '4%',
    paddingVertical: 22,
    // backgroundColor: 'rgba(0, 0, 0, .1)',
  },
  cotrolBtn: {
    justifyContent: 'center',
    alignItems: 'center',

    // backgroundColor: '#ccc',
  },
})
