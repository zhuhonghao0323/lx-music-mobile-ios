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

/** 统一的字符串归一化：去掉空白/常见标点、转小写，避免「歌名 - 歌手」细微差异导致判不中 */
const normalize = (str: string | undefined | null): string =>
  (str ?? '')
    .toLowerCase()
    .replace(/\s+/g, '')
    .replace(/[''`´]/g, '')
    .replace(/[()（）[\]【】<>《》「」『』]/g, '')

/**
 * 歌曲是否「同一首」的判定键：歌名 + 演唱者。
 *
 * 为什么不用 id：用户早期从其它音源导入到列表的歌曲记录的是当时的 id，
 * 与现在播放时拿到的新 id 并不相同，用 id 比较会永远判定为未收藏。
 * 歌名 + 演唱者是跨音源稳定的身份信息，因此统一用它作为收藏判定依据。
 */
export const getMusicKey = (musicInfo: LX.Music.MusicInfo): string =>
  `${normalize(musicInfo.name)}__${normalize(musicInfo.singer)}`

/** 找出某个歌曲在指定列表中命中的条目（按 歌名+演唱者 匹配） */
export const findMusicInList = (list: LX.Music.MusicInfo[], musicInfo: LX.Music.MusicInfo): LX.Music.MusicInfo | undefined => {
  const key = getMusicKey(musicInfo)
  // 优先按 id 精确命中，再退化为 歌名+演唱者 匹配
  return list.find(m => m.id == musicInfo.id) ?? list.find(m => getMusicKey(m) == key)
}

/**
 * 判断歌曲是否已经收藏在任意一个收藏列表中。
 * 「我的收藏」是聚合列表，同时检查用户自建列表以兼容历史数据；
 * 匹配使用 歌名+演唱者，兼容不同音源产生不同 id 的情况。
 */
export const isMusicFavorited = async(musicInfo: LX.Music.MusicInfo): Promise<boolean> => {
  for (const listId of getFavoriteListIds()) {
    const list = await getListMusics(listId)
    if (findMusicInList(list, musicInfo)) return true
  }
  return false
}

/**
 * 查出歌曲当前所在的全部收藏列表（用于长按收藏按钮时准确显示 / 取消）。
 * 返回列表信息（id + 名称），按 我的收藏 → 用户自建列表 的顺序。
 */
export const getFavoriteListsContaining = async(
  musicInfo: LX.Music.MusicInfo,
): Promise<Array<{ id: string, name: string }>> => {
  const result: Array<{ id: string, name: string }> = []
  for (const listId of getFavoriteListIds()) {
    const list = await getListMusics(listId)
    if (!findMusicInList(list, musicInfo)) continue
    result.push({
      id: listId,
      name: listId == LIST_IDS.LOVE ? global.i18n.t('list_name_love') : (userLists.find(l => l.id == listId)?.name ?? listId),
    })
  }
  return result
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
      const exists = new Set(loveList.map(m => getMusicKey(m)))
      const missing: LX.Music.MusicInfo[] = []
      const seen = new Set<string>()
      for (const listInfo of userLists) {
        const list = await getListMusics(listInfo.id)
        for (const musicInfo of list) {
          const key = getMusicKey(musicInfo)
          if (exists.has(key) || seen.has(key)) continue
          seen.add(key)
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
 * 按 歌名+演唱者 定位，兼容历史数据里 id 不同的同款歌曲。
 */
export const removeFromFavorite = async(musicInfo: LX.Music.MusicInfo): Promise<void> => {
  // 先移除用户自建列表里的引用，再移除「我的收藏」，避免同步逻辑把歌曲重新补回来
  for (const listInfo of userLists) {
    const list = await getListMusics(listInfo.id)
    const hit = findMusicInList(list, musicInfo)
    if (hit) await removeListMusics(listInfo.id, [hit.id])
  }
  const loveList = await getListMusics(LIST_IDS.LOVE)
  const loveHit = findMusicInList(loveList, musicInfo)
  if (loveHit) await removeListMusics(LIST_IDS.LOVE, [loveHit.id])
}

/**
 * 只从指定列表取消收藏（长按收藏按钮里逐个取消时用）。
 */
export const removeFromFavoriteList = async(listId: string, musicInfo: LX.Music.MusicInfo): Promise<void> => {
  const list = await getListMusics(listId)
  const hit = findMusicInList(list, musicInfo)
  if (hit) await removeListMusics(listId, [hit.id])
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
