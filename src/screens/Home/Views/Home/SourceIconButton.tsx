import { memo, useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { TouchableOpacity, Image } from 'react-native'
import { scaleSizeW } from '@/utils/pixelRatio'
import { createStyle } from '@/utils/tools'
import { haptic } from '@/utils/haptics'
import { getSongListSetting, saveSongListSetting } from '@/utils/data'
import Menu, { type MenuType, type Menus, type Position } from '@/components/common/Menu'

// eslint-disable-next-line @typescript-eslint/no-var-requires
const ICON_KW = require('@/resources/images/platform_kw_box.png')
// eslint-disable-next-line @typescript-eslint/no-var-requires
const ICON_KG = require('@/resources/images/platform_kg.png')
// eslint-disable-next-line @typescript-eslint/no-var-requires
const ICON_WY = require('@/resources/images/platform_wy.png')
// eslint-disable-next-line @typescript-eslint/no-var-requires
const ICON_MG = require('@/resources/images/platform_mg.png')
// eslint-disable-next-line @typescript-eslint/no-var-requires
const ICON_TX = require('@/resources/images/platform_kw.png')

/**
 * 音源平台标识（真实平台 logo）。
 *   小蜗音乐 → 酷我 (kw)、小秋音乐 → QQ (tx)、小枸音乐 → 酷狗 (kg)、
 *   小芸音乐 → 网易云 (wy)、小蜜音乐 → 咪咕 (mg)
 *
 * 注：QQ 音乐未提供 logo，暂用「圈圈音乐」图标占位。
 */
const PLATFORMS: Array<{
  id: LX.OnlineSource
  icon: number
  name: string
}> = [
  { id: 'kw', icon: ICON_KW, name: '酷我音乐' },
  { id: 'tx', icon: ICON_TX, name: 'QQ音乐' },
  { id: 'kg', icon: ICON_KG, name: '酷狗音乐' },
  { id: 'wy', icon: ICON_WY, name: '网易云音乐' },
  { id: 'mg', icon: ICON_MG, name: '咪咕音乐' },
]

/** 首页顶栏的「Music」位：真实平台图标筛选按钮 */
export default memo(() => {
  const menuRef = useRef<MenuType>(null)
  const btnRef = useRef<TouchableOpacity>(null)
  const [source, setSource] = useState<LX.OnlineSource>('kw')

  useEffect(() => {
    void getSongListSetting().then(info => { setSource(info.source) })
  }, [])

  const current = PLATFORMS.find(p => p.id == source) ?? PLATFORMS[0]

  const menus = useMemo<Menus>(() => PLATFORMS.map(p => ({
    action: p.id,
    label: p.name,
  })), [])

  const showMenu = useCallback(() => {
    haptic.tap()
    btnRef.current?.measure((_x, _y, w, h, px, py) => {
      const position: Position = { x: Math.ceil(px), y: Math.ceil(py), w: Math.ceil(w), h: Math.ceil(h) }
      menuRef.current?.show(position, { width: 150, height: 44 })
    })
  }, [])

  const handleSelect = useCallback((menu: Menus[number]) => {
    const next = menu.action as LX.OnlineSource
    haptic.select()
    setSource(next)
    void saveSongListSetting({ source: next, tagId: '', tagName: '' })
    global.app_event.songlistSourceChanged(next)
  }, [])

  return (
    <>
      <TouchableOpacity ref={btnRef} style={styles.wrap} onPress={showMenu} activeOpacity={0.7}>
        <Image source={current.icon} style={styles.icon} resizeMode="contain" />
      </TouchableOpacity>
      <Menu ref={menuRef} menus={menus} activeId={source} onPress={handleSelect} />
    </>
  )
})

const styles = createStyle({
  wrap: {
    width: scaleSizeW(30),
    height: scaleSizeW(30),
    alignItems: 'center',
    justifyContent: 'center',
  },
  icon: {
    width: scaleSizeW(28),
    height: scaleSizeW(28),
  },
})
