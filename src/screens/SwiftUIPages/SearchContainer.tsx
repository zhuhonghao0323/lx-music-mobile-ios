import { memo, useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { View, StyleSheet } from 'react-native'
import { NativeSearchView, updatePageState, onPageCommand } from './swiftUIPageBridge'
import { getSearchHistory, clearHistoryList, addHistoryWord } from '@/core/search/search'
import searchMusicState from '@/store/search/music/state'
import { search } from '@/core/search/music'
import { handlePlay } from '@/screens/Home/Views/Mylist/MusicList/listAction'

const PAGE_ID = 'search'

/** 搜索页 SwiftUI 容器 */
export default memo(() => {
  const [history, setHistory] = useState<string[]>([])
  const [results, setResults] = useState<Array<{ index: number, id: string, name: string, singer: string, duration?: string }>>([])
  const [searching, setSearching] = useState(false)
  const [hasKeyword, setHasKeyword] = useState(false)
  const keywordRef = useRef('')

  const reloadHistory = useCallback(async() => {
    const h = await getSearchHistory()
    setHistory(h)
  }, [])
  useEffect(() => { void reloadHistory() }, [reloadHistory])

  const state = useMemo(() => ({
    history: history.join('\u0001'),
    hots: '',
    results: JSON.stringify(results),
    searching,
    hasKeyword,
  }), [history, results, searching, hasKeyword])

  useEffect(() => { updatePageState(PAGE_ID, state) }, [state])

  useEffect(() => onPageCommand((pageId, command, payload) => {
    if (pageId != PAGE_ID) return
    switch (command) {
      case 'clearHistory':
        clearHistoryList()
        setHistory([])
        break
      case 'search': {
        const kw = String(payload.keyword ?? '').trim()
        if (!kw) break
        keywordRef.current = kw
        void addHistoryWord(kw)
        setSearching(true)
        setHasKeyword(true)
        const src = searchMusicState.source
        void search(kw, 1, src).then((list) => {
          setResults((list || []).map((m, i) => ({
            index: i,
            id: String(m.id),
            name: m.name,
            singer: m.singer ?? '',
            duration: m.interval ?? '',
          })))
        }).catch(() => {}).finally(() => { setSearching(false) })
        break
      }
      case 'playResult': {
        const idx = Number(payload.index ?? -1)
        const list = searchMusicState.listInfos[searchMusicState.source]?.list ?? []
        if (idx >= 0 && idx < list.length) {
          const target = { musicInfo: list[idx] }
          handlePlay(target as never, idx)
        }
        break
      }
      case 'switchSource': break
      default: break
    }
  }), [])

  if (!NativeSearchView) return null
  return (
    <View style={styles.container}>
      <NativeSearchView style={styles.view} />
    </View>
  )
})

const styles = StyleSheet.create({
  container: { flex: 1 },
  view: { flex: 1 },
})
