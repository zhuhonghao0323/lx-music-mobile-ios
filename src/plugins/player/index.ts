import TrackPlayer from 'react-native-track-player'
import { updateOptions, setVolume, setPlaybackRate, migratePlayerCache } from './utils'
import { initCacheDir } from './cache'

// const listenEvent = () => {
//   TrackPlayer.addEventListener('playback-error', err => {
//     console.log('playback-error', err)
//   })
//   TrackPlayer.addEventListener('playback-state', info => {
//     console.log('playback-state', info)
//   })
//   TrackPlayer.addEventListener('playback-track-changed', info => {
//     console.log('playback-track-changed', info)
//   })
//   TrackPlayer.addEventListener('playback-queue-ended', info => {
//     console.log('playback-queue-ended', info)
//   })
// }

const initial = async({ volume, playRate, cacheSize, isHandleAudioFocus, isEnableAudioOffload }: {
  volume: number
  playRate: number
  cacheSize: number
  isHandleAudioFocus: boolean
  isEnableAudioOffload: boolean
}) => {
  if (global.lx.playerStatus.isIniting || global.lx.playerStatus.isInitialized) return
  global.lx.playerStatus.isIniting = true
  console.log('Cache Size', cacheSize * 1024)
  await migratePlayerCache()
  // iOS 的 RNTP 没有原生缓存，这里准备好自建缓存目录（Android 上是空操作）
  await initCacheDir()
  await TrackPlayer.setupPlayer({
    // 以下三个是 Android(ExoPlayer) 专属参数，iOS 的 setupPlayer 只读取
    // waitForBuffer 与 autoUpdateMetadata，多余键会被忽略，因此无需按平台拆分
    maxCacheSize: cacheSize * 1024,
    maxBuffer: 1000,
    waitForBuffer: true,
    handleAudioFocus: isHandleAudioFocus,
    audioOffload: isEnableAudioOffload,
    autoUpdateMetadata: false,
  })
  global.lx.playerStatus.isInitialized = true
  global.lx.playerStatus.isIniting = false
  await updateOptions()
  await setVolume(volume)
  await setPlaybackRate(playRate)
  // listenEvent()
}


const isInitialized = () => global.lx.playerStatus.isInitialized


export {
  initial,
  isInitialized,
  setVolume,
  setPlaybackRate,
}

export {
  setResource,
  setPause,
  setPlay,
  setCurrentTime,
  getDuration,
  setStop,
  resetPlay,
  getPosition,
  updateMetaData,
  onStateChange,
  isEmpty,
  useBufferProgress,
  initTrackInfo,
} from './utils'
