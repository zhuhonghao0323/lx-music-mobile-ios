import { memo, useMemo, useRef } from 'react'
import { TouchableOpacity, StyleSheet } from 'react-native'
import { useTheme } from '@/store/theme/hook'
import { useSettingValue } from '@/store/setting/hook'
import { updateSetting } from '@/core/common'
import { setMusicUrl } from '@/core/player/player'
import playerState from '@/store/player/state'
import { TRY_QUALITYS_LIST } from '@/core/music/utils'
import { formatQuality, useCurrentPlayQuality } from '@/store/player/quality'
import { BTN_WIDTH } from './Btn'
import Text from '@/components/common/Text'
import Menu, { type MenuType, type Menus, type Position } from '@/components/common/Menu'
import { haptic } from '@/utils/haptics'

/** 底部功能行：显示当前音质，点击弹出音质选择，切换后按新音质重新取 URL */
export default memo(() => {
  const theme = useTheme()
  const playQuality = useSettingValue('player.playQuality')
  const currentQuality = useCurrentPlayQuality()
  const menuRef = useRef<MenuType>(null)
  const btnRef = useRef<TouchableOpacity>(null)

  const qualities = useMemo(() => {
    return [...TRY_QUALITYS_LIST, '128k'].reverse() as LX.Quality[]
  }, [])

  const menus = useMemo<Menus>(() => qualities.map(q => ({
    action: q,
    label: formatQuality(q),
  })), [qualities])

  const label = formatQuality(currentQuality ?? playQuality)

  const showMenu = () => {
    haptic.tap()
    btnRef.current?.measure((_x, _y, w, h, px, py) => {
      const position: Position = { x: Math.ceil(px), y: Math.ceil(py), w: Math.ceil(w), h: Math.ceil(h) }
      menuRef.current?.show(position, { width: Math.max(Math.ceil(w), 96), height: 40 })
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

  return (
    <>
      <TouchableOpacity
        ref={btnRef}
        style={[styles.btn, { width: BTN_WIDTH, height: BTN_WIDTH }]}
        activeOpacity={0.5}
        onPress={showMenu}
      >
        <Text style={styles.text} size={14} color={theme['c-font-label']} numberOfLines={1}>{label}</Text>
      </TouchableOpacity>
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
    paddingHorizontal: 2,
  },
  text: {
    textAlign: 'center',
  },
})
