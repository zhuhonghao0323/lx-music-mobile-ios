import { memo, useEffect, useMemo, useRef, useState } from 'react'
import { View, StyleSheet } from 'react-native'
import { NativeMineView, updatePageState, onPageCommand } from './swiftUIPageBridge'
import { useMyList } from '@/store/list/hook'
import { getListMusicSync } from '@/utils/listManage'
import { LIST_IDS } from '@/config/constant'
import { getTotalPlayTime } from '@/utils/data'
import { getMusicPicUrl } from '@/utils/musicCover'
import { formatTotalPlayTime } from '@/core/player/totalPlayTime'
import { setNavActiveId } from '@/core/common'
import { setActiveList } from '@/core/list'

const PAGE_ID = 'mine'

/** 「我的」页 SwiftUI 容器：把统计与歌单推给原生，接住操作回传 */
export default memo(() => {
  const allList = useMyList()
  const [totalTime, setTotalTime] = useState('--')

  // 歌单封面：用首个列表的封面 hook 逐个取（保持与 RN 版一致）
  useEffect(() => {
    void getTotalPlayTime().then(v => { setTotalTime(formatTotalPlayTime(v)) })
  }, [])

  // 歌单数据（id/name/count/cover）
  // 封面取该列表第一首歌的专辑图，与 RN 版 ListGrid 保持一致
  const lists = useMemo(() => allList.map(item => {
    const musics = getListMusicSync(item.id)
    const first = musics.length ? musics[0] : null
    const cover = first ? getMusicPicUrl(first) : undefined
    return {
      id: item.id,
      name: item.name,
      count: musics.length,
      cover: cover ?? undefined,
    }
  }), [allList])

  const state = useMemo(() => ({
    favoriteCount: getListMusicSync(LIST_IDS.LOVE).length,
    playlistCount: allList.length,
    totalPlayTime: totalTime,
    lists: JSON.stringify(lists),
  }), [allList, lists, totalTime])

  useEffect(() => { updatePageState(PAGE_ID, state) }, [state])

  const stateRef = useRef(state)
  stateRef.current = state

  useEffect(() => onPageCommand((pageId, command, payload) => {
    if (pageId != PAGE_ID) return
    switch (command) {
      case 'openSetting': setNavActiveId('nav_setting'); break
      case 'createList': global.app_event.requestCreateList(); break
      case 'openList': {
        const id = String(payload.id ?? '')
        if (!id) break
        setActiveList(id)
        setNavActiveId('nav_love')
        break
      }
      case 'listOp': {
        const id = String(payload.id ?? '')
        const action = payload.action as 'localFile' | 'sync' | 'import' | 'export' | 'remove'
        if (id && action) global.app_event.listOperation(action, id)
        break
      }
      default: break
    }
  }), [])

  if (!NativeMineView) return null
  return (
    <View style={styles.container}>
      <NativeMineView style={styles.view} />
    </View>
  )
})

const styles = StyleSheet.create({
  container: { flex: 1 },
  view: { flex: 1 },
})
