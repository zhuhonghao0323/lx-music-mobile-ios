import { memo, useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { TouchableOpacity, View } from 'react-native'
import Text from '@/components/common/Text'
import { scaleSizeW } from '@/utils/pixelRatio'
import { createStyle } from '@/utils/tools'
import { haptic } from '@/utils/haptics'
import { getSongListSetting, saveSongListSetting } from '@/utils/data'
import Menu, { type MenuType, type Menus, type Position } from '@/components/common/Menu'

/**
 * 音源平台标识（对应小蜗/小秋/小枸/小芸/小蜜的别名）。
 *
 * 用彩色圆形 + 首字近似各平台 logo（icomoon 字体集里没有真实平台图标）：
 *   小蜗音乐 → 酷我音乐 (kw) → 青蓝 "酷"
 *   小秋音乐 → QQ 音乐   (tx) → 蓝   "Q"
 *   小枸音乐 → 酷狗音乐 (kg) → 青绿 "狗"
 *   小芸音乐 → 网易云    (wy) → 红   "云"
 *   小蜜音乐 → 咪咕音乐 (mg) → 品红 "咪"
 */
const PLATFORMS: Array<{
  id: LX.OnlineSource
  short: string
  color: string
  name: string
}> = [
  { id: 'kw', short: '酷', color: '#1BA9E0', name: '酷我音乐' },
  { id: 'tx', short: 'Q', color: '#12B7F5', name: 'QQ音乐' },
  { id: 'kg', short: '狗', color: '#1EC98C', name: '酷狗音乐' },
  { id: 'wy', short: '云', color: '#E8402A', name: '网易云音乐' },
  { id: 'mg', short: '咪', color: '#E0398F', name: '咪咕音乐' },
]

/**
 * 首页顶栏的「Music」位置：音源平台筛选按钮。
 *
 * 不再显示 "Music" 文字，而是显示当前平台的彩色图标；
 * 点击弹出平台列表（显示真实平台名），切换后通知 SongList 页重载。
 */
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
        <View style={[styles.circle, { backgroundColor: current.color }]}>
          <Text size={17} color="#FFFFFF" style={styles.short}>{current.short}</Text>
        </View>
      </TouchableOpacity>
      <Menu ref={menuRef} menus={menus} activeId={source} onPress={handleSelect} />
    </>
  )
})

const styles = createStyle({
  wrap: {
    padding: scaleSizeW(2),
  },
  circle: {
    width: scaleSizeW(30),
    height: scaleSizeW(30),
    borderRadius: scaleSizeW(15),
    alignItems: 'center',
    justifyContent: 'center',
  },
  short: {
    fontWeight: '800',
  },
})
