import { useEffect, useState } from 'react'
import { getListMusicSync } from '@/utils/listManage'
import { LIST_IDS } from '@/config/constant'
import playerState from '@/store/player/state'
import { useMyList } from '@/store/list/hook'

/**
 * 「我的」页统计信息（只展示能真实获取的数据，不编造）。
 *
 * - 收藏歌曲数：收藏列表(LOVE)里的歌曲数量 —— 真实持久数据
 * - 歌单数：自建 + 收藏列表数量 —— 真实数据
 * - 本次播放：本次会话已播放过的歌曲数 —— 真实但仅当前会话
 *
 * 项目没有「累计听歌数 / 累计播放时长 / 历史记录」的持久化数据源，
 * 因此不展示这些指标，避免给出假数据。
 */
export interface MineStats {
  favoriteCount: number
  playlistCount: number
  sessionPlayedCount: number
}

export const useMineStats = (): MineStats => {
  const allList = useMyList()
  const [favoriteCount, setFavoriteCount] = useState(() => getListMusicSync(LIST_IDS.LOVE).length)
  const [sessionPlayedCount, setSessionPlayedCount] = useState(() => playerState.playedList.length)

  useEffect(() => {
    // 收藏列表可能是异步加载的，首帧后用同步源再取一次
    setFavoriteCount(getListMusicSync(LIST_IDS.LOVE).length)
    setSessionPlayedCount(playerState.playedList.length)

    const handlePlayedChanged = (list: typeof playerState.playedList) => {
      setSessionPlayedCount(list.length)
    }
    const handleListUpdate = () => {
      setFavoriteCount(getListMusicSync(LIST_IDS.LOVE).length)
    }
    global.state_event.on('playPlayedListChanged', handlePlayedChanged)
    global.state_event.on('mylistUpdated', handleListUpdate)
    return () => {
      global.state_event.off('playPlayedListChanged', handlePlayedChanged)
      global.state_event.off('mylistUpdated', handleListUpdate)
    }
  }, [])

  return {
    favoriteCount,
    playlistCount: allList.length,
    sessionPlayedCount,
  }
}
