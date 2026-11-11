import { memo, useCallback, useMemo, useRef, useState } from 'react'
import { View, TouchableOpacity, Animated } from 'react-native'
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
import MusicAddBtn from '@/screens/PlayDetail/Vertical/Player/components/MoreBtn/MusicAddBtn'
import PlayModeBtn from '@/screens/PlayDetail/Vertical/Player/components/MoreBtn/PlayModeBtn'
import CommentBtn from '@/screens/PlayDetail/Vertical/Player/components/MoreBtn/CommentBtn'
import FullScreenSwipe from '@/screens/PlayDetail/components/FullScreenSwipe'
import PlaylistSheet, { type PlaylistSheetType } from './PlaylistSheet'
import { usePlayerMusicInfo } from '@/store/player/hook'
import { useSettingValue } from '@/store/setting/hook'
import { getSourceDisplayName } from '@/core/customSource'
import { setApiSource } from '@/core/apiSource'
import { useUserApiList } from '@/store/userApi'
import { formatQualityShort, formatQuality, useCurrentPlayQuality } from '@/store/player/quality'
import { TRY_QUALITYS_LIST } from '@/core/music/utils'
import { updateSetting, setNavActiveId } from '@/core/common'
import { setMusicUrl } from '@/core/player/player'
import playerState from '@/store/player/state'
import commonState from '@/store/common/state'
import { useTogglePlayMode } from './useTogglePlayMode'

/**
 * Tab 2 · 正在播放（对标波点音乐的精简播放器）。
 *
 * 布局（自上而下）：
 *   顶栏（⋯ 更多）
 *   → 封面
 *   → 三行歌词（预留足够高度，不被下方内容遮挡）
 *   → 歌名 / 歌手 / 可点击的 320k 小标签（切音质）
 *   → 进度条
 *   → 五个操作：收藏 / 播放模式 / 评论 / 音源简写（点击切源） / 列表
 *
 * 播放/暂停按钮在底部 BottomNavBar 的中间（与左右图标组成三按钮）。
 * 上下滑切歌包 FullScreenSwipe，弹窗打开时禁用。
 */
export default memo(() => {
  const theme = useTheme()
  const t = useI18n()
  const statusBarHeight = useStatusbarHeight()
  const isGlass = useIsGlass()
  const musicInfo = usePlayerMusicInfo()
  const menuRef = useRef<MenuType>(null)
  const sourceMenuRef = useRef<MenuType>(null)
  const qualityMenuRef = useRef<MenuType>(null)
  const moreBtnRef = useRef<TouchableOpacity>(null)
  const qualityBtnRef = useRef<TouchableOpacity>(null)
  const sourceBtnRef = useRef<TouchableOpacity>(null)
  const playlistSheetRef = useRef<PlaylistSheetType>(null)
  const togglePlayMode = useTogglePlayMode()

  const apiSource = useSettingValue('common.apiSource')
  const userApiList = useUserApiList()
  const quality = useCurrentPlayQuality()
  const playQuality = useSettingValue('player.playQuality')

  // 任一二级弹窗/抽屉打开时禁用切歌手势
  const [overlayVisible, setOverlayVisible] = useState(false)

  const fadeIn = useRef(new Animated.Value(0)).current
  const translateY = useRef(new Animated.Value(scaleSizeW(10))).current
  useMemo(() => {
    Animated.parallel([
      Animated.timing(fadeIn, { toValue: 1, duration: 240, useNativeDriver: true }),
      Animated.timing(translateY, { toValue: 0, duration: 260, useNativeDriver: true }),
    ]).start()
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  const qualityText = formatQualityShort(quality ?? playQuality)

  /** 音源简写：中文取头两字，英文取首个单词 */
  const sourceShort = useMemo(() => {
    if (!userApiList.length) return '--'
    const name = getSourceDisplayName(apiSource)
    const cn = name.match(/[\u4e00-\u9fa5]/g)
    if (cn) return cn.slice(0, 2).join('')
    return name.trim().split(/\s+/)[0] || '--'
  }, [userApiList, apiSource])

  const moreMenus = useMemo<Menus>(() => [
    { action: 'eq', label: t('setting_play_sound_effect') },
    { action: 'toggleMode', label: t('play_list_loop') },
    { action: 'setting', label: t('nav_setting') },
  ], [t])

  const showMore = useCallback(() => {
    haptic.tap()
    setOverlayVisible(true)
    moreBtnRef.current?.measure((_x, _y, w, h, px, py) => {
      const position: Position = { x: Math.ceil(px), y: Math.ceil(py), w: Math.ceil(w), h: Math.ceil(h) }
      menuRef.current?.show(position, { width: 170, height: 44 })
    })
  }, [])

  const handleMoreSelect = useCallback((menu: Menus[number]) => {
    haptic.select()
    switch (menu.action) {
      case 'setting': setNavActiveId('nav_setting'); break
      case 'toggleMode': togglePlayMode(); break
      default: break
    }
  }, [togglePlayMode])

  // ---- 音质菜单（320k 小标签）----
  const qualityMenus = useMemo<Menus>(() => {
    const qualities = [...TRY_QUALITYS_LIST, '128k'].reverse() as LX.Quality[]
    return qualities.map(q => ({ action: q, label: formatQuality(q) }))
  }, [])

  const showQualityMenu = useCallback(() => {
    haptic.tap()
    setOverlayVisible(true)
    qualityBtnRef.current?.measure((_x, _y, w, h, px, py) => {
      const position: Position = { x: Math.ceil(px), y: Math.ceil(py), w: Math.ceil(w), h: Math.ceil(h) }
      qualityMenuRef.current?.show(position, { width: Math.max(Math.ceil(w), 110), height: 40 })
    })
  }, [])

  const handleQualitySelect = useCallback((menu: Menus[number]) => {
    const q = menu.action as LX.Quality
    if (q == playQuality) return
    haptic.select()
    updateSetting({ 'player.playQuality': q })
    const info = playerState.playMusicInfo.musicInfo
    if (info) setMusicUrl(info, true)
  }, [playQuality])

  // ---- 音源菜单（简写按钮，恢复手动切源）----
  const sourceMenus = useMemo<Menus>(() => userApiList.map(item => ({
    action: item.id,
    label: item.name,
  })), [userApiList])

  const showSourceMenu = useCallback(() => {
    if (!userApiList.length) return
    haptic.tap()
    setOverlayVisible(true)
    sourceBtnRef.current?.measure((_x, _y, w, h, px, py) => {
      const position: Position = { x: Math.ceil(px), y: Math.ceil(py), w: Math.ceil(w), h: Math.ceil(h) }
      sourceMenuRef.current?.show(position, { width: Math.max(Math.ceil(w), 130), height: 40 })
    })
  }, [userApiList])

  const handleSourceSelect = useCallback((menu: Menus[number]) => {
    if (menu.action == apiSource) return
    haptic.select()
    setApiSource(menu.action)
  }, [apiSource])

  const openPlaylist = useCallback(() => {
    haptic.tap()
    setOverlayVisible(true)
    playlistSheetRef.current?.show()
  }, [])

  const circleBg = isGlass ? 'rgba(255,255,255,0.09)' : theme['c-primary-light-500-alpha-800']

  return (
    <FullScreenSwipe disabled={overlayVisible}>
      <Animated.View style={[styles.container, { opacity: fadeIn, transform: [{ translateY }] }]}>
        <StatusBar />

        {/* 顶栏：右上 ⋯ 更多（音源信息已移到下方按钮行） */}
        <View style={[styles.header, { paddingTop: statusBarHeight + scaleSizeW(6) }]}>
          <View style={styles.headerSpacer} />
          <TouchableOpacity
            ref={moreBtnRef}
            style={[styles.moreBtn, { backgroundColor: circleBg }]}
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

        {/* 三行歌词：预留足够高度不被遮挡 */}
        <View style={styles.lyricArea}>
          <LyricPreview />
        </View>

        {/* 歌名 / 歌手 / 可点 320k 小标签 */}
        <View style={styles.titleRow}>
          <Text size={19} color={theme['c-font']} numberOfLines={1} style={styles.songName}>{musicInfo.name}</Text>
          <Text size={12} color={theme['c-font-label']} numberOfLines={1} style={styles.singerText}>{musicInfo.singer}</Text>
          <TouchableOpacity ref={qualityBtnRef} onPress={showQualityMenu} activeOpacity={0.7} style={styles.qualityTagWrap}>
            <View style={[styles.tag, { backgroundColor: circleBg }]}>
              <Text size={10} color={theme['c-font-label']}>{qualityText}</Text>
            </View>
          </TouchableOpacity>
        </View>

        {/* 进度条 */}
        <View style={styles.progressArea}>
          <PlayInfo />
        </View>

        {/* 五个操作：收藏 / 播放模式 / 评论 / 音源简写 / 列表 */}
        <View style={styles.actionsRow}>
          <View style={styles.actionCell}><MusicAddBtn /></View>
          <View style={styles.actionCell}><PlayModeBtn /></View>
          <View style={styles.actionCell}><CommentBtn /></View>
          {/* 音源简写按钮：点击弹菜单手动切源 */}
          <TouchableOpacity
            ref={sourceBtnRef}
            style={[styles.actionCell, styles.sourceBtn, { backgroundColor: circleBg }]}
            activeOpacity={0.7}
            onPress={showSourceMenu}
          >
            <Text size={11} color={theme['c-font-label']} numberOfLines={1}>{sourceShort}</Text>
          </TouchableOpacity>
          <TouchableOpacity
            style={[styles.actionCell, styles.listBtn, { backgroundColor: circleBg }]}
            hitSlop={{ top: 8, bottom: 8, left: 8, right: 8 }}
            onPress={openPlaylist}
          >
            <Icon name="menu" size={17} color={theme['c-font-label']} />
          </TouchableOpacity>
        </View>

        {/* 弹窗 onHide 时恢复切歌手势 */}
        <Menu ref={menuRef} menus={moreMenus} onPress={handleMoreSelect} onHide={() => { setOverlayVisible(false) }} />
        <Menu
          ref={sourceMenuRef}
          menus={sourceMenus}
          activeId={apiSource}
          center
          onPress={handleSourceSelect}
          onHide={() => { setOverlayVisible(false) }}
        />
        <Menu ref={qualityMenuRef} menus={qualityMenus} activeId={playQuality} center fontSize={12} onPress={handleQualitySelect} onHide={() => { setOverlayVisible(false) }} />
        <PlaylistSheet ref={playlistSheetRef} onHide={() => { setOverlayVisible(false) }} />
      </Animated.View>
    </FullScreenSwipe>
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
  headerSpacer: {
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
    minHeight: scaleSizeW(140),
  },
  lyricArea: {
    // 三行歌词预留充足高度，避免被歌名/进度挤到遮挡
    height: scaleSizeW(84),
    justifyContent: 'center',
  },
  titleRow: {
    paddingHorizontal: scaleSizeW(20),
    paddingTop: scaleSizeW(6),
    paddingBottom: scaleSizeW(2),
  },
  songName: {
    fontWeight: '700',
  },
  singerText: {
    marginTop: scaleSizeW(2),
  },
  qualityTagWrap: {
    alignSelf: 'flex-start',
    marginTop: scaleSizeW(6),
  },
  tag: {
    paddingHorizontal: scaleSizeW(8),
    paddingVertical: scaleSizeW(3),
    borderRadius: scaleSizeW(8),
  },
  progressArea: {
    paddingHorizontal: scaleSizeW(16),
    paddingTop: scaleSizeW(10),
  },
  actionsRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: scaleSizeW(10),
    paddingTop: scaleSizeW(14),
    paddingBottom: scaleSizeW(6),
  },
  actionCell: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  sourceBtn: {
    height: scaleSizeW(38),
    borderRadius: scaleSizeW(19),
    marginHorizontal: scaleSizeW(2),
  },
  listBtn: {
    height: scaleSizeW(38),
    width: scaleSizeW(38),
    maxWidth: scaleSizeW(38),
    borderRadius: scaleSizeW(19),
  },
})
