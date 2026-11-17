import { forwardRef, useImperativeHandle, useRef, useState } from 'react'
import { View } from 'react-native'
import type { InitState as SearchState } from '@/store/search/state'
import type { Source as MusicSource } from '@/store/search/music/state'
import type { Source as SongListSource } from '@/store/search/songlist/state'
import MusicList, { type MusicListType } from './MusicList'
import BlankView, { type BlankViewType } from './BlankView'
import SonglistList from './SonglistList'
import Text from '@/components/common/Text'
import { useTheme } from '@/store/theme/hook'

interface ListProps {
  onSearch: (keyword: string) => void
  /** 结果分类 tab：all/music 显示歌曲，songlist 显示歌单，singer/album 暂不支持 */
  tab?: string
}
export interface ListType {
  loadList: (text: string, source: MusicSource | SongListSource, type: SearchState['searchType']) => void
}

export default forwardRef<ListType, ListProps>(({ onSearch, tab = 'music' }, ref) => {
  const [listType, setListType] = useState<SearchState['searchType']>('music')
  const [showBlankView, setShowListView] = useState(true)
  const listRef = useRef<MusicListType>(null)
  const blankViewRef = useRef<BlankViewType>(null)
  const theme = useTheme()

  useImperativeHandle(ref, () => ({
    loadList(text, source, type) {
      if (text) {
        setShowListView(false)
        setListType(type)
        requestAnimationFrame(() => {
          listRef.current?.loadList(text, source)
        })
      } else {
        setShowListView(true)
        requestAnimationFrame(() => {
          blankViewRef.current?.show(source)
        })
      }
    },
  }), [])

  const unsupported = tab == 'singer' || tab == 'album'
  const useSonglist = tab == 'songlist' || (tab != 'singer' && tab != 'album' && tab != 'all' && listType == 'songlist')

  return (
    showBlankView
      ? <BlankView ref={blankViewRef} onSearch={onSearch} />
      : unsupported
        ? (
            <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center' }}>
              <Text size={14} color={theme['c-font-label']}>{tab == 'singer' ? '歌手搜索暂不支持' : '专辑搜索暂不支持'}</Text>
            </View>
          )
        : useSonglist
          ? <SonglistList ref={listRef} />
          : <MusicList ref={listRef} />
  )
})
