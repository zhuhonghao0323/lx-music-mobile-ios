import { getPosition, updateMetaData } from '@/plugins/player'
import playerState from '@/store/player/state'
import settingState from '@/store/setting/state'
import { clearNowPlayingInfo, pauseNowPlaying, playNowPlaying, stopNowPlaying } from '@/utils/nativeModules/nowPlaying'
import { setNowPlayingHidden, isNowPlayingHidden } from './nowPlayingVisibility'

const getElapsedTime = async() => getPosition().catch(() => playerState.progress.nowPlayTime)

export const syncNowPlayingVisibility = async(hidden: boolean) => {
  setNowPlayingHidden(hidden)
  if (!hidden) return
  // 开启混音：立即清空锁屏控件（原生端会禁用所有遥控命令）
  await clearNowPlayingInfo().catch(() => {})
}

export const syncNowPlayingState = async(type: 'play' | 'pause' | 'stop') => {
  // 混音模式：不写锁屏控件状态
  if (isNowPlayingHidden()) return
  const elapsedTime = type == 'stop' ? 0 : await getElapsedTime()

  if (type == 'play') {
    await playNowPlaying({
      elapsedTime,
      playbackRate: settingState.setting['player.playbackRate'],
    }).catch(() => {})
    return
  }

  if (type == 'pause') {
    await pauseNowPlaying({
      elapsedTime,
      playbackRate: 0,
    }).catch(() => {})
    return
  }

  await stopNowPlaying({
    elapsedTime,
    playbackRate: 0,
  }).catch(() => {})
}

export const syncNowPlayingMetadata = (force = false) => {
  // 混音模式：不写锁屏控件元数据
  if (isNowPlayingHidden()) return
  if (!playerState.playMusicInfo.musicInfo) return
  void updateMetaData(playerState.musicInfo, playerState.isPlay, playerState.lastLyric, force)
}
