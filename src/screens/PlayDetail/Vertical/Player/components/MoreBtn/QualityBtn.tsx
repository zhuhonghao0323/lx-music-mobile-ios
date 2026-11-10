import { memo, useMemo, useRef } from 'react'
import { Animated, Easing, StyleSheet, TouchableOpacity } from 'react-native'
import { useTheme } from '@/store/theme/hook'
import { useSettingValue } from '@/store/setting/hook'
import { updateSetting } from '@/core/common'
import { setMusicUrl } from '@/core/player/player'
import playerState from '@/store/player/state'
import { TRY_QUALITYS_LIST } from '@/core/music/utils'
import { formatQuality, formatQualityShort, useCurrentPlayQuality } from '@/store/player/quality'
import { BTN_WIDTH } from './Btn'
import { GLASS_CIRCLE_SIZE, QUALITY_TEXT_SIZE, glassCircleStyle } from './glassButton'
import Text from '@/components/common/Text'
import Menu, { type MenuType, type Menus, type Position } from '@/components/common/Menu'
import { useIsGlass } from '@/theme/glass'
import { haptic } from '@/utils/haptics'

/**
 * 底部功能行：显示当前音质，点击弹出音质选择，切换后按新音质重新取 URL。
 * 玻璃主题下与其它三个辅助按钮使用同一套圆形玻璃底，保证视觉一致。
 */
export default memo(() => {
  const theme = useTheme()
  const isGlass = useIsGlass()
  const playQuality = useSettingValue('player.playQuality')
  const currentQuality = useCurrentPlayQuality()
  const menuRef = useRef<MenuType>(null)
  const btnRef = useRef<TouchableOpacity>(null)

  // 按压回弹，与其它辅助按钮一致
  const pressScale = useRef(new Animated.Value(1)).current
  const animateTo = (to: number) => {
    Animated.timing(pressScale, {
      toValue: to,
      duration: to < 1 ? 90 : 180,
      easing: Easing.out(Easing.cubic),
      useNativeDriver: true,
    }).start()
  }

  const qualities = useMemo(() => {
    return [...TRY_QUALITYS_LIST, '128k'].reverse() as LX.Quality[]
  }, [])

  // 弹窗里用完整文案（320kbps），按钮上用简写（320k）避免被裁切
  const menus = useMemo<Menus>(() => qualities.map(q => ({
    action: q,
    label: formatQuality(q),
  })), [qualities])

  const label = formatQualityShort(currentQuality ?? playQuality)

  const showMenu = () => {
    haptic.tap()
    btnRef.current?.measure((_x, _y, w, h, px, py) => {
      const position: Position = { x: Math.ceil(px), y: Math.ceil(py), w: Math.ceil(w), h: Math.ceil(h) }
      menuRef.current?.show(position, { width: Math.max(Math.ceil(w), 110), height: 40 })
    })
  }

  const handleSelect = (menu: Menus[number]) => {
    const q = menu.action as LX.Quality
    if (q == playQuality) return
    haptic.select()
    updateSetting({ 'player.playQuality': q })
    const musicInfo = playerState.playMusicInfo.musicInfo
    if (musicInfo) setMusicUrl(musicInfo, true)
  }

  const boxSize = isGlass ? GLASS_CIRCLE_SIZE : BTN_WIDTH

  return (
    <>
      <Animated.View style={isGlass ? { transform: [{ scale: pressScale }] } : undefined}>
        <TouchableOpacity
          ref={btnRef}
          style={StyleSheet.compose(
            styles.btn,
            isGlass ? glassCircleStyle(boxSize) : { width: boxSize, height: boxSize },
          )}
          activeOpacity={isGlass ? 1 : 0.5}
          onPressIn={isGlass ? () => { animateTo(0.96) } : undefined}
          onPressOut={isGlass ? () => { animateTo(1) } : undefined}
          onPress={showMenu}
        >
          <Text
            style={styles.text}
            size={isGlass ? QUALITY_TEXT_SIZE : 13}
            color={isGlass ? '#F5F2F1' : theme['c-font-label']}
            numberOfLines={1}
            // 极窄机型上自动缩字，保证 320k/24bit 完整显示
            adjustsFontSizeToFit
          >{label}</Text>
        </TouchableOpacity>
      </Animated.View>
      <Menu
        ref={menuRef}
        menus={menus}
        activeId={playQuality}
        center
        fontSize={12}
        onPress={handleSelect}
      />
    </>
  )
})

const styles = StyleSheet.create({
  btn: {
    justifyContent: 'center',
    alignItems: 'center',
    paddingHorizontal: 1,
  },
  text: {
    textAlign: 'center',
    includeFontPadding: false,
  },
})
