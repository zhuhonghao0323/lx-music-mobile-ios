import { forwardRef, useEffect, useImperativeHandle, useRef, useState } from 'react'
import { TouchableOpacity, View } from 'react-native'
import { type Source, type InitState } from '@/store/hotSearch/state'
import { getList } from '@/core/hotSearch'
import Text from '@/components/common/Text'
import { createStyle } from '@/utils/tools'
import { useTheme } from '@/store/theme/hook'
import { useI18n } from '@/lang'
import { scaleSizeW } from '@/utils/pixelRatio'

interface ListProps {
  onSearch: (keyword: string) => void
}
export interface HotSearchType {
  show: (source: Source) => void
}

export type List = NonNullable<InitState['sourceList'][keyof InitState['sourceList']]>

/** 单个热搜 chip：搜索图标 + 关键词，两列等宽 */
const ListItem = ({ keyword, index, onSearch }: {
  keyword: string
  index: number
  onSearch: (keyword: string) => void
}) => {
  const theme = useTheme()
  return (
    <TouchableOpacity
      style={[styles.button, { backgroundColor: theme['c-button-background'] }]}
      activeOpacity={0.7}
      onPress={() => { onSearch(keyword) }}
    >
      <View style={[
        styles.rankBadge,
        { backgroundColor: index < 3 ? (index == 0 ? '#FF3B30' : index == 1 ? '#FF9500' : '#FFCC00') : theme['c-font-label'] },
      ]}>
        <Text size={11} color="#FFFFFF" style={styles.rankText}>{index + 1}</Text>
      </View>
      <Text color={theme['c-font']} size={13} numberOfLines={1} style={styles.keyword}>{keyword}</Text>
    </TouchableOpacity>
  )
}

export default forwardRef<HotSearchType, ListProps>((props, ref) => {
  const [list, setList] = useState<List>([])
  const t = useI18n()
  const theme = useTheme()

  const isUnmountedRef = useRef(false)
  useEffect(() => {
    isUnmountedRef.current = false
    return () => { isUnmountedRef.current = true }
  }, [])

  useImperativeHandle(ref, () => ({
    show(source) {
      void getList(source).then((list) => {
        if (isUnmountedRef.current) return
        setList(list)
      })
    },
  }), [])

  if (!list.length) return null

  return (
    <View style={styles.container}>
      <View style={styles.titleRow}>
        <Text style={styles.title} size={17} color={theme['c-font']}>{t('search_hot_search')}</Text>
        <Text size={12} color={theme['c-font-label']}>{t('source_real_all')}</Text>
      </View>
      <View style={styles.list}>
        {list.map((keyword, index) => (
          <ListItem keyword={keyword} index={index} key={keyword} onSearch={props.onSearch} />
        ))}
      </View>
    </View>
  )
})

const styles = createStyle({
  container: {
    marginBottom: scaleSizeW(18),
  },
  titleRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginBottom: scaleSizeW(8),
  },
  title: {
    fontWeight: '700',
  },
  list: {
    flexDirection: 'row',
    flexWrap: 'wrap',
  },
  button: {
    // 两列等宽：各占 48%，中间留 4% 间隙
    width: '48%',
    marginRight: '2%',
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: scaleSizeW(12),
    paddingVertical: scaleSizeW(11),
    borderRadius: scaleSizeW(22),
    marginBottom: scaleSizeW(9),
  },
  rankBadge: {
    width: scaleSizeW(18),
    height: scaleSizeW(18),
    borderRadius: scaleSizeW(9),
    alignItems: 'center',
    justifyContent: 'center',
  },
  rankText: {
    fontWeight: '700',
  },
  keyword: {
    flex: 1,
    marginLeft: scaleSizeW(8),
    marginRight: scaleSizeW(4),
  },
})
