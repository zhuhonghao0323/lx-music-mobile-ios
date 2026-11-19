import { memo, useCallback, useEffect, useRef } from 'react'
import { View, TouchableOpacity, StyleSheet } from 'react-native'
import { useTheme } from '@/store/theme/hook'
import { useStatusbarHeight } from '@/store/common/hook'
import { useI18n } from '@/lang'
import { createStyle } from '@/utils/tools'
import { Icon } from '@/components/common/Icon'
import Text from '@/components/common/Text'
import StatusBar from '@/components/common/StatusBar'
import { scaleSizeH, scaleSizeW } from '@/utils/pixelRatio'
import { HEADER_HEIGHT } from '@/config/constant'
import { useIsGlass } from '@/theme/glass'
import { haptic } from '@/utils/haptics'
import { setNavActiveId } from '@/core/common'
import { setActiveList } from '@/core/list'
import ListGrid from './ListGrid'
import ListOperations from '../Mylist/ListOperations'
import Menu, { type MenuType, type Menus, type Position } from '@/components/common/Menu'

import { useMineStats } from './useMineStats'
import { isSwiftUIPageSupported } from '@/screens/SwiftUIPages/swiftUIPageBridge'
import MineSwiftUIContainer from '@/screens/SwiftUIPages/MineContainer'

/** 统计卡片中的单项（大数字 + 小标签） */
const StatItem = ({ value, label, theme }: { value: string | number, label: string, theme: ReturnType<typeof useTheme> }) => (
  <View style={styles.statItem}>
    <Text size={typeof value == 'string' ? 16 : 22} color={theme['c-font']} style={styles.statValue}>{value}</Text>
    <Text size={11} color={theme['c-font-label']} numberOfLines={2} style={styles.statLabel}>{label}</Text>
  </View>
)

/**
 * Tab 3 · 我的（统计 + 歌单 + 设置入口）。
 *
 * 结构：
 *   顶部栏（标题 + 设置齿轮）
 *   → 统计卡片（收藏歌曲数 / 歌单数 / 本次会话已播放，均为真实可获取的数据）
 *   → 歌单网格（自建与收藏歌单，含封面与数量）
 */
const MineContent = memo(() => {
  const theme = useTheme()
  const t = useI18n()
  const statusBarHeight = useStatusbarHeight()
  const isGlass = useIsGlass()
  const stats = useMineStats()
  const listMenuRef = useRef<MenuType>(null)
  const longPressedIdRef = useRef<string>('')

  /** 长按歌单弹出的操作菜单（用户指定 5 项） */
  const LIST_MENUS: Menus = [
    { action: 'localFile', label: t('list_select_local_file') },
    { action: 'sync', label: t('list_sync') },
    { action: 'import', label: t('list_import') },
    { action: 'export', label: t('list_export') },
    { action: 'remove', label: t('list_remove') },
  ]

  const handleLongPressList = useCallback((info: LX.List.MyListInfo, position: Position) => {
    longPressedIdRef.current = info.id
    listMenuRef.current?.show({ x: position.x, y: position.y, w: position.w, h: position.h }, { width: 140, height: 40 })
  }, [])

  const handleListMenuPress = useCallback((menu: Menus[number]) => {
    if (!longPressedIdRef.current) return
    global.app_event.listOperation(menu.action as 'localFile' | 'sync' | 'import' | 'export' | 'remove', longPressedIdRef.current)
  }, [])

  const handleCreateList = useCallback(() => {
    haptic.tap()
    global.app_event.requestCreateList()
  }, [])

  const openSetting = useCallback(() => {
    haptic.tap()
    setNavActiveId('nav_setting')
  }, [])

  /** 点歌单图标：设为当前列表并进入列表歌曲页（那里有播放列表、添加到播放列表等全部功能） */
  const handleSelectList = useCallback((info: LX.List.MyListInfo) => {
    setActiveList(info.id)
    setNavActiveId('nav_love')
  }, [])

  // 说明：不再在这里触发 changeLoveListVisible。
  // Mylist 页内部本身就是「列表抽屉 + 歌曲列表」的双栏结构，
  // 在「我的」Tab 里打开它只会让抽屉挡住内容，正确做法是直接切到该页。
  useEffect(() => {
    // 进入「我的」时确保 Mylist 页的抽屉处于收起状态，
    // 否则从别的入口残留的打开状态会带过来。
    global.app_event.changeLoveListVisible(false)
  }, [])

  return (
    <View style={styles.container}>
      <StatusBar />
      <View
        style={StyleSheet.compose(styles.header, {
          height: scaleSizeH(HEADER_HEIGHT) + statusBarHeight,
          paddingTop: statusBarHeight,
        })}
      >
        <Text style={styles.title} size={20} color={theme['c-font']}>{t('nav_mine')}</Text>
        <TouchableOpacity
          style={styles.settingBtn}
          hitSlop={{ top: 8, bottom: 8, left: 8, right: 8 }}
          onPress={openSetting}
        >
          <Icon name="setting" size={19} color={theme['c-font']} />
        </TouchableOpacity>
      </View>

      {/* 统计卡片：收藏歌曲数 / 歌单数 / 本次会话已播放（真实可获取的数据） */}
      <View style={StyleSheet.compose(styles.profileCard, {
        backgroundColor: isGlass ? 'rgba(255,255,255,0.08)' : theme['c-primary-light-500-alpha-800'],
      })}>
        <StatItem value={stats.favoriteCount} label={t('mine_stat_favorite')} theme={theme} />
        <View style={styles.statDivider} />
        <StatItem value={stats.playlistCount} label={t('mine_stat_playlists')} theme={theme} />
        <View style={styles.statDivider} />
        <StatItem value={stats.totalPlayTimeText} label={t('mine_stat_total_time')} theme={theme} />
      </View>

      <View style={styles.sectionHeader}>
        <Text size={15} color={theme['c-font']}>{t('nav_my_lists')}</Text>
        <TouchableOpacity style={styles.createBtn} activeOpacity={0.7} onPress={handleCreateList}>
          <Icon name="add_folder" size={17} color={theme['c-primary-font']} />
        </TouchableOpacity>
      </View>

      {/* 歌单图标网格：点图标进入该列表的歌曲页（复用现有 MusicList 全部能力） */}
      <View style={styles.listArea}>
        <ListGrid onSelectList={handleSelectList} onLongPressList={handleLongPressList} />
      </View>

      {/* 歌单长按菜单 */}
      <Menu ref={listMenuRef} menus={LIST_MENUS} onPress={handleListMenuPress} fontSize={13} />
      {/* 歌单操作处理器（新建/添加本地/更新/导入/导出/移除） */}
      <ListOperations />
    </View>
  )
})

/**
 * Tab 3 · 我的 —— 平台分发。
 * iOS 走 SwiftUI 原生实现（系统 List/Grid + SF Symbols + 材质），
 * 其它平台保留原 RN 实现。
 */
export default memo(() => {
  if (isSwiftUIPageSupported) return <MineSwiftUIContainer />
  return <MineContent />
})

const styles = createStyle({
  container: {
    flex: 1,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: scaleSizeW(16),
    zIndex: 10,
  },
  title: {
    flex: 1,
    fontWeight: '700',
  },
  settingBtn: {
    width: scaleSizeW(36),
    height: scaleSizeW(36),
    alignItems: 'center',
    justifyContent: 'center',
  },
  profileCard: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-around',
    marginHorizontal: scaleSizeW(16),
    marginTop: scaleSizeW(6),
    paddingVertical: scaleSizeW(16),
    borderRadius: scaleSizeW(16),
  },
  statItem: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  statValue: {
    fontWeight: '800',
  },
  statLabel: {
    marginTop: scaleSizeW(4),
    textAlign: 'center',
    lineHeight: scaleSizeW(15),
  },
  statDivider: {
    width: 1,
    height: scaleSizeW(34),
    backgroundColor: 'rgba(128,128,128,0.24)',
  },
  sectionHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: scaleSizeW(16),
    marginTop: scaleSizeW(18),
    marginBottom: scaleSizeW(4),
  },
  createBtn: {
    marginLeft: 'auto',
    padding: scaleSizeW(6),
  },
  listArea: {
    flex: 1,
  },
})
