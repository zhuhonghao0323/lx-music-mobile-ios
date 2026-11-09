import { addPlayedList, clearPlayedList } from '@/core/player/playedList'
import { pause, playNext, resetCustomSourceForNewSong } from '@/core/player/player'
import { setStatusText, setIsPlay } from '@/core/player/playStatus'
// import { resetPlayerMusicInfo } from '@/core/player/playInfo'
import { setStop, setPlay } from '@/plugins/player'
import { delayUpdateMusicInfo, updateMetaData } from '@/plugins/player/playList'
import { soundEffectController } from '@/plugins/player/soundEffect'
import playerState from '@/store/player/state'
import settingState from '@/store/setting/state'
import { onHeadphonesDisconnected } from '@/utils/nativeModules/utils'
import { AppState, Platform } from 'react-native'


export default async(setting: LX.AppSetting) => {
  const setPlayStatus = () => {
    setIsPlay(true)
  }
  const setPauseStatus = () => {
    setIsPlay(false)
    if (global.lx.isPlayedStop) void pause()
  }

  const handleEnded = () => {
    // setTimeout(() => {
    if (global.lx.isPlayedStop) {
      setStatusText(global.i18n.t('player__end'))
      return
    }
    // resetPlayerMusicInfo()
    // global.app_event.stop()
    setStatusText(global.i18n.t('player__end'))
    void playNext(true)
    // })
  }

  const setStopStatus = () => {
    setIsPlay(false)
    setStatusText('')
    void setStop()
  }

  const updatePic = () => {
    if (!settingState.setting['player.isShowNotificationImage']) return
    if (playerState.playMusicInfo.musicInfo && playerState.musicInfo.pic) {
      delayUpdateMusicInfo(playerState.musicInfo, playerState.lastLyric)
    }
  }

  const refreshNowPlaying = () => {
    if (!playerState.playMusicInfo.musicInfo) return
    void updateMetaData(playerState.musicInfo, playerState.isPlay, playerState.lastLyric, true)
  }

  const handleConfigUpdated: typeof global.state_event.configUpdated = (keys, settings) => {
    if (keys.includes('player.togglePlayMethod')) {
      const newValue = settings['player.togglePlayMethod']
      if (playerState.playedList.length) clearPlayedList()
      const playMusicInfo = playerState.playMusicInfo
      if (newValue == 'random' && playMusicInfo.musicInfo && !playMusicInfo.isTempPlay) addPlayedList({ ...(playMusicInfo as LX.Player.PlayMusicInfo) })
    }
    if (keys.some(soundEffectController.isSettingKey)) void soundEffectController.applyCurrentConfig()
  }


  global.app_event.on('play', setPlayStatus)
  global.app_event.on('pause', setPauseStatus)
  global.app_event.on('error', setPauseStatus)
  global.app_event.on('stop', setStopStatus)
  global.app_event.on('playerEnded', handleEnded)
  global.app_event.on('picUpdated', updatePic)
  global.app_event.on('musicToggled', refreshNowPlaying)
  global.app_event.on('musicToggled', () => {
    const id = playerState.playMusicInfo.musicInfo?.id
    if (id) resetCustomSourceForNewSong(id)
  })
  global.app_event.on('lyricUpdated', refreshNowPlaying)
  global.state_event.on('configUpdated', handleConfigUpdated)
  void soundEffectController.applyCurrentConfig()

  if (Platform.OS == 'ios') {
    onHeadphonesDisconnected(() => {
      // 混音模式下忽略耳机拔出中断，避免与其它 App 同时播放时被误暂停
      if (settingState.setting['player.isPlayWithOtherApps']) return
      if (!playerState.isPlay) return
      void pause()
    })

    // 「与其他应用同时播放」模式下，锁屏 / 进入后台时系统的音频中断有可能
    // 让底层播放器进入 paused，但 JS 侧 UI 状态仍是「播放中」。
    // 回到前台时，如果 UI 认为在播而底层确实停了，就主动恢复一次，
    // 保证锁屏 / 后台都不会导致音乐停止。
    AppState.addEventListener('change', (state) => {
      if (state != 'active') return
      if (!settingState.setting['player.isPlayWithOtherApps']) return
      if (!playerState.isPlay || !playerState.playMusicInfo.musicInfo) return
      if (global.lx.isPlayedStop) return
      // 延迟一点，避开系统恢复音频会话时的抖动
      setTimeout(() => { void setPlay() }, 180)
    })
  }
}
