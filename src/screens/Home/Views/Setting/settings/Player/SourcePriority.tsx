import { memo, useState } from 'react'
import { View, TouchableOpacity, StyleSheet } from 'react-native'
import Text from '@/components/common/Text'
import { useI18n } from '@/lang'
import { updateSetting } from '@/core/common'
import { useSettingValue } from '@/store/setting/hook'
import { ALL_SOURCES, SOURCE_NAMES, type OnlineSourceId } from '@/core/sourcePriority'
import { useTheme } from '@/store/theme/hook'
import { scaleSizeW } from '@/utils/pixelRatio'
import { Icon } from '@/components/common/Icon'

/**
 * 音源管理：复选启用 + 上下移动排序。
 * 顺序即播放失败时自动切换的顺序，每次切歌从第一项重新开始。
 */
export default memo(() => {
  const t = useI18n()
  const theme = useTheme()
  const priority = useSettingValue('player.sourcePriority')
  const enabled = useSettingValue('player.enabledSources')
  // 本地维护一份顺序，保证交互即时反馈
  const [order, setOrder] = useState<string[]>(() => {
    const list = Array.isArray(priority) && priority.length ? [...priority] : [...ALL_SOURCES]
    for (const id of ALL_SOURCES) if (!list.includes(id)) list.push(id)
    return list.filter(id => (ALL_SOURCES as readonly string[]).includes(id))
  })
  const enabledSet = new Set(enabled)

  const persist = (nextOrder: string[], nextEnabled: string[]) => {
    setOrder(nextOrder)
    updateSetting({
      'player.sourcePriority': nextOrder,
      'player.enabledSources': nextEnabled,
    })
  }

  const toggleSource = (id: string) => {
    const next = new Set(enabledSet)
    if (next.has(id)) {
      // 至少保留一个启用音源
      if (next.size <= 1) return
      next.delete(id)
    } else next.add(id)
    persist(order, [...next])
  }

  const move = (index: number, delta: number) => {
    const target = index + delta
    if (target < 0 || target >= order.length) return
    const next = [...order]
    const tmp = next[index]
    next[index] = next[target]
    next[target] = tmp
    persist(next, [...enabledSet])
  }

  return (
    <View style={styles.wrap}>
      <Text style={styles.title} size={14} color={theme['c-font']}>{t('setting_source_priority_title')}</Text>
      <Text style={styles.desc} size={11} color={theme['c-font-label']}>{t('setting_source_priority_desc')}</Text>
      {
        order.map((id, index) => {
          const isOn = enabledSet.has(id)
          return (
            <View key={id} style={[styles.row, { backgroundColor: theme['c-primary-background'] }]}>
              <TouchableOpacity style={styles.checkBox} onPress={() => { toggleSource(id) }} activeOpacity={0.6}>
                <Icon name={isOn ? 'checkbox-marked' : 'checkbox-blank-outline'} size={18} color={isOn ? theme['c-primary-font'] : theme['c-font-label']} />
              </TouchableOpacity>
              <Text style={styles.name} size={13} color={isOn ? theme['c-font'] : theme['c-font-label']}>
                {SOURCE_NAMES[id as OnlineSourceId] ?? id}
              </Text>
              <View style={styles.arrows}>
                <TouchableOpacity onPress={() => { move(index, -1) }} disabled={index == 0} style={styles.arrowBtn} activeOpacity={0.5}>
                  <Icon name="chevron-left-2" size={14} color={index == 0 ? theme['c-font-label'] : theme['c-primary-font']} style={{ transform: [{ rotate: '90deg' }] }} />
                </TouchableOpacity>
                <TouchableOpacity onPress={() => { move(index, 1) }} disabled={index == order.length - 1} style={styles.arrowBtn} activeOpacity={0.5}>
                  <Icon name="chevron-right-2" size={14} color={index == order.length - 1 ? theme['c-font-label'] : theme['c-primary-font']} style={{ transform: [{ rotate: '90deg' }] }} />
                </TouchableOpacity>
              </View>
            </View>
          )
        })
      }
    </View>
  )
})

const styles = StyleSheet.create({
  wrap: { marginTop: 12, marginBottom: 6 },
  title: { fontWeight: '600', marginBottom: 2 },
  desc: { marginBottom: 8, lineHeight: 16 },
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    borderRadius: 10,
    paddingHorizontal: 8,
    paddingVertical: 5,
    marginBottom: 6,
  },
  checkBox: { padding: 4, marginRight: 6 },
  name: { flex: 1 },
  arrows: { flexDirection: 'row', gap: 2 },
  arrowBtn: { paddingHorizontal: scaleSizeW(5), paddingVertical: 4 },
})
