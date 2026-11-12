import { memo, useCallback, useMemo } from 'react'
import { View, TouchableOpacity, StyleSheet } from 'react-native'
import { useKeyboard } from '@/utils/hooks'

import Pic from './components/Pic'
import { createStyle } from '@/utils/tools'
import { useSettingValue } from '@/store/setting/hook'
import { useIsGlass } from '@/theme/glass'
import { usePlayerMusicInfo } from '@/store/player/hook'
import Text from '@/components/common/Text'
import MarqueeText from '@/components/common/MarqueeText'
import { useTheme } from '@/store/theme/hook'
import { scaleSizeW } from '@/utils/pixelRatio'
import { haptic } from '@/utils/haptics'
import { setNavActiveId } from '@/core/common'

/** 胶囊高度（圆角取一半，得到灵动岛式的半圆端头） */
const PILL_HEIGHT = scaleSizeW(52)

/**
 * 底部迷你条胶囊（对标波点 / 灵动岛）。
 *
 * 只显示：封面 + 歌名 + 歌手。
 * 宽度不再铺满（由父容器限制 maxWidth），圆角接近半圆（灵动岛弧度），
 * 整条可点击进入「正在播放」Tab。
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
          // 胶囊高度的一半作为圆角 = 完美的半圆端头（灵动岛圆弧）
          borderRadius: PILL_HEIGHT / 2,
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
      <View pointerEvents="none" style={[styles.glassSheen, { borderTopLeftRadius: PILL_HEIGHT / 2, borderTopRightRadius: PILL_HEIGHT / 2 }]} />
      {/* 封面（点击同样进播放页） */}
      <Pic isHome={isHome} />
      {/* 歌名 + 歌手（歌名过长时横向慢速滚动） */}
      <View style={styles.center}>
        <MarqueeText text={musicInfo.name} size={14} color={theme['c-font']} style={styles.songName} />
        <Text size={11} color={theme['c-font-label']} numberOfLines={1} style={styles.singer}>{musicInfo.singer}</Text>
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
    height: PILL_HEIGHT,
    paddingLeft: scaleSizeW(5),
    paddingRight: scaleSizeW(12),
  },
  // 顶部高光条：玻璃受光，3D 立体感
  glassSheen: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    height: '52%',
    backgroundColor: 'rgba(255,255,255,0.09)',
  },
  center: {
    flexDirection: 'column',
    flexGrow: 1,
    flexShrink: 1,
    paddingLeft: scaleSizeW(9),
    justifyContent: 'center',
  },
  songName: {
    fontWeight: '600',
  },
  singer: {
    marginTop: scaleSizeW(1),
  },
})
