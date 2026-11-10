import { useEffect, useState } from 'react'
import state, { type InitState } from './state'
import { getListMusics } from '@/core/list'
import { isMusicFavorited, findMusicInList } from '@/core/favorite'

/**
 * 当前歌曲是否已收藏（收藏在任意收藏列表都算已收藏），随列表变化/切歌自动刷新
 */
export const useIsMusicFavorited = (musicInfo: LX.Music.MusicInfo | null) => {
  const [favorited, setFavorited] = useState(false)
  const musicId = musicInfo?.id ?? null
  const musicName = musicInfo?.name ?? ''
  const musicSinger = musicInfo?.singer ?? ''

  useEffect(() => {
    let cancelled = false
    const update = () => {
      if (!musicId || !musicInfo) {
        setFavorited(false)
        return
      }
      void isMusicFavorited(musicInfo).then(result => {
        if (!cancelled) setFavorited(result)
      })
    }
    update()
    global.app_event.on('myListMusicUpdate', update)
    return () => {
      cancelled = true
      global.app_event.off('myListMusicUpdate', update)
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [musicId, musicName, musicSinger])

  return favorited
}

export const useMyList = () => {
  const [lists, setList] = useState(state.allList)
  lists[0].name = global.i18n.t('list_name_default')
  lists[1].name = global.i18n.t('list_name_love')

  useEffect(() => {
    const handleConfigUpdate = (keys: Array<keyof LX.AppSetting>) => {
      if (!keys.includes('common.langId')) return
      setList((lists) => {
        lists[0].name = global.i18n.t('list_name_default')
        lists[1].name = global.i18n.t('list_name_love')
        return [...lists]
      })
    }
    global.state_event.on('mylistUpdated', setList)
    global.state_event.on('configUpdated', handleConfigUpdate)
    return () => {
      global.state_event.off('mylistUpdated', setList)
      global.state_event.off('configUpdated', handleConfigUpdate)
    }
  }, [])

  return lists
}

export const useActiveListId = () => {
  const [id, setId] = useState(state.activeListId)

  useEffect(() => {
    global.state_event.on('mylistToggled', setId)
    return () => {
      global.state_event.off('mylistToggled', setId)
    }
  }, [])

  return id
}


export const useMusicList = () => {
  const [list, setList] = useState<LX.List.ListMusics>([])

  useEffect(() => {
    const handleToggle = (activeListId: string) => {
      void getListMusics(activeListId).then((list) => {
        setList([...list])
      })
    }
    const handleChange = (ids: string[]) => {
      if (!ids.includes(state.activeListId)) return
      void getListMusics(state.activeListId).then((list) => {
        setList([...list])
      })
    }
    global.state_event.on('mylistToggled', handleToggle)
    global.app_event.on('myListMusicUpdate', handleChange)

    handleToggle(state.activeListId)

    return () => {
      global.state_event.off('mylistToggled', handleToggle)
      global.app_event.off('myListMusicUpdate', handleChange)
    }
  }, [])

  return list
}

export const useMusicExistsList = (list: LX.List.MyListInfo, musicInfo: LX.Music.MusicInfo) => {
  const [isExists, setExists] = useState(false)

  useEffect(() => {
    let cancelled = false
    const check = () => {
      void getListMusics(list.id).then((musics) => {
        // 用 歌名+演唱者 判定，兼容不同音源导入后 id 不一致的同一首歌
        if (!cancelled) setExists(!!findMusicInList(musics, musicInfo))
      })
    }
    check()
    // 列表内容变化后重新判定，避免弹窗里状态滞后
    global.app_event.on('myListMusicUpdate', check)
    return () => {
      cancelled = true
      global.app_event.off('myListMusicUpdate', check)
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [list.id, musicInfo.id, musicInfo.name, musicInfo.singer])

  return isExists
}

export const useListFetching = (listId: string) => {
  const [fetching, setFetching] = useState(!!state.fetchingListStatus[listId])

  useEffect(() => {
    let prevStatus = state.fetchingListStatus[listId]
    const handleUpdate = (status: InitState['fetchingListStatus']) => {
      let currentStatus = status[listId]
      if (currentStatus == null || prevStatus == status[listId]) return
      setFetching(prevStatus = currentStatus)
    }
    global.state_event.on('fetchingListStatusUpdated', handleUpdate)
    return () => {
      global.state_event.off('fetchingListStatusUpdated', handleUpdate)
    }
  }, [listId])

  return fetching
}

