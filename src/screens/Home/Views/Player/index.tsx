import { memo, useCallback, useMemo, useRef, useState } from 'react'
import { View, TouchableOpacity, Animated, StyleSheet } from 'react-native'
import PagerView, { type PagerViewOnPageSelectedEvent } from 'react-native-pager-view'
import { useStatusbarHeight } from '@/store/common/hook'
import { useI18n } from '@/lang'
import { createStyle } from '@/utils/tools'
import { Icon } from '@/components/common/Icon'
import Text from '@/components/common/Text'
import StatusBar from '@/components/common/StatusBar'
import { scaleSizeW } from '@/utils/pixelRatio'
import { haptic } from '@/utils/haptics'
import Menu, { type MenuType, type Menus, type Position } from '@/components/common/Menu'
import Pic from '@/screens/PlayDetail/Vertical/Pic'
import LyricPreview from '@/screens/PlayDetail/Vertical/Player/components/LyricPreview'
import PlayInfo from '@/screens/PlayDetail/Vertical/Player/components/PlayInfo'
import MusicAddBtn from '@/screens/PlayDetail/Vertical/Player/components/MoreBtn/MusicAddBtn'
import PlayModeBtn from '@/screens/PlayDetail/Vertical/Player/components/MoreBtn/PlayModeBtn'
import CommentBtn from '@/screens/PlayDetail/Vertical/Player/components/MoreBtn/CommentBtn'
import Lyric from '@/screens/PlayDetail/Vertical/Lyric'
import FullScreenSwipe from '@/screens/PlayDetail/components/FullScreenSwipe'
import PlaylistSheet, { type PlaylistSheetType } from './PlaylistSheet'
import PlaylistBtn from './PlaylistBtn'
import CommentSheet, { type CommentSheetType } from './CommentSheet'
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
import { useBeansColors, BEANS_SPACING, beansCircleButton } from '@/theme/beans'

/**
 * Tab 2 · 正在播放（对标波点音乐的精简播放器）。
 *
 * 横滑切换（与原项目一致，用 PagerView 原生翻页）：
 *   左滑 → 全屏歌词页；歌词页右滑 → 回到播放页
 *
 * 播放页布局（自上而下）：
 *   顶栏（⋯ 更多）
 *   → 封面
 *   → 三行歌词预览
 *   → 歌名 / 歌手 / 音质 + 音源小标签
 *   → 进度条
 *   → 四个操作：收藏 / 播放模式 / 评论 / 列表
 *
 * 播放/暂停按钮在底部 BottomNavBar 的中间（与左右图标组成三按钮）。
 * 上下滑切歌包 FullScreenSwipe，弹窗打开时禁用。
 */
/** 音质/音源标签的字号（两者统一） */
const TAG_FONT_SIZE = 11
/** 音质/音源弹出菜单的字号（两者统一，比标签略大以保证可读） */
const MENU_FONT_SIZE = 13

export default memo(() => {
  const t = useI18n()
  const statusBarHeight = useStatusbarHeight()
  const musicInfo = usePlayerMusicInfo()
  const menuRef = useRef<MenuType>(null)
  const sourceMenuRef = useRef<MenuType>(null)
  const qualityMenuRef = useRef<MenuType>(null)
  const moreBtnRef = useRef<TouchableOpacity>(null)
  const qualityBtnRef = useRef<TouchableOpacity>(null)
  const sourceBtnRef = useRef<TouchableOpacity>(null)
  const playlistSheetRef = useRef<PlaylistSheetType>(null)
  const commentSheetRef = useRef<CommentSheetType>(null)
  const togglePlayMode = useTogglePlayMode()

  const apiSource = useSettingValue('common.apiSource')
  const userApiList = useUserApiList()
  const quality = useCurrentPlayQuality()
  const playQuality = useSettingValue('player.playQuality')

  // 任一二级弹窗/抽屉打开时禁用切歌手势
  const [overlayVisible, setOverlayVisible] = useState(false)
  // 横向翻页：0 = 播放页，1 = 全屏歌词（与原项目一致）
  const [pageIndex, setPageIndex] = useState(0)

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

  const openComment = useCallback(() => {
    haptic.tap()
    setOverlayVisible(true)
    commentSheetRef.current?.show()
  }, [])

  const onPageSelected = useCallback(({ nativeEvent }: PagerViewOnPageSelectedEvent) => {
    setPageIndex(nativeEvent.position)
  }, [])

  const beansColors = useBeansColors()
  // Beans 风格圆形玻璃按钮
  const roundBtn = beansCircleButton(beansColors, scaleSizeW(44))

  return (
    <FullScreenSwipe disabled={overlayVisible || pageIndex == 1}>
      <Animated.View style={[styles.container, { opacity: fadeIn, transform: [{ translateY }] }]}>
        <StatusBar />

        {/* 横滑翻页：0 播放页 / 1 全屏歌词（左滑看歌词，右滑回播放页） */}
        <PagerView
          style={styles.pagerView}
          initialPage={0}
          onPageSelected={onPageSelected}
          // 弹窗打开时禁止翻页，避免与弹窗手势冲突
          scrollEnabled={!overlayVisible}
        >
          <View collapsable={false} style={styles.page}>
            <View style={styles.playerPage}>
              {/* 顶栏（Beans 布局）：左收起箭头 / 中「正在播放 + 歌名」/ 右收藏 + 更多 */}
              <View style={[styles.header, { paddingTop: statusBarHeight + scaleSizeW(6) }]}>
                <TouchableOpacity
                  style={roundBtn}
                  onPress={() => { haptic.tap(); setNavActiveId('nav_home') }}
                  activeOpacity={0.7}
                >
                  <Icon name="chevron-left" size={20} color={beansColors.text} />
                </TouchableOpacity>
                <View style={styles.headerTitle}>
                  <Text size={15} color={beansColors.text} numberOfLines={1} style={styles.headerTitleMain}>{t('nav_player')}</Text>
                  <Text size={12} color={beansColors.textSecondary} numberOfLines={1}>{musicInfo.name}</Text>
                </View>
                <View style={styles.headerRight}>
                  <TouchableOpacity ref={moreBtnRef} style={[roundBtn, styles.headerRightBtn]} onPress={showMore} activeOpacity={0.7}>
                    <Icon name="dots-vertical" size={18} color={beansColors.text} />
                  </TouchableOpacity>
                </View>
              </View>

              {/* 封面 */}
              <View style={styles.coverArea}>
                <Pic componentId={commonState.componentIds.home ?? ''} />
              </View>

              {/* 三行歌词：预留足够高度不被遮挡 */}
              <View style={styles.lyricArea}>
                <LyricPreview />
              </View>

              {/* 歌名 / 歌手（Beans 大字号居中） + 音质/音源玻璃胶囊 */}
              <View style={styles.titleRow}>
                <Text size={26} color={beansColors.text} numberOfLines={1} style={styles.songName}>{musicInfo.name}</Text>
                <Text size={15} color={beansColors.textSecondary} numberOfLines={1} style={styles.singerText}>{musicInfo.singer}</Text>
                <View style={styles.tagRow}>
                  <TouchableOpacity ref={qualityBtnRef} onPress={showQualityMenu} activeOpacity={0.7}>
                    <View style={[styles.tag, { backgroundColor: beansColors.glass, borderColor: beansColors.border }]}>
                      <Text size={TAG_FONT_SIZE} color={beansColors.textSecondary} numberOfLines={1}>{qualityText}</Text>
                    </View>
                  </TouchableOpacity>
                  <TouchableOpacity ref={sourceBtnRef} onPress={showSourceMenu} activeOpacity={0.7}>
                    <View style={[styles.tag, styles.tagGap, { backgroundColor: beansColors.glass, borderColor: beansColors.border }]}>
                      <Text size={TAG_FONT_SIZE} color={beansColors.textSecondary} numberOfLines={1}>{sourceShort}</Text>
                    </View>
                  </TouchableOpacity>
                </View>
              </View>

              {/* 进度条 */}
              <View style={styles.progressArea}>
                <PlayInfo />
              </View>

              {/* 四个操作：收藏 / 播放模式 / 评论 / 列表（等间距、尺寸统一） */}
              <View style={styles.actionsRow}>
                <View style={styles.actionCell}><MusicAddBtn /></View>
                <View style={styles.actionCell}><PlayModeBtn /></View>
                <View style={styles.actionCell}>
                  <CommentBtn onPress={openComment} />
                </View>
                <View style={styles.actionCell}>
                  {/* 与其它三个按钮共用 Btn 组件，保证样式、尺寸、对齐完全一致 */}
                  <PlaylistBtn onPress={openPlaylist} />
                </View>
              </View>
            </View>
          </View>

          {/* 第二页：全屏歌词 */}
          <View collapsable={false} style={styles.page}>
            <View style={styles.lyricPage}>
              <Lyric />
            </View>
          </View>
        </PagerView>

        {/* 弹窗 onHide 时恢复切歌手势 */}
        <Menu ref={menuRef} menus={moreMenus} onPress={handleMoreSelect} onHide={() => { setOverlayVisible(false) }} />
        <Menu
          ref={sourceMenuRef}
          menus={sourceMenus}
          activeId={apiSource}
          center
          fontSize={MENU_FONT_SIZE}
          onPress={handleSourceSelect}
          onHide={() => { setOverlayVisible(false) }}
        />
        <Menu
          ref={qualityMenuRef}
          menus={qualityMenus}
          activeId={playQuality}
          center
          fontSize={MENU_FONT_SIZE}
          onPress={handleQualitySelect}
          onHide={() => { setOverlayVisible(false) }}
        />
        <PlaylistSheet ref={playlistSheetRef} onHide={() => { setOverlayVisible(false) }} />
        <CommentSheet ref={commentSheetRef} onHide={() => { setOverlayVisible(false) }} />
      </Animated.View>
    </FullScreenSwipe>
  )
})

const styles = createStyle({
  container: {
    flex: 1,
  },
  pagerView: {
    flex: 1,
  },
  page: {
    flex: 1,
  },
  playerPage: {
    flex: 1,
  },
  lyricPage: {
    flex: 1,
    paddingTop: scaleSizeW(40),
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: BEANS_SPACING.page,
    paddingBottom: scaleSizeW(8),
  },
  headerTitle: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: scaleSizeW(8),
  },
  headerTitleMain: {
    fontWeight: '600',
    marginBottom: scaleSizeW(2),
  },
  headerRight: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  headerRightBtn: {
    marginLeft: scaleSizeW(8),
  },
  coverArea: {
    flexGrow: 1,
    flexShrink: 1,
    minHeight: scaleSizeW(140),
  },
  lyricArea: {
    // 三行歌词预览（Beans 播放页封面下方的歌词预览区）
    height: scaleSizeW(96),
    justifyContent: 'center',
  },
  titleRow: {
    alignItems: 'center',
    paddingHorizontal: scaleSizeW(20),
    paddingTop: scaleSizeW(4),
    paddingBottom: scaleSizeW(2),
  },
  songName: {
    fontWeight: '800',
    textAlign: 'center',
  },
  singerText: {
    marginTop: scaleSizeW(4),
    textAlign: 'center',
  },
  // 音质 + 音源并排：统一样式、水平对齐、保持适当间距
  tagRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginTop: scaleSizeW(10),
  },
  tag: {
    height: scaleSizeW(24),
    minWidth: scaleSizeW(48),
    paddingHorizontal: scaleSizeW(10),
    borderRadius: scaleSizeW(12),
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: StyleSheet.hairlineWidth,
  },
  tagGap: {
    marginLeft: scaleSizeW(8),
  },
  progressArea: {
    paddingHorizontal: scaleSizeW(16),
    paddingTop: scaleSizeW(10),
  },
  actionsRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: scaleSizeW(16),
    paddingTop: scaleSizeW(14),
    paddingBottom: scaleSizeW(6),
  },
  actionCell: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  listBtn: {
    height: scaleSizeW(38),
    width: scaleSizeW(38),
    borderRadius: scaleSizeW(19),
  },
})
