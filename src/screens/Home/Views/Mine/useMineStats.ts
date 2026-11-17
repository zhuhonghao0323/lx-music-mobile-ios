import { useEffect, useState } from 'react'
import { getListMusicSync } from '@/utils/listManage'
import { LIST_IDS } from '@/config/constant'
import { useMyList } from '@/store/list/hook'
import { getTotalPlayTime } from '@/utils/data'
import { formatTotalPlayTime } from '@/core/player/totalPlayTime'

/**
 * 「我的」页统计信息（只展示能真实获取的数据，不编造）。
 *
 * - 收藏歌曲数：收藏列表(LOVE)里的歌曲数量 —— 真实持久数据
 * - 歌单数：自建 + 收藏列表数量 —— 真实数据
 * - 累计播放时长：真实持久数据（播放过程中按合理正增量累加）
 */
export interface MineStats {
  favoriteCount: number
  playlistCount: number
  totalPlayTimeText: string
}

export const useMineStats = (): MineStats => {
  const allList = useMyList()
  const [favoriteCount, setFavoriteCount] = useState(() => getListMusicSync(LIST_IDS.LOVE).length)
  const [totalSeconds, setTotalSeconds] = useState(0)

  useEffect(() => {
    // 收藏列表可能是异步加载的，首帧后用同步源再取一次
    setFavoriteCount(getListMusicSync(LIST_IDS.LOVE).length)
    void getTotalPlayTime().then(setTotalSeconds)

    const handleListUpdate = () => {
      setFavoriteCount(getListMusicSync(LIST_IDS.LOVE).length)
    }
    // 每次播放进度落盘时刷新累计时长显示
    const handleProgress = () => { void getTotalPlayTime().then(setTotalSeconds) }
    global.state_event.on('mylistUpdated', handleListUpdate)
    global.state_event.on('playProgressChanged', handleProgress)
    return () => {
      global.state_event.off('mylistUpdated', handleListUpdate)
      global.state_event.off('playProgressChanged', handleProgress)
    }
  }, [])

  return {
    favoriteCount,
    playlistCount: allList.length,
    totalPlayTimeText: formatTotalPlayTime(totalSeconds),
  }
}
