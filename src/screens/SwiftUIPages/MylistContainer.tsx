import { memo, useEffect, useMemo } from 'react'
import { View, StyleSheet } from 'react-native'
import { NativeMylistView, updatePageState, onPageCommand } from './swiftUIPageBridge'
import { useMyList, useActiveListId } from '@/store/list/hook'
import { getListMusicSync } from '@/utils/listManage'
import { setActiveList } from '@/core/list'
import { handlePlay } from '@/screens/Home/Views/Mylist/MusicList/listAction'

const PAGE_ID = 'mylist'

/** 歌单详情 SwiftUI 容器 */
export default memo(() => {
  const allList = useMyList()
  const activeId = useActiveListId()

  const state = useMemo(() => {
    const active = allList.find(l => l.id == activeId)
    const musics = getListMusicSync(activeId)
    return {
      listName: active?.name ?? '歌单',
      listId: activeId,
      lists: allList.map(l => `${l.id}|${l.name}`).join('\u0001'),
      songs: JSON.stringify(musics.map((m, i) => ({
        id: `${m.id}__${i}`,
        name: m.name,
        singer: m.singer ?? '',
        interval: m.interval ?? '',
      }))),
    }
  }, [allList, activeId])

  useEffect(() => { updatePageState(PAGE_ID, state) }, [state])

  useEffect(() => onPageCommand((pageId, command, payload) => {
    if (pageId != PAGE_ID) return
    switch (command) {
      case 'switchList': {
        const id = String(payload.id ?? '')
        if (id) setActiveList(id)
        break
      }
      case 'playSong': {
        const idx = Number(payload.index ?? -1)
        if (idx >= 0) handlePlay(activeId, idx)
        break
      }
      case 'listOp': {
        const action = String(payload.action ?? '')
        const id = String(payload.id ?? activeId)
        if (action && id) global.app_event.listOperation(action as never, id)
        break
      }
      case 'searchInList': break
      default: break
    }
  }), [activeId])

  if (!NativeMylistView) return null
  return <View style={styles.container}><NativeMylistView style={styles.view} /></View>
})

const styles = StyleSheet.create({ container: { flex: 1 }, view: { flex: 1 } })
