import { memo, useCallback, useEffect } from 'react'
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
import MyList from '../Mylist/MyList'

/** 快捷入口图标按钮 */
const QuickEntry = ({ icon, label, onPress }: { icon: string, label: string, onPress: () => void }) => {
  const theme = useTheme()
  const isGlass = useIsGlass()
  return (
    <TouchableOpacity
      style={styles.quickEntry}
      activeOpacity={0.7}
      onPress={() => { haptic.tap(); onPress() }}
    >
      <View style={StyleSheet.compose(styles.quickIcon, {
        backgroundColor: isGlass ? 'rgba(255,255,255,0.10)' : theme['c-primary-light-500-alpha-800'],
      })}>
        <Icon name={icon} size={18} color={theme['c-primary-font']} />
      </View>
      <Text style={styles.quickLabel} size={11} color={theme['c-font-label']} numberOfLines={1}>{label}</Text>
    </TouchableOpacity>
  )
}

/**
 * Tab 3 · 我的（收藏 + 个人 + 设置入口）。
 *
 * 结构对标波点音乐：
 *   顶部栏（标题 + 设置齿轮）
 *   → 个人信息卡
 *   → 快捷入口（喜欢）
 *   → 歌单区（直接复用现有 MyList，含自建与收藏歌单的全部操作）
 *
 * 复用 MyList 而不是重搭列表，是为了让新建/重命名/排序/导入导出/
 * 同步等既有能力全部保留，不因布局重构而丢失。
 */
export default memo(() => {
  const theme = useTheme()
  const t = useI18n()
  const statusBarHeight = useStatusbarHeight()
  const isGlass = useIsGlass()

  const openSetting = useCallback(() => {
    haptic.tap()
    setNavActiveId('nav_setting')
  }, [])

  const openLove = useCallback(() => {
    haptic.tap()
    global.app_event.changeLoveListVisible(true)
    setNavActiveId('nav_love')
  }, [])

  // MyList 组件默认要收到 changeLoveListVisible 才挂载，
  // 在「我的」页里它是常驻内容，所以挂载时就主动触发一次。
  useEffect(() => {
    global.app_event.changeLoveListVisible(true)
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

      <View style={StyleSheet.compose(styles.profileCard, {
        backgroundColor: isGlass ? 'rgba(255,255,255,0.08)' : theme['c-primary-light-500-alpha-800'],
      })}>
        <View style={StyleSheet.compose(styles.avatar, { backgroundColor: theme['c-primary-font'] })}>
          <Icon name="logo" size={24} color={theme['c-main-background']} />
        </View>
        <View style={styles.profileInfo}>
          <Text size={16} color={theme['c-font']}>{t('user_api_local')}</Text>
          <Text style={styles.profileSub} size={11} color={theme['c-font-label']}>{t('nav_mine_subtitle')}</Text>
        </View>
      </View>

      <View style={styles.quickRow}>
        <QuickEntry icon="love" label={t('nav_love')} onPress={openLove} />
      </View>

      <View style={styles.sectionHeader}>
        <Text size={15} color={theme['c-font']}>{t('nav_my_lists')}</Text>
      </View>

      {/* 歌单区：复用现有 MyList（自建/收藏歌单 + 全部管理操作） */}
      <View style={styles.listArea}>
        <MyList />
      </View>
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
    marginHorizontal: scaleSizeW(16),
    marginTop: scaleSizeW(6),
    padding: scaleSizeW(14),
    borderRadius: scaleSizeW(16),
  },
  avatar: {
    width: scaleSizeW(48),
    height: scaleSizeW(48),
    borderRadius: scaleSizeW(24),
    alignItems: 'center',
    justifyContent: 'center',
  },
  profileInfo: {
    marginLeft: scaleSizeW(12),
    flex: 1,
  },
  profileSub: {
    marginTop: scaleSizeW(3),
  },
  quickRow: {
    flexDirection: 'row',
    marginTop: scaleSizeW(14),
    paddingHorizontal: scaleSizeW(16),
  },
  quickEntry: {
    alignItems: 'center',
    width: scaleSizeW(56),
  },
  quickIcon: {
    width: scaleSizeW(44),
    height: scaleSizeW(44),
    borderRadius: scaleSizeW(22),
    alignItems: 'center',
    justifyContent: 'center',
  },
  quickLabel: {
    marginTop: scaleSizeW(5),
  },
  sectionHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: scaleSizeW(16),
    marginTop: scaleSizeW(18),
    marginBottom: scaleSizeW(4),
  },
  listArea: {
    flex: 1,
  },
})
