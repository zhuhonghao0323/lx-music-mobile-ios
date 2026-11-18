import { useCallback, useEffect, useRef } from 'react'
import { View, TouchableOpacity, StyleSheet, PanResponder } from 'react-native'
import BackToMine from './BackToMine'
import MusicList from './MusicList'
import { useTheme } from '@/store/theme/hook'
import { haptic } from '@/utils/haptics'
import { setNavActiveId } from '@/core/common'
import { scaleSizeW } from '@/utils/pixelRatio'
import { Icon } from '@/components/common/Icon'
import Text from '@/components/common/Text'
import { createStyle } from '@/utils/tools'
import { useActiveListId } from '@/store/list/hook'
import ListOperations from './ListOperations'

/** 歌单内一排功能按钮（风格统一）：排序 / 重复 / 添加本地 / 更新 / 导入 / 导出 / 移除 */
type OpAction = 'sort' | 'duplicate' | 'localFile' | 'sync' | 'import' | 'export' | 'remove'

const ACTIONS: Array<{ id: OpAction, icon: string, label: string, needsOnline?: boolean }> = [
  { id: 'sort', icon: 'list-order', label: '排序' },
  { id: 'duplicate', icon: 'sd-card', label: '重复' },
  { id: 'localFile', icon: 'add_folder', label: '本地' },
  { id: 'sync', icon: 'available_updates', label: '更新', needsOnline: true },
  { id: 'import', icon: 'download-2', label: '导入' },
  { id: 'export', icon: 'share', label: '导出' },
  { id: 'remove', icon: 'remove', label: '移除' },
]

export default () => {
  const theme = useTheme()
  const activeListId = useActiveListId()

  // 整页右滑返回「我的」
  const backResponder = useRef(PanResponder.create({
    onStartShouldSetPanResponder: () => false,
    onMoveShouldSetPanResponder: (_e, gs) => gs.dx > 20 && Math.abs(gs.dx) > Math.abs(gs.dy) * 1.3,
    onPanResponderRelease: (_e, gs) => {
      if (gs.dx > 70) {
        haptic.tap()
        setNavActiveId('nav_mine')
      }
    },
  })).current

  useEffect(() => {
    // 进入歌单页时确保不处于抽屉态（兼容旧逻辑）
    global.app_event.changeLoveListVisible(false)
  }, [])

  const handleOp = useCallback((action: OpAction) => {
    haptic.tap()
    global.app_event.listOperation(action, activeListId)
  }, [activeListId])

  return (
    <View style={{ flex: 1 }} {...backResponder.panHandlers}>
      <BackToMine />
      {/* 一排统一风格的功能按钮，放在歌曲列表最上方 */}
      <View style={[styles.actionBar, { borderBottomColor: theme['c-border-background'] }]}>
        {ACTIONS.map(a => (
          <TouchableOpacity key={a.id} style={styles.actionBtn} activeOpacity={0.7} onPress={() => { handleOp(a.id) }}>
            <View style={[styles.actionIcon, { backgroundColor: theme['c-button-background'] }]}>
              <Icon name={a.icon} size={17} color={theme['c-font']} />
            </View>
            <Text size={10} color={theme['c-font-label']} numberOfLines={1}>{a.label}</Text>
          </TouchableOpacity>
        ))}
      </View>
      <View style={{ flex: 1 }}>
        <MusicList />
      </View>
      <ListOperations />
    </View>
  )
}

const styles = createStyle({
  actionBar: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-around',
    paddingHorizontal: scaleSizeW(6),
    paddingVertical: scaleSizeW(8),
    borderBottomWidth: StyleSheet.hairlineWidth,
  },
  actionBtn: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  actionIcon: {
    width: scaleSizeW(38),
    height: scaleSizeW(38),
    borderRadius: scaleSizeW(19),
    alignItems: 'center',
    justifyContent: 'center',
  },
})
