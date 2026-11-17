import { forwardRef, useEffect, useImperativeHandle, useRef, useState } from 'react'
import { TouchableOpacity, View } from 'react-native'
import { type Source, type InitState } from '@/store/hotSearch/state'
import { getList } from '@/core/hotSearch'
import Text from '@/components/common/Text'
import { Icon } from '@/components/common/Icon'
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
      <Icon name="search-2" size={13} color={theme['c-primary-font']} />
      <Text color={theme['c-font']} size={13} numberOfLines={1} style={styles.keyword}>{keyword}</Text>
      {/* 前三条带热度标识（图1 的🔥效果，用图标近似） */}
      {index < 3 ? <Icon name="thumbs-up" size={11} color={theme['c-primary-font']} /> : null}
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
  keyword: {
    flex: 1,
    marginLeft: scaleSizeW(7),
    marginRight: scaleSizeW(4),
  },
})
