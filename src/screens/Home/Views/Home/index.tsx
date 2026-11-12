import { memo, useCallback, useState } from 'react'
import { View, TouchableOpacity, StyleSheet } from 'react-native'
import { useStatusbarHeight } from '@/store/common/hook'
import { useI18n } from '@/lang'
import { createStyle } from '@/utils/tools'
import { Icon } from '@/components/common/Icon'
import Text from '@/components/common/Text'
import StatusBar from '@/components/common/StatusBar'
import { scaleSizeW } from '@/utils/pixelRatio'
import { haptic } from '@/utils/haptics'
import { setNavActiveId } from '@/core/common'
import { useBeansColors, useBeansAccent, BEANS_NETEASE_RED, BEANS_SPACING, BEANS_RADIUS, beansCard, beansSheen } from '@/theme/beans'
import SongList from '../SongList'
import Leaderboard from '../Leaderboard'

/** 主页顶部频道：歌单 / 榜单，同页切换 */
type Channel = 'songlist' | 'top'

/**
 * Tab 1 · 主页「发现」—— 对齐 Beans Music 首页布局。
 *
 * Beans 结构（自上而下）：
 *   问候语（晚上好 / 发现好音乐）+ 右上刷新圆钮
 *   → 平台切换胶囊（选中态网易云红，未选中玻璃）
 *   → 分区标题（每日推荐 / 查看全部）
 *   → 频道切换 + 搜索
 *   → 内容卡片（复用现有 SongList / Leaderboard，保留全部功能）
 *
 * 头部固定、内容区 flex 铺满：避免 ScrollView 与内部 FlatList 嵌套滚动冲突。
 * 底部三大图标逻辑保持不变，由外层 BottomNavBar 承载。
 */
export default memo(() => {
  const t = useI18n()
  const statusBarHeight = useStatusbarHeight()
  const colors = useBeansColors()
  const accent = useBeansAccent()
  const [channel, setChannel] = useState<Channel>('songlist')

  const switchChannel = useCallback((next: Channel) => {
    if (next == channel) return
    haptic.select()
    setChannel(next)
  }, [channel])

  const refresh = useCallback(() => {
    haptic.tap()
    global.app_event.focus()
  }, [])

  const openSearch = useCallback(() => {
    haptic.tap()
    setNavActiveId('nav_search')
  }, [])

  return (
    <View style={[styles.container, { backgroundColor: colors.background }]}>
      <StatusBar />

      {/* 固定头部区 */}
      <View style={[styles.head, { paddingTop: statusBarHeight + scaleSizeW(12) }]}>
        {/* 问候语 + 刷新 */}
        <View style={styles.greetingRow}>
          <View style={styles.greetingText}>
            <Text size={28} color={colors.text} style={styles.greeting}>{greeting()}</Text>
            <Text size={13} color={colors.textSecondary} style={styles.subGreeting}>{t('home_discover_hint')}</Text>
          </View>
          <TouchableOpacity
            style={[styles.refreshBtn, { backgroundColor: colors.glass, borderColor: colors.border }]}
            onPress={refresh}
            activeOpacity={0.7}
          >
            <Icon name="available_updates" size={20} color={colors.text} />
          </TouchableOpacity>
        </View>

        {/* 平台切换胶囊 */}
        <View style={[styles.platformBar, { backgroundColor: colors.glass, borderColor: colors.border }]}>
          <TouchableOpacity
            style={[styles.platformActive, { backgroundColor: BEANS_NETEASE_RED.primary }]}
            onPress={() => { switchChannel('songlist') }}
            activeOpacity={0.8}
          >
            <Icon name="music_time" size={15} color="#FFFFFF" />
            <Text size={15} color="#FFFFFF" style={styles.platformLabel}>{t('nav_songlist')}</Text>
          </TouchableOpacity>
          <TouchableOpacity
            style={styles.platformInactive}
            onPress={() => { switchChannel('top') }}
            activeOpacity={0.8}
          >
            <Icon name="play" size={14} color={colors.textSecondary} />
            <Text size={15} color={colors.textSecondary} style={styles.platformLabel}>{t('nav_top')}</Text>
          </TouchableOpacity>
        </View>

        {/* 分区标题 + 查看全部 */}
        <View style={styles.sectionHeader}>
          <Text size={21} color={colors.text} style={styles.sectionTitle}>{t('home_daily_recommend')}</Text>
          <TouchableOpacity style={styles.sectionMore} onPress={openSearch} activeOpacity={0.7}>
            <Text size={13} color={colors.textSecondary}>{t('home_view_all')}</Text>
            <Icon name="chevron-right" size={13} color={colors.textSecondary} />
          </TouchableOpacity>
        </View>

        {/* 频道切换 + 搜索 */}
        <View style={styles.channelRow}>
          <ChannelPill
            label={t('nav_songlist')}
            active={channel == 'songlist'}
            colors={colors}
            accent={accent}
            onPress={() => { switchChannel('songlist') }}
          />
          <ChannelPill
            label={t('nav_top')}
            active={channel == 'top'}
            colors={colors}
            accent={accent}
            onPress={() => { switchChannel('top') }}
          />
          <View style={styles.channelSpacer} />
          <TouchableOpacity
            style={[styles.searchBtn, { backgroundColor: colors.glass, borderColor: colors.border }]}
            onPress={openSearch}
            activeOpacity={0.7}
          >
            <Icon name="search-2" size={16} color={colors.textSecondary} />
          </TouchableOpacity>
        </View>
      </View>

      {/* 内容区：Beans 玻璃大卡片，flex 铺满，内部组件自带滚动 */}
      <View style={[styles.contentCard, beansCard(colors, BEANS_RADIUS.card)]}>
        <View pointerEvents="none" style={[styles.cardSheen, beansSheen(colors, BEANS_RADIUS.card)]} />
        <View style={styles.content}>
          {channel == 'songlist' ? <SongList /> : <Leaderboard />}
        </View>
      </View>
    </View>
  )
})

/** 按时段返回问候语（Beans 首页「晚上好 / 早上好」） */
const greeting = () => {
  const h = new Date().getHours()
  if (h < 6) return '夜深了'
  if (h < 11) return '早上好'
  if (h < 14) return '中午好'
  if (h < 18) return '下午好'
  return '晚上好'
}

const ChannelPill = ({ label, active, colors, accent, onPress }: {
  label: string
  active: boolean
  colors: ReturnType<typeof useBeansColors>
  accent: string
  onPress: () => void
}) => (
  <TouchableOpacity
    style={[styles.channelPill, {
      backgroundColor: active ? accent : colors.glass,
      borderColor: active ? 'transparent' : colors.border,
    }]}
    onPress={onPress}
    activeOpacity={0.7}
  >
    <Text size={13} color={active ? '#1C1A1A' : colors.textSecondary} style={styles.channelPillText}>{label}</Text>
  </TouchableOpacity>
)

const styles = createStyle({
  container: {
    flex: 1,
  },
  head: {
    paddingHorizontal: BEANS_SPACING.page,
  },
  greetingRow: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    justifyContent: 'space-between',
  },
  greetingText: {
    flex: 1,
  },
  greeting: {
    fontWeight: '800',
    letterSpacing: 0.5,
  },
  subGreeting: {
    marginTop: scaleSizeW(3),
  },
  refreshBtn: {
    width: scaleSizeW(44),
    height: scaleSizeW(44),
    borderRadius: scaleSizeW(22),
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: StyleSheet.hairlineWidth,
  },
  platformBar: {
    flexDirection: 'row',
    alignItems: 'center',
    height: scaleSizeW(50),
    borderRadius: scaleSizeW(25),
    marginTop: scaleSizeW(14),
    padding: scaleSizeW(3),
    borderWidth: StyleSheet.hairlineWidth,
  },
  platformActive: {
    flex: 1,
    height: '100%',
    borderRadius: scaleSizeW(22),
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
  },
  platformInactive: {
    flex: 1,
    height: '100%',
    borderRadius: scaleSizeW(22),
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
  },
  platformLabel: {
    marginLeft: scaleSizeW(7),
    fontWeight: '600',
  },
  sectionHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginTop: scaleSizeW(20),
    marginBottom: scaleSizeW(10),
  },
  sectionTitle: {
    fontWeight: '800',
  },
  sectionMore: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  channelRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: scaleSizeW(12),
  },
  channelPill: {
    paddingHorizontal: scaleSizeW(14),
    paddingVertical: scaleSizeW(7),
    borderRadius: BEANS_RADIUS.pill,
    marginRight: scaleSizeW(8),
    borderWidth: StyleSheet.hairlineWidth,
  },
  channelPillText: {
    fontWeight: '600',
  },
  channelSpacer: {
    flex: 1,
  },
  searchBtn: {
    width: scaleSizeW(34),
    height: scaleSizeW(34),
    borderRadius: scaleSizeW(17),
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: StyleSheet.hairlineWidth,
  },
  contentCard: {
    flex: 1,
    marginHorizontal: BEANS_SPACING.page,
    marginBottom: scaleSizeW(8),
    overflow: 'hidden',
  },
  cardSheen: {
    position: 'absolute',
  },
  content: {
    flex: 1,
  },
})
