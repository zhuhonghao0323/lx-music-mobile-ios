import TrackPlayer, { IOSCategory, IOSCategoryOptions, State } from 'react-native-track-player'
import { Platform } from 'react-native'
import { updateOptions, setVolume, setPlaybackRate, migratePlayerCache, destroy as destroyPlayer, getPosition } from './utils'
import { getCurrentTrack, restoreTrack, updateMetaData } from './playList'
import { isNativeFlacActive, restoreNativeFlacPlayback, snapshotNativeFlacPlayback } from './nativeFlac'
import { soundEffectController } from './soundEffect'
import settingState from '@/store/setting/state'
import playerState from '@/store/player/state'

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
  await TrackPlayer.setupPlayer({
    maxCacheSize: cacheSize * 1024,
    maxBuffer: 1000,
    waitForBuffer: true,
    handleAudioFocus: isHandleAudioFocus,
    audioOffload: isEnableAudioOffload,
    autoUpdateMetadata: false,
    // iOS 音频会话：只有 setupPlayer 会读取这几个字段。
    //
    // 无论开关状态都显式指定 playback：
    // playback 会忽略侧边静音开关（外放时静音键拨下去也有声），
    // ambient / soloAmbient 才会被静音键掐掉。
    // 之前关闭状态下不传，依赖 RNTP 的默认值，实测外放静音时没声音，
    // 所以这里改成明确指定，不留给默认值。
    ...(Platform.OS == 'ios'
      ? {
          iosCategory: IOSCategory.Playback,
          iosCategoryOptions: settingState.setting['player.isPlayWithOtherApps']
            ? [IOSCategoryOptions.MixWithOthers]
            : ([] as IOSCategoryOptions[]),
        }
      : {}),
  })
  global.lx.playerStatus.isInitialized = true
  global.lx.playerStatus.isIniting = false
  await updateOptions()
  await setVolume(volume)
  await setPlaybackRate(playRate)
  await soundEffectController.applyCurrentConfig()
  // listenEvent()
}


const isInitialized = () => global.lx.playerStatus.isInitialized

const getPlayerConfig = () => ({
  volume: settingState.setting['player.volume'],
  playRate: settingState.setting['player.playbackRate'],
  cacheSize: settingState.setting['player.cacheSize'] ? parseInt(settingState.setting['player.cacheSize']) : 0,
  isHandleAudioFocus: settingState.setting['player.isHandleAudioFocus'],
  isEnableAudioOffload: settingState.setting['player.isEnableAudioOffload'],
})

let reconfigurePromise = Promise.resolve()
const reloadConfig = async() => {
  const run = async() => {
    if (global.lx.playerStatus.isIniting || !global.lx.playerStatus.isInitialized) return

    if (Platform.OS == 'ios' && isNativeFlacActive()) {
      const snapshot = await snapshotNativeFlacPlayback()
      global.lx.playerStatus.ignoreTrackPlayerLifecycle = true
      try {
        await destroyPlayer()
        await initial(getPlayerConfig())
        if (snapshot) {
          await restoreNativeFlacPlayback(snapshot)
        }
        if (playerState.musicInfo.id) {
          const isPlay = snapshot ? !['idle', 'paused', 'stopped'].includes(snapshot.state) : playerState.isPlay
          void updateMetaData(playerState.musicInfo, isPlay, playerState.lastLyric, true)
        }
      } finally {
        global.lx.playerStatus.ignoreTrackPlayerLifecycle = false
      }
      return
    }

    const [track, position, currentState] = await Promise.all([
      getCurrentTrack(),
      getPosition(),
      TrackPlayer.getState(),
    ])
    const shouldRestoreTrack = typeof track?.id == 'string' && !/\/\/default$/.test(track.id)

    await destroyPlayer()
    await initial(getPlayerConfig())

    if (!shouldRestoreTrack || !track) return
    await restoreTrack(track, position, currentState == State.Playing)
  }

  reconfigurePromise = reconfigurePromise.then(run, run)
  return reconfigurePromise
}


export {
  initial,
  isInitialized,
  reloadConfig,
  setVolume,
  setPlaybackRate,
}

export {
  applyAudioMix,
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
