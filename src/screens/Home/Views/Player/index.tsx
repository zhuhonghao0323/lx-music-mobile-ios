import { memo, useCallback, useMemo, useRef } from 'react'
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
import ControlBtn from '@/screens/PlayDetail/Vertical/Player/components/ControlBtn'
import MoreBtn from '@/screens/PlayDetail/Vertical/Player/components/MoreBtn'
import FullScreenSwipe from '@/screens/PlayDetail/components/FullScreenSwipe'
import PlaylistSheet, { type PlaylistSheetType } from './PlaylistSheet'
import { usePlayerMusicInfo } from '@/store/player/hook'
import { useSettingValue } from '@/store/setting/hook'
import { getSourceDisplayName } from '@/core/customSource'
import { useUserApiList } from '@/store/userApi'
import { formatQualityShort, useCurrentPlayQuality } from '@/store/player/quality'
import commonState from '@/store/common/state'
import { setNavActiveId } from '@/core/common'
import { useTogglePlayMode } from './useTogglePlayMode'

/**
 * Tab 2 · 正在播放（对标波点音乐的精简播放器）。
 *
 * 布局（自上而下）：
 *   顶栏（当前来源 + ⋯ 更多）
 *   → 封面
 *   → 三行歌词
 *   → 歌名 / 歌手 / 音质标签
 *   → 进度条
 *   → 次操作行（收藏 / 播放模式 / 评论 / 列表）
 *   → 底部居中的大播放键（替代原胶囊位置）
 *
 * 上下滑切歌：包了 FullScreenSwipe，只切歌不导航（不会跳旧播放页）。
 */
export default memo(() => {
  const theme = useTheme()
  const t = useI18n()
  const statusBarHeight = useStatusbarHeight()
  const isGlass = useIsGlass()
  const musicInfo = usePlayerMusicInfo()
  const menuRef = useRef<MenuType>(null)
  const menuBtnRef = useRef<TouchableOpacity>(null)
  const playlistSheetRef = useRef<PlaylistSheetType>(null)
  const togglePlayMode = useTogglePlayMode()

  const apiSource = useSettingValue('common.apiSource')
  const userApiList = useUserApiList()
  const quality = useCurrentPlayQuality()
  const playQuality = useSettingValue('player.playQuality')

  const fadeIn = useRef(new Animated.Value(0)).current
  const translateY = useRef(new Animated.Value(scaleSizeW(10))).current
  useMemo(() => {
    Animated.parallel([
      Animated.timing(fadeIn, { toValue: 1, duration: 240, useNativeDriver: true }),
      Animated.timing(translateY, { toValue: 0, duration: 260, useNativeDriver: true }),
    ]).start()
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  const sourceName = useMemo(() => {
    if (!userApiList.length) return musicInfo.singer ?? ''
    return getSourceDisplayName(apiSource)
  }, [userApiList, apiSource, musicInfo.singer])

  const qualityText = formatQualityShort(quality ?? playQuality)

  const moreMenus = useMemo<Menus>(() => [
    { action: 'eq', label: t('setting_play_sound_effect') },
    { action: 'toggleMode', label: t('play_list_loop') },
    { action: 'setting', label: t('nav_setting') },
  ], [t])

  const showMore = useCallback(() => {
    haptic.tap()
    menuBtnRef.current?.measure((_x, _y, w, h, px, py) => {
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

  const openPlaylist = useCallback(() => {
    haptic.tap()
    playlistSheetRef.current?.show()
  }, [])

  const circleBg = isGlass ? 'rgba(255,255,255,0.09)' : theme['c-primary-light-500-alpha-800']

  return (
    <FullScreenSwipe>
      <Animated.View style={[styles.container, { opacity: fadeIn, transform: [{ translateY }] }]}>
        <StatusBar />

        {/* 顶栏：当前来源 + ⋯ 更多 */}
        <View style={[styles.header, { paddingTop: statusBarHeight + scaleSizeW(6) }]}>
          <Text size={12} color={theme['c-font-label']} numberOfLines={1} style={styles.sourceName}>{sourceName}</Text>
          <TouchableOpacity
            ref={menuBtnRef}
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

        {/* 三行歌词 */}
        <View style={styles.lyricArea}>
          <LyricPreview />
        </View>

        {/* 歌名 / 歌手 / 音质 */}
        <View style={styles.titleRow}>
          <Text size={18} color={theme['c-font']} numberOfLines={1} style={styles.songName}>{musicInfo.name}</Text>
          <Text size={12} color={theme['c-font-label']} numberOfLines={1}>{musicInfo.singer}</Text>
          <View style={styles.tagRow}>
            <View style={[styles.tag, { backgroundColor: circleBg }]}>
              <Text size={10} color={theme['c-font-label']}>{qualityText}</Text>
            </View>
          </View>
        </View>

        {/* 进度条 */}
        <View style={styles.progressArea}>
          <PlayInfo />
        </View>

        {/* 次操作行：收藏 / 播放模式 / 评论 / 列表 */}
        <View style={styles.secondaryRow}>
          <View style={styles.secondaryLeft}>
            <MoreBtn />
          </View>
          <TouchableOpacity
            style={[styles.listBtn, { backgroundColor: circleBg }]}
            hitSlop={{ top: 8, bottom: 8, left: 8, right: 8 }}
            onPress={openPlaylist}
          >
            <Icon name="menu" size={17} color={theme['c-font-label']} />
          </TouchableOpacity>
        </View>

        {/* 底部居中的大播放键（替代原胶囊位置） */}
        <View style={styles.playArea}>
          <ControlBtn hideSkip />
        </View>

        <Menu ref={menuRef} menus={moreMenus} onPress={handleMoreSelect} />
        <PlaylistSheet ref={playlistSheetRef} />
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
  sourceName: {
    flex: 1,
    marginRight: scaleSizeW(8),
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
    minHeight: scaleSizeW(150),
  },
  lyricArea: {
    height: scaleSizeW(64),
  },
  titleRow: {
    paddingHorizontal: scaleSizeW(20),
    paddingBottom: scaleSizeW(2),
  },
  songName: {
    fontWeight: '700',
  },
  tagRow: {
    flexDirection: 'row',
    marginTop: scaleSizeW(4),
  },
  tag: {
    paddingHorizontal: scaleSizeW(7),
    paddingVertical: scaleSizeW(2),
    borderRadius: scaleSizeW(8),
  },
  progressArea: {
    paddingHorizontal: scaleSizeW(16),
  },
  secondaryRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: scaleSizeW(14),
    paddingTop: scaleSizeW(6),
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
  playArea: {
    alignItems: 'center',
    justifyContent: 'center',
    paddingBottom: scaleSizeW(10),
    paddingTop: scaleSizeW(4),
  },
})
