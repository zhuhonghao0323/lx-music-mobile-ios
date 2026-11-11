import { useEffect, useState } from 'react'
import { getListMusics } from '@/core/list'
import { getMusicPicUrl } from '@/utils/musicCover'

/**
 * 歌单封面缓存：歌单 id → 第一首歌的封面 url。
 * 进程级缓存，避免每次渲染都异步读取歌单；歌单歌曲变化后需要失效重取。
 */
const coverCache = new Map<string, string | null>()

/** 清空封面缓存（歌单内容变化时调用，下次会重新取第一首封面） */
export const clearListCoverCache = () => {
  coverCache.clear()
}

/**
 * 获取歌单封面（第一首歌的 pic），带进程级缓存。
 * 返回 null 表示无封面或加载中。
 */
export const useListCover = (listId: string): string | null => {
  const [cover, setCover] = useState<string | null>(coverCache.get(listId) ?? null)

  useEffect(() => {
    let cancelled = false
    const cached = coverCache.get(listId)
    if (cached !== undefined) {
      setCover(cached)
      return
    }
    void getListMusics(listId).then(list => {
      const pic = getMusicPicUrl(list[0])
      coverCache.set(listId, pic)
      if (!cancelled) setCover(pic)
    }).catch(() => {
      if (!cancelled) setCover(null)
    })
    return () => { cancelled = true }
  }, [listId])

  return cover
}
