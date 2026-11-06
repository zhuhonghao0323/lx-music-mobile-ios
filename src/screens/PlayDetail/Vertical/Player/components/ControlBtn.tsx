import { TouchableOpacity, View, StyleSheet } from 'react-native'
import { Icon } from '@/components/common/Icon'
import { useTheme } from '@/store/theme/hook'
// import { useIsPlay } from '@/store/player/hook'
import { playNext, playPrev, togglePlay } from '@/core/player/player'
import { useIsPlay } from '@/store/player/hook'
import { createStyle } from '@/utils/tools'
import { useWindowSize } from '@/utils/hooks'
import { BTN_WIDTH } from './MoreBtn/Btn'
import { useMemo } from 'react'
import { markTimeoutExitInteraction } from '@/core/player/timeoutExit'
import { useIsGlass } from '@/theme/glass'

const glassButton = (size: number) => ({
  width: size,
  height: size,
  borderRadius: size / 2,
  backgroundColor: 'rgba(255, 255, 255, 0.14)',
  borderWidth: StyleSheet.hairlineWidth,
  borderColor: 'rgba(255, 255, 255, 0.38)',
  shadowColor: 'rgba(6, 10, 30, 0.5)',
  shadowOffset: { width: 0, height: 6 },
  shadowOpacity: 0.35,
  shadowRadius: 14,
  elevation: 4,
})
const useCtrlStyle = (size: number) => {
  const isGlass = useIsGlass()
  return useMemo(() => StyleSheet.compose(
    { ...styles.cotrolBtn, width: size, height: size },
    isGlass ? glassButton(size) : {},
  ), [size, isGlass])
}

const PrevBtn = ({ size }: { size: number }) => {
  const theme = useTheme()
  const btnStyle = useCtrlStyle(size)
  const isGlass = useIsGlass()
  const handlePlayPrev = () => {
    markTimeoutExitInteraction()
    void playPrev()
  }
  return (
    <TouchableOpacity style={btnStyle} activeOpacity={0.5} onPress={handlePlayPrev}>
      <Icon name='prevMusic' color={isGlass ? '#f4f8ff' : theme['c-button-font']} rawSize={size * 0.7} />
    </TouchableOpacity>
  )
}
const NextBtn = ({ size }: { size: number }) => {
  const theme = useTheme()
  const btnStyle = useCtrlStyle(size)
  const isGlass = useIsGlass()
  const handlePlayNext = () => {
    markTimeoutExitInteraction()
    void playNext()
  }
  return (
    <TouchableOpacity style={btnStyle} activeOpacity={0.5} onPress={handlePlayNext}>
      <Icon name='nextMusic' color={isGlass ? '#f4f8ff' : theme['c-button-font']} rawSize={size * 0.7} />
    </TouchableOpacity>
  )
}

const TogglePlayBtn = ({ size }: { size: number }) => {
  const theme = useTheme()
  const isPlay = useIsPlay()
  const btnStyle = useCtrlStyle(size)
  const isGlass = useIsGlass()
  return (
    <TouchableOpacity style={btnStyle} activeOpacity={0.5} onPress={() => {
      markTimeoutExitInteraction()
      togglePlay()
    }}>
      <Icon name={isPlay ? 'pause' : 'play'} color={isGlass ? '#f4f8ff' : theme['c-button-font']} rawSize={size * 0.7} />
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
