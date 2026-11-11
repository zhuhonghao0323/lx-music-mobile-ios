import { memo, useCallback, useMemo, useRef, useState } from 'react'
import { View, TouchableOpacity } from 'react-native'
import { useTheme } from '@/store/theme/hook'
import { useStatusbarHeight } from '@/store/common/hook'
import { useI18n } from '@/lang'
import { createStyle } from '@/utils/tools'
import { Icon } from '@/components/common/Icon'
import Text from '@/components/common/Text'
import StatusBar from '@/components/common/StatusBar'
import { scaleSizeW } from '@/utils/pixelRatio'
import { useIsGlass } from '@/theme/glass'
import { haptic } from '@/utils/haptics'
import Menu, { type MenuType, type Menus, type Position } from '@/components/common/Menu'
import Pic from '@/screens/PlayDetail/Vertical/Pic'
import LyricPreview from '@/screens/PlayDetail/Vertical/Player/components/LyricPreview'
import PlayInfo from '@/screens/PlayDetail/Vertical/Player/components/PlayInfo'
import ControlBtn from '@/screens/PlayDetail/Vertical/Player/components/ControlBtn'
import MoreBtn from '@/screens/PlayDetail/Vertical/Player/components/MoreBtn'
import PlaylistSheet from './PlaylistSheet'
import { usePlayerMusicInfo } from '@/store/player/hook'
import { useSettingValue } from '@/store/setting/hook'
import { getSourceDisplayName } from '@/core/customSource'
import { useUserApiList } from '@/store/userApi'
import { formatQualityShort, useCurrentPlayQuality } from '@/store/player/quality'
import commonState from '@/store/common/state'
import { setNavActiveId } from '@/core/common'
import { useTogglePlayMode } from './useTogglePlayMode'

/**
 * Tab 2 · 正在播放（精简版全屏播放器）。
 *
 * 结构对标波点音乐：
 *   顶栏（当前来源 + ⋯ 更多菜单）
 *   → 封面 → 歌词区 → 进度区 → 主操作行 → 次操作行（含右下角 ☰ 列表按钮）
 *
 * 与旧独立播放页的区别：
 * - 不再有返回键（由底部 Tab 切换离开）
 * - 音效/均衡器、设置等低频入口收进右上角 ⋯ 更多菜单
 * - 右下角新增 ☰ 按钮，弹出当前播放列表半屏 Sheet
 */
export default memo(() => {
  const theme = useTheme()
  const t = useI18n()
  const statusBarHeight = useStatusbarHeight()
  const isGlass = useIsGlass()
  const musicInfo = usePlayerMusicInfo()
  const menuRef = useRef<MenuType>(null)
  const menuBtnRef = useRef<TouchableOpacity>(null)
  const playlistSheetRef = useRef<{ show: () => void }>(null)
  const [sheetVisible, setSheetVisible] = useState(false)
  const togglePlayMode = useTogglePlayMode()

  const apiSource = useSettingValue('common.apiSource')
  const userApiList = useUserApiList()
  const quality = useCurrentPlayQuality()
  const playQuality = useSettingValue('player.playQuality')

  /** 当前来源名（音源名），对标波点左上角的「当前歌单 / 来源」 */
  const sourceName = useMemo(() => {
    if (!userApiList.length) return musicInfo.singer ?? ''
    return getSourceDisplayName(apiSource)
  }, [userApiList, apiSource, musicInfo.singer])

  const qualityText = formatQualityShort(quality ?? playQuality)

  // ⋯ 更多菜单：收纳原播放页右上角的音效 / 播放设置等次要入口
  const moreMenus = useMemo<Menus>(() => [
    { action: 'eq', label: t('setting_play_sound_effect') },
    { action: 'setting', label: t('nav_setting') },
    { action: 'toggleMode', label: t('play_list_loop') },
  ], [t])

  const showMore = useCallback(() => {
    haptic.tap()
    menuBtnRef.current?.measure((_x, _y, w, h, px, py) => {
      const position: Position = { x: Math.ceil(px), y: Math.ceil(py), w: Math.ceil(w), h: Math.ceil(h) }
      menuRef.current?.show(position, { width: 160, height: 40 })
    })
  }, [])

  const handleMoreSelect = useCallback((menu: Menus[number]) => {
    haptic.select()
    switch (menu.action) {
      case 'setting':
        setNavActiveId('nav_setting')
        break
      case 'toggleMode':
        togglePlayMode()
        break
      default:
        break
    }
  }, [togglePlayMode])

  const openPlaylist = useCallback(() => {
    haptic.tap()
    setSheetVisible(true)
    requestAnimationFrame(() => {
      playlistSheetRef.current?.show()
    })
  }, [])

  return (
    <View style={styles.container}>
      <StatusBar />

      {/* 顶栏：当前来源 + 更多菜单 */}
      <View style={[styles.header, { paddingTop: statusBarHeight + scaleSizeW(6) }]}>
        <View style={styles.headerLeft}>
          <Text size={12} color={theme['c-font-label']} numberOfLines={1}>{sourceName}</Text>
        </View>
        <TouchableOpacity
          ref={menuBtnRef}
          style={[
            styles.moreBtn,
            { backgroundColor: isGlass ? 'rgba(255,255,255,0.09)' : theme['c-primary-light-500-alpha-800'] },
          ]}
          hitSlop={{ top: 10, bottom: 10, left: 10, right: 10 }}
          onPress={showMore}
        >
          <Icon name="dots-vertical" size={16} color={theme['c-font']} />
        </TouchableOpacity>
      </View>

      {/* 封面 */}
      <View style={styles.coverArea}>
        <Pic componentId={commonState.componentIds.home ?? ''} />
      </View>

      {/* 歌词区 */}
      <View style={styles.lyricArea}>
        <LyricPreview />
      </View>

      {/* 歌名歌手 + 音质/音源标识 */}
      <View style={styles.titleRow}>
        <Text size={17} color={theme['c-font']} numberOfLines={1} style={styles.songName}>{musicInfo.name}</Text>
        <Text size={12} color={theme['c-font-label']} numberOfLines={1}>{musicInfo.singer}</Text>
        <View style={styles.tagRow}>
          <View style={[styles.tag, { backgroundColor: isGlass ? 'rgba(255,255,255,0.10)' : theme['c-primary-light-500-alpha-800'] }]}>
            <Text size={10} color={theme['c-font-label']}>{qualityText}</Text>
          </View>
        </View>
      </View>

      {/* 进度 + 控制 + 次操作 */}
      <View style={styles.bottomGroup}>
        <PlayInfo />
        <ControlBtn />
        <View style={styles.secondaryRow}>
          <View style={styles.secondaryLeft}>
            <MoreBtn />
          </View>
          {/* 右下角：当前播放列表 */}
          <TouchableOpacity
            style={[
              styles.listBtn,
              { backgroundColor: isGlass ? 'rgba(255,255,255,0.09)' : theme['c-primary-light-500-alpha-800'] },
            ]}
            hitSlop={{ top: 8, bottom: 8, left: 8, right: 8 }}
            onPress={openPlaylist}
          >
            <Icon name="menu" size={17} color={theme['c-font-label']} />
          </TouchableOpacity>
        </View>
      </View>

      <Menu ref={menuRef} menus={moreMenus} onPress={handleMoreSelect} />
      <PlaylistSheet
        ref={playlistSheetRef}
        visible={sheetVisible}
        onHide={() => { setSheetVisible(false) }}
      />
    </View>
  )
})

const styles = createStyle({
  container: {
    flex: 1,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: scaleSizeW(16),
    paddingBottom: scaleSizeW(4),
  },
  headerLeft: {
    flex: 1,
  },
  moreBtn: {
    width: scaleSizeW(34),
    height: scaleSizeW(34),
    borderRadius: scaleSizeW(17),
    alignItems: 'center',
    justifyContent: 'center',
  },
  coverArea: {
    flexGrow: 1,
    flexShrink: 1,
    minHeight: scaleSizeW(180),
  },
  lyricArea: {
    height: scaleSizeW(72),
  },
  titleRow: {
    paddingHorizontal: scaleSizeW(20),
    paddingBottom: scaleSizeW(2),
  },
  songName: {
    fontWeight: '600',
  },
  tagRow: {
    flexDirection: 'row',
    marginTop: scaleSizeW(5),
  },
  tag: {
    paddingHorizontal: scaleSizeW(7),
    paddingVertical: scaleSizeW(2),
    borderRadius: scaleSizeW(8),
  },
  bottomGroup: {
    paddingBottom: scaleSizeW(4),
  },
  secondaryRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: scaleSizeW(14),
  },
  secondaryLeft: {
    flex: 1,
    flexDirection: 'row',
  },
  listBtn: {
    width: scaleSizeW(38),
    height: scaleSizeW(38),
    borderRadius: scaleSizeW(19),
    alignItems: 'center',
    justifyContent: 'center',
  },
})
