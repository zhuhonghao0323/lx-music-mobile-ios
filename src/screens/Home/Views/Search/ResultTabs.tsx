import { memo } from 'react'
import { View, ScrollView, TouchableOpacity } from 'react-native'
import Text from '@/components/common/Text'
import { useTheme } from '@/store/theme/hook'
import { createStyle } from '@/utils/tools'
import { scaleSizeW } from '@/utils/pixelRatio'

/** 搜索结果分类 tab（骨架）。
 * 目前底层只支持「歌曲 / 歌单」两种搜索；「综合 / 歌手 / 专辑」为占位展示。
 */
const TABS = [
  { id: 'all', label: '综合' },
  { id: 'music', label: '单曲' },
  { id: 'singer', label: '歌手' },
  { id: 'album', label: '专辑' },
  { id: 'songlist', label: '歌单' },
] as const

export type ResultTabId = typeof TABS[number]['id']

export default memo(({ active, onChange }: {
  active: ResultTabId
  onChange: (id: ResultTabId) => void
}) => {
  const theme = useTheme()
  return (
    <View style={[styles.wrap, { backgroundColor: theme['c-app-background'] }]}>
      <ScrollView horizontal showsHorizontalScrollIndicator={false}>
        <View style={styles.row}>
          {TABS.map(tab => (
            <TouchableOpacity
              key={tab.id}
              style={styles.tab}
              onPress={() => { onChange(tab.id) }}
              activeOpacity={0.7}
            >
              <View style={[
                styles.tabInner,
                active == tab.id ? { backgroundColor: theme['c-button-background-selected'] } : null,
              ]}>
                <Text
                  size={14}
                  color={active == tab.id ? theme['c-button-font-selected'] : theme['c-font-label']}
                  style={active == tab.id ? styles.activeText : undefined}
                >{tab.label}</Text>
              </View>
            </TouchableOpacity>
          ))}
        </View>
      </ScrollView>
    </View>
  )
})

const styles = createStyle({
  wrap: {
    paddingVertical: scaleSizeW(6),
  },
  row: {
    flexDirection: 'row',
    paddingHorizontal: scaleSizeW(12),
  },
  tab: {
    marginRight: scaleSizeW(6),
  },
  tabInner: {
    paddingHorizontal: scaleSizeW(16),
    paddingVertical: scaleSizeW(7),
    borderRadius: scaleSizeW(18),
  },
  activeText: {
    fontWeight: '600',
  },
})
