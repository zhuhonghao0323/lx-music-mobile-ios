import { LIST_IDS } from '@/config/constant'
import { addListMusics, removeListMusics } from '@/core/list'
import settingState from '@/store/setting/state'
import playerState from '@/store/player/state'
import { getListMusics, userLists } from '@/utils/listManage'

/**
 * 取出当前正在播放歌曲的「歌曲信息」对象。
 * 播放列表里的歌曲可能是下载/缓存包装后的对象（带 progress / metadata），
 * 收藏、去重都统一使用里层的 LX.Music.MusicInfo。
 */
export const getPlayMusicInfo = (): LX.Music.MusicInfo | null => {
  const musicInfo = playerState.playMusicInfo.musicInfo
  if (!musicInfo) return null
  return 'progress' in musicInfo ? musicInfo.metadata.musicInfo : musicInfo
}

/** 判断某个列表是否属于「收藏列表」（我的收藏 + 用户自建列表） */
export const isFavoriteList = (listId: string): boolean => {
  if (listId == LIST_IDS.LOVE) return true
  if (listId == LIST_IDS.DEFAULT || listId == LIST_IDS.TEMP || listId == LIST_IDS.DOWNLOAD) return false
  return userLists.some(l => l.id == listId)
}

/** 所有收藏列表的 id（我的收藏 + 用户自建列表） */
export const getFavoriteListIds = (): string[] => [
  LIST_IDS.LOVE,
  ...userLists.map(l => l.id),
]

/**
 * 判断歌曲是否已经收藏在任意一个收藏列表中。
 * 「我的收藏」是聚合列表，正常情况检查它即可；同时兜底检查用户自建列表，
 * 以兼容旧数据（自建列表里有、但还没同步进「我的收藏」的歌曲）。
 */
export const isMusicFavorited = async(musicInfo: LX.Music.MusicInfo): Promise<boolean> => {
  const id = musicInfo.id
  for (const listId of getFavoriteListIds()) {
    const list = await getListMusics(listId)
    if (list.some(m => m.id == id)) return true
  }
  return false
}

/**
 * 把「我的收藏」同步为全量收藏清单：
 * 凡是收藏在任意用户自建列表里的歌曲，都会出现在「我的收藏」里，且不重复。
 * 只做增量补充，不改动已有顺序、不删除，避免影响用户手动排序。
 */
let syncing = false
let pending = false
export const syncMyFavoriteList = async(): Promise<void> => {
  if (syncing) {
    pending = true
    return
  }
  syncing = true
  try {
    // 同步过程中（写「我的收藏」会再次触发列表更新事件）可能又收到新的变更，
    // 用 pending 标记保证最终状态一定会被重新计算一次。
    do {
      pending = false
      const loveList = await getListMusics(LIST_IDS.LOVE)
      const exists = new Set(loveList.map(m => m.id))
      const missing: LX.Music.MusicInfo[] = []
      const seen = new Set<string>()
      for (const listInfo of userLists) {
        const list = await getListMusics(listInfo.id)
        for (const musicInfo of list) {
          if (exists.has(musicInfo.id) || seen.has(musicInfo.id)) continue
          seen.add(musicInfo.id)
          missing.push(musicInfo)
        }
      }
      if (!missing.length) continue
      // 直接走 list_event，避免再经过 addListMusics 触发不必要的同步逻辑
      await global.list_event.list_music_add(LIST_IDS.LOVE, missing, settingState.setting['list.addMusicLocationType'])
    } while (pending)
  } finally {
    // 单飞锁复位：这里赋值常量 false 而非基于旧值累加，不存在读改写竞态
    // eslint-disable-next-line require-atomic-updates
    syncing = false
  }
}

/**
 * 收藏：添加到「我的收藏」（轻点心形 / 封面右上滑动）
 * @param musicInfo 歌曲
 * @param listId 可选，指定收藏到哪个列表（长按选择列表时用）
 */
export const addToFavorite = async(musicInfo: LX.Music.MusicInfo, listId?: string): Promise<void> => {
  const target = listId ?? LIST_IDS.LOVE
  await addListMusics(target, [musicInfo], settingState.setting['list.addMusicLocationType'])
  // 收藏到其它列表时，同步补充进「我的收藏」聚合清单
  if (target != LIST_IDS.LOVE) await syncMyFavoriteList()
}

/**
 * 取消收藏：把歌曲从「我的收藏」以及所有收藏列表里移除，
 * 使之真正变为「未收藏」状态（否则仍会出现在聚合清单里）。
 */
export const removeFromFavorite = async(musicInfo: LX.Music.MusicInfo): Promise<void> => {
  const id = musicInfo.id
  // 先移除用户自建列表里的引用，再移除「我的收藏」，避免同步逻辑把歌曲重新补回来
  for (const listInfo of userLists) {
    const list = await getListMusics(listInfo.id)
    if (list.some(m => m.id == id)) await removeListMusics(listInfo.id, [id])
  }
  await removeListMusics(LIST_IDS.LOVE, [id])
}

/**
 * 切换收藏状态（心形按钮轻点 / 封面滑动）
 * @returns 切换后是否已收藏
 */
export const toggleFavorite = async(musicInfo: LX.Music.MusicInfo): Promise<boolean> => {
  if (await isMusicFavorited(musicInfo)) {
    await removeFromFavorite(musicInfo)
    return false
  }
  await addToFavorite(musicInfo)
  return true
}

/**
 * 列表歌曲变化后，若涉及收藏列表则把「我的收藏」同步为全量清单。
 * 由 core/init 注册到 app_event.myListMusicUpdate。
 */
export const handleFavoriteListChange = (ids: string[]): void => {
  if (!ids.some(id => isFavoriteList(id))) return
  void syncMyFavoriteList()
}
