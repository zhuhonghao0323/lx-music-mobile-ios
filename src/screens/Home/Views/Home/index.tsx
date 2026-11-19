import { memo, useCallback, useState } from 'react'
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
import SongList from '../SongList'
import Leaderboard from '../Leaderboard'
import SourceIconButton from './SourceIconButton'
import { isSwiftUIPageSupported } from '@/screens/SwiftUIPages/swiftUIPageBridge'
import HomeSwiftUIContainer from '@/screens/SwiftUIPages/HomeContainer'

/** 主页顶部频道：歌单 / 榜单，同页切换 */
type Channel = 'songlist' | 'top'

/**
 * Tab 1 · 主页（发现 + 搜索入口）。
 *
 * 结构对标波点音乐：
 *   顶部栏（品牌名 + 频道 Tab + 搜索框）
 *   → 内容区（歌单网格 / 榜单列表，按频道切换）
 *
 * 歌单与榜单都直接复用现有的 SongList / Leaderboard 页面组件，
 * 因此排序、音源筛选、单曲菜单等能力全部原样保留。
 */
const HomeContent = memo(() => {
  const theme = useTheme()
  const t = useI18n()
  const statusBarHeight = useStatusbarHeight()
  const isGlass = useIsGlass()
  const [channel, setChannel] = useState<Channel>('songlist')

  const switchChannel = useCallback((next: Channel) => {
    if (next == channel) return
    haptic.select()
    setChannel(next)
  }, [channel])

  const openSearch = useCallback(() => {
    haptic.tap()
    setNavActiveId('nav_search')
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
        {/* 品牌位改为音源平台筛选图标（点击切换酷我/QQ/酷狗/网易/咪咕） */}
        <View style={styles.headerLeft}>
          <SourceIconButton />
          <ChannelTab label={t('nav_songlist')} active={channel == 'songlist'} onPress={() => { switchChannel('songlist') }} />
          <ChannelTab label={t('nav_top')} active={channel == 'top'} onPress={() => { switchChannel('top') }} />
        </View>
        {/* 搜索入口：胶囊形搜索框，点击进入搜索二级页 */}
        <TouchableOpacity
          style={StyleSheet.compose(styles.searchBox, {
            backgroundColor: isGlass ? 'rgba(255,255,255,0.10)' : theme['c-primary-light-500-alpha-800'],
          })}
          activeOpacity={0.7}
          onPress={openSearch}
        >
          <Icon name="search-2" size={14} color={theme['c-font-label']} />
          <Text style={styles.searchText} size={12} color={theme['c-font-label']} numberOfLines={1}>{t('search_input_placeholder')}</Text>
        </TouchableOpacity>
      </View>

      {/* 内容区 */}
      <View style={styles.content}>
        {channel == 'songlist' ? <SongList /> : <Leaderboard />}
      </View>
    </View>
  )
})

const ChannelTab = ({ label, active, onPress }: { label: string, active: boolean, onPress: () => void }) => {
  const theme = useTheme()
  return (
    <TouchableOpacity style={styles.channelTab} onPress={onPress} activeOpacity={0.7}>
      {/* 选中态仅用「文字高亮 + 加粗放大」表示，去掉下方横杆，避免遮挡 */}
      <Text
        size={active ? 18 : 15}
        color={active ? theme['c-primary-font'] : theme['c-font-label']}
        style={active ? styles.channelTabActiveText : undefined}
      >{label}</Text>
    </TouchableOpacity>
  )
}

/**
 * 主页 —— 平台分发。
 * iOS 使用 SwiftUI（系统 Grid + 材质 + SF Symbols），其它保留 RN 实现。
 */
export default memo(() => {
  if (isSwiftUIPageSupported) return <HomeSwiftUIContainer />
  return <HomeContent />
})

const styles = createStyle({
  container: {
    flex: 1,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingRight: scaleSizeW(10),
    zIndex: 10,
  },
  headerLeft: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    paddingLeft: scaleSizeW(16),
  },
  brand: {
    fontWeight: '700',
    marginRight: scaleSizeW(14),
  },
  channelTab: {
    paddingHorizontal: scaleSizeW(6),
    height: '100%',
    justifyContent: 'center',
    alignItems: 'center',
  },
  channelTabActiveText: {
    fontWeight: '800',
  },
  searchBox: {
    flexDirection: 'row',
    alignItems: 'center',
    height: scaleSizeW(32),
    paddingHorizontal: scaleSizeW(10),
    borderRadius: scaleSizeW(16),
    maxWidth: scaleSizeW(150),
    minWidth: scaleSizeW(96),
  },
  searchText: {
    marginLeft: scaleSizeW(5),
    flexShrink: 1,
  },
  content: {
    flex: 1,
  },
})
