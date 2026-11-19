import { memo, useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { View, StyleSheet } from 'react-native'
import { NativeHomeView, updatePageState, onPageCommand } from './swiftUIPageBridge'
import songlistState from '@/store/songlist/state'
import { getList, setList, setListInfo } from '@/core/songlist'
import { setNavActiveId } from '@/core/common'
import { setActiveList } from '@/core/list'
import { haptic } from '@/utils/haptics'

const PAGE_ID = 'home'

/** 从 tags 里查出当前分类名 */
const getTagName = (source: LX.OnlineSource, tagId: string): string => {
  if (!tagId) return ''
  const group = songlistState.tags[source]
  if (!group) return ''
  // 分类是两级结构：{ name, list: [{ id, name }] }
  for (const g of group.tags) {
    const hit = g.list?.find(t => t.id == tagId)
    if (hit) return hit.name
  }
  const hot = group.hotTag?.find(t => t.id == tagId)
  return hot?.name ?? ''
}

const SOURCE_LABEL: Partial<Record<string, string>> = {
  kw: '酷我',
  tx: 'QQ',
  kg: '酷狗',
  wy: '网易云',
  mg: '咪咕',
  all: '聚合',
}

/** 主页（歌单发现）SwiftUI 容器 */
export default memo(() => {
  const [channel, setChannel] = useState<'songlist' | 'top'>('songlist')
  const [items, setItems] = useState<Array<{ id: string, name: string, img: string, source?: string }>>([])
  const [loading, setLoading] = useState(false)
  const [hasMore, setHasMore] = useState(true)
  const loadingRef = useRef(false)
  const pageRef = useRef(0)

  const loadPage = useCallback((page: number) => {
    if (loadingRef.current) return
    loadingRef.current = true
    setLoading(true)
    const info = songlistState.listInfo
    getList(info.source, info.tagId, info.sortId, page).then(res => {
      const result = setList(res, info.tagId, info.sortId, page)
      pageRef.current = page
      setItems(result.list.map(i => ({ id: String(i.id), name: i.name, img: i.img ?? '', source: i.source })))
      setHasMore(songlistState.listInfo.maxPage > page)
    }).catch(() => {}).finally(() => {
      loadingRef.current = false
      setLoading(false)
    })
  }, [])

  useEffect(() => {
    setListInfo(songlistState.listInfo.source, songlistState.listInfo.tagId, songlistState.listInfo.sortId)
    loadPage(1)
  }, [loadPage])

  const state = useMemo(() => {
    const source = songlistState.listInfo.source
    const sources = songlistState.sources.map(s => `${s}|${SOURCE_LABEL[s] ?? s.toUpperCase()}`).join('\u0001')
    const sortList = songlistState.sortList[source] ?? []
    const sorts = sortList.map(s => `${s.id}|${s.name}`).join('\u0001')
    return {
      items: JSON.stringify(items),
      loading,
      hasMore,
      channel,
      sourceName: SOURCE_LABEL[source] ?? source.toUpperCase(),
      sources,
      sorts,
      sortId: songlistState.listInfo.sortId ?? '',
      tagName: getTagName(source, songlistState.listInfo.tagId),
    }
  }, [items, loading, hasMore, channel])

  useEffect(() => { updatePageState(PAGE_ID, state) }, [state])

  useEffect(() => onPageCommand((pageId, command, payload) => {
    if (pageId != PAGE_ID) return
    switch (command) {
      case 'openSearch': setNavActiveId('nav_search'); break
      case 'loadMore': loadPage(pageRef.current + 1); break
      case 'switchSource': global.app_event.songlistSourceChanged(songlistState.listInfo.source); break
      case 'selectSource': {
        const src = String(payload.source ?? '') as LX.OnlineSource
        if (src && src != songlistState.listInfo.source) {
          global.app_event.songlistSourceChanged(src)
        }
        break
      }
      case 'selectSort': {
        const sortId = String(payload.sortId ?? '')
        if (!sortId) break
        const info = songlistState.listInfo
        setListInfo(info.source, info.tagId, sortId)
        loadPage(1)
        break
      }
      case 'openTagPicker': break
      case 'switchChannel': {
        const next = String(payload.channel ?? 'songlist') as 'songlist' | 'top'
        setChannel(next)
        if (next == 'songlist') loadPage(1)
        break
      }
      case 'openItem': {
        haptic.tap()
        const id = String(payload.id ?? '')
        if (!id) break
        // 用当前列表作为来源，交给 RN 的歌单详情页
        setActiveList(id)
        setNavActiveId('nav_songlist')
        break
      }
      default: break
    }
  }), [loadPage])

  if (!NativeHomeView) return null
  return (
    <View style={styles.container}>
      <NativeHomeView style={styles.view} />
    </View>
  )
})

const styles = StyleSheet.create({
  container: { flex: 1 },
  view: { flex: 1 },
})
