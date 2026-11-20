import { memo, useCallback, useEffect, useMemo, useState } from 'react'
import { View, StyleSheet } from 'react-native'
import { NativeLeaderboardView, updatePageState, onPageCommand } from './swiftUIPageBridge'
import { getBoardsList, getListDetail, setListDetailInfo, setListDetail } from '@/core/leaderboard'
import { getLeaderboardSetting, saveLeaderboardSetting } from '@/utils/data'
import leaderboardState from '@/store/leaderboard/state'
import { handlePlay } from '@/screens/Home/Views/Mylist/MusicList/listAction'

const PAGE_ID = 'leaderboard'

/** 排行榜 SwiftUI 容器 */
export default memo(() => {
  const [boards, setBoards] = useState<Array<{ id: string, name: string }>>([])
  const [songs, setSongs] = useState<Array<{ id: string, name: string, singer: string, interval: string }>>([])
  const [boardId, setBoardId] = useState('')
  const [loading, setLoading] = useState(false)

  const loadBoard = useCallback((id: string) => {
    if (!id) return
    setLoading(true)
    setBoardId(id)
    void saveLeaderboardSetting({ boardId: id })
    setListDetailInfo(id)
    void getListDetail(id, 1).then(info => {
      const merged = setListDetail(info, id, 1)
      setSongs((merged.list ?? []).map(m => ({
        id: String(m.id),
        name: m.name,
        singer: m.singer ?? '',
        interval: m.interval ?? '',
      })))
    }).catch(() => {}).finally(() => { setLoading(false) })
  }, [])

  useEffect(() => {
    void getLeaderboardSetting().then(async({ source, boardId: savedId }) => {
      const list = await getBoardsList(source)
      const items = list.map(b => ({ id: b.id, name: b.name }))
      setBoards(items)
      const target = savedId && items.some(b => b.id == savedId) ? savedId : items[0]?.id
      if (target) loadBoard(target)
    }).catch(() => {})
  }, [loadBoard])

  const state = useMemo(() => ({
    boards: JSON.stringify(boards),
    songs: JSON.stringify(songs),
    boardId,
    loading,
  }), [boards, songs, boardId, loading])

  useEffect(() => { updatePageState(PAGE_ID, state) }, [state])

  useEffect(() => onPageCommand((pageId, command, payload) => {
    if (pageId != PAGE_ID) return
    switch (command) {
      case 'selectBoard': loadBoard(String(payload.id ?? '')); break
      case 'refresh': loadBoard(boardId); break
      case 'playSong': {
        const idx = Number(payload.index ?? -1)
        const list = leaderboardState.listDetailInfo.list
        if (idx >= 0 && idx < list.length) handlePlay('', idx)
        break
      }
      default: break
    }
  }), [boardId, loadBoard])

  if (!NativeLeaderboardView) return null
  return <View style={styles.container}><NativeLeaderboardView style={styles.view} /></View>
})

const styles = StyleSheet.create({ container: { flex: 1 }, view: { flex: 1 } })
