import { memo, useCallback, useMemo } from 'react'
import { View, TouchableOpacity, StyleSheet } from 'react-native'
import { useKeyboard } from '@/utils/hooks'

import Pic from './components/Pic'
import { createStyle } from '@/utils/tools'
import { useSettingValue } from '@/store/setting/hook'
import { useIsGlass } from '@/theme/glass'
import { usePlayerMusicInfo } from '@/store/player/hook'
import Text from '@/components/common/Text'
import { useTheme } from '@/store/theme/hook'
import { scaleSizeW } from '@/utils/pixelRatio'
import { haptic } from '@/utils/haptics'
import { setNavActiveId } from '@/core/common'

/**
 * 底部迷你条胶囊（对标波点）。
 *
 * 只显示：封面 + 歌名 + 歌手。不显示进度时间、不放播放/下一首按钮。
 * 整条可点击进入「正在播放」Tab（点封面、点歌名、点任意区域行为一致）。
 * 高度比之前更高，更接近波点的大胶囊。
 */
export default memo(({ isHome = false }: { isHome?: boolean }) => {
  const { keyboardShown } = useKeyboard()
  const isGlass = useIsGlass()
  const theme = useTheme()
  const musicInfo = usePlayerMusicInfo()
  const autoHidePlayBar = useSettingValue('common.autoHidePlayBar')

  const handlePressBar = useCallback(() => {
    haptic.tap()
    setNavActiveId('nav_player')
  }, [])

  const playerComponent = useMemo(() => (
    <TouchableOpacity
      activeOpacity={0.85}
      onPress={handlePressBar}
      style={StyleSheet.compose(
        styles.container,
        {
          backgroundColor: isGlass ? 'rgba(28,24,24,0.72)' : 'rgba(24,22,22,0.94)',
          borderRadius: 26,
          borderWidth: StyleSheet.hairlineWidth,
          borderTopColor: 'rgba(255,255,255,0.32)',
          borderLeftColor: 'rgba(255,255,255,0.18)',
          borderRightColor: 'rgba(255,255,255,0.12)',
          borderBottomColor: 'rgba(0,0,0,0.30)',
          overflow: 'hidden',
          shadowColor: 'rgba(0,0,0,0.55)',
          shadowOffset: { width: 0, height: 10 },
          shadowOpacity: 0.5,
          shadowRadius: 18,
          elevation: 10,
        },
      )}
    >
      {/* 顶部高光条：模拟玻璃受光，增强立体感 */}
      <View pointerEvents="none" style={styles.glassSheen} />
      {/* 封面（点击同样进播放页） */}
      <Pic isHome={isHome} />
      {/* 歌名 + 歌手 */}
      <View style={styles.center}>
        <Text size={15} color={theme['c-font']} numberOfLines={1} style={styles.songName}>{musicInfo.name}</Text>
        <Text size={12} color={theme['c-font-label']} numberOfLines={1} style={styles.singer}>{musicInfo.singer}</Text>
      </View>
    </TouchableOpacity>
  ), [isHome, isGlass, theme, musicInfo.name, musicInfo.singer, handlePressBar])

  return autoHidePlayBar && keyboardShown ? null : playerComponent
})

const styles = createStyle({
  container: {
    width: '100%',
    flexDirection: 'row',
    alignItems: 'center',
    // 增高：更接近波点大胶囊
    height: scaleSizeW(64),
    paddingHorizontal: scaleSizeW(6),
  },
  // 顶部高光条：玻璃受光，3D 立体感
  glassSheen: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    height: '52%',
    backgroundColor: 'rgba(255,255,255,0.09)',
    borderTopLeftRadius: 26,
    borderTopRightRadius: 26,
  },
  center: {
    flexDirection: 'column',
    flexGrow: 1,
    flexShrink: 1,
    paddingLeft: scaleSizeW(10),
    justifyContent: 'center',
  },
  songName: {
    fontWeight: '600',
  },
  singer: {
    marginTop: scaleSizeW(2),
  },
})
