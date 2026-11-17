import { forwardRef, useCallback, useEffect, useImperativeHandle, useRef, useState } from 'react'
import { TouchableOpacity, View } from 'react-native'
import { Icon } from '@/components/common/Icon'
import Text from '@/components/common/Text'
import { useI18n } from '@/lang'
import { useTheme } from '@/store/theme/hook'
import { createStyle } from '@/utils/tools'
import { scaleSizeW } from '@/utils/pixelRatio'
import { getSearchHistory, clearHistoryList, removeHistoryWord } from '@/core/search/search'

interface HistorySearchProps {
  onSearch: (keyword: string) => void
}
export interface HistorySearchType {
  show: () => void
}
type List = string[]

/** 历史词条：圆角灰色 chip + 关闭图标 */
const ListItem = ({ keyword, onSearch, onRemove }: {
  keyword: string
  onSearch: (keyword: string) => void
  onRemove: (keyword: string) => void
}) => {
  const theme = useTheme()
  return (
    <TouchableOpacity
      style={[styles.chip, { backgroundColor: theme['c-button-background'] }]}
      activeOpacity={0.7}
      onPress={() => { onSearch(keyword) }}
      onLongPress={() => { onRemove(keyword) }}
    >
      <Text color={theme['c-font']} size={13} numberOfLines={1} style={styles.chipText}>{keyword}</Text>
      <TouchableOpacity hitSlop={{ top: 6, bottom: 6, left: 6, right: 6 }} onPress={() => { onRemove(keyword) }}>
        <Icon name="close" size={11} color={theme['c-font-label']} />
      </TouchableOpacity>
    </TouchableOpacity>
  )
}

export default forwardRef<HistorySearchType, HistorySearchProps>((props, ref) => {
  const [list, setList] = useState<List>([])
  const isUnmountedRef = useRef(false)
  const t = useI18n()
  const theme = useTheme()

  useEffect(() => {
    isUnmountedRef.current = false
    return () => { isUnmountedRef.current = true }
  }, [])

  useImperativeHandle(ref, () => ({
    show() {
      void getSearchHistory().then((list) => {
        if (isUnmountedRef.current) return
        setList(list)
      })
    },
  }), [])

  const handleClear = () => {
    clearHistoryList()
    setList([])
  }

  const handleRemove = useCallback((keyword: string) => {
    setList(curr => {
      const index = curr.indexOf(keyword)
      if (index < 0) return curr
      removeHistoryWord(index)
      const next = [...curr]
      next.splice(index, 1)
      return next
    })
  }, [])

  if (!list.length) return null

  return (
    <View style={styles.container}>
      <View style={styles.titleRow}>
        <Text size={17} color={theme['c-font']} style={styles.title}>{t('search_history_search')}</Text>
        <TouchableOpacity onPress={handleClear} style={styles.clearBtn} activeOpacity={0.7}>
          <Icon name="eraser" color={theme['c-font-label']} size={15} />
        </TouchableOpacity>
      </View>
      <View style={styles.list}>
        {list.map(keyword => (
          <ListItem keyword={keyword} key={keyword} onSearch={props.onSearch} onRemove={handleRemove} />
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
    marginBottom: scaleSizeW(10),
  },
  title: {
    fontWeight: '700',
  },
  clearBtn: {
    padding: scaleSizeW(5),
  },
  list: {
    flexDirection: 'row',
    flexWrap: 'wrap',
  },
  chip: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: scaleSizeW(12),
    paddingVertical: scaleSizeW(8),
    borderRadius: scaleSizeW(16),
    marginRight: scaleSizeW(8),
    marginBottom: scaleSizeW(9),
    maxWidth: '48%',
  },
  chipText: {
    marginRight: scaleSizeW(6),
  },
})
