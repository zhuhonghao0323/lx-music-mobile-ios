import { addPlayedList, clearPlayedList } from '@/core/player/playedList'
import { pause, playNext, resetCustomSourceForNewSong } from '@/core/player/player'
import { setStatusText, setIsPlay } from '@/core/player/playStatus'
// import { resetPlayerMusicInfo } from '@/core/player/playInfo'
import { setStop, setPlay, reloadConfig } from '@/plugins/player'
import { delayUpdateMusicInfo, updateMetaData } from '@/plugins/player/playList'
import { soundEffectController } from '@/plugins/player/soundEffect'
import playerState from '@/store/player/state'
import settingState from '@/store/setting/state'
import { onHeadphonesDisconnected } from '@/utils/nativeModules/utils'
import { AppState, Platform } from 'react-native'
import TrackPlayer, { Event as TPEvent, State } from 'react-native-track-player'


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
    // 「与其他应用同时播放」开关变化：iOS 音频会话的 category options 只在
    // setupPlayer 时读取，切换开关后不重建会话就会出现「开了混音却没声音」。
    if (Platform.OS == 'ios' && keys.includes('player.isPlayWithOtherApps')) {
      void reloadConfig()
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

    // 「与其他应用同时播放」模式的守护：
    //
    // 现象：开了混音后，App 长时间在后台（或锁屏很久），其它 App 以独占方式
    // 启动音频会让系统 deactivate 我们的 AVAudioSession，底层 AVPlayer 被停住，
    // 但 JS 侧 UI / NowPlaying 仍认为「正在播放」，于是锁屏控件存在却点不动。
    //
    // 处理：
    // 1) 监听底层播放状态，若「UI 认为在播」而底层已 paused/stopped，自动恢复一次
    // 2) 回到前台时也补一次恢复
    // 都只在混音模式下生效，避免影响正常的用户暂停。
    let recovering = false
    const recoverIfStalled = () => {
      if (recovering) return
      if (!settingState.setting['player.isPlayWithOtherApps']) return
      if (!playerState.isPlay || !playerState.playMusicInfo.musicInfo) return
      if (global.lx.isPlayedStop) return
      // 用户主动点过暂停：绝不自动恢复（否则暂停键会失效）
      if (global.lx.isUserPauseIntent) return
      recovering = true
      // 延迟一点，避开音频会话恢复瞬间的抖动
      setTimeout(() => {
        void setPlay().finally(() => { recovering = false })
      }, 220)
    }

    // 底层状态变化：故意停了就不管，只有「UI 说在播、底层说停了」才恢复
    TrackPlayer.addEventListener(TPEvent.PlaybackState, ({ state }: { state: State }) => {
      if (state == State.Paused || state == State.Stopped) {
        recoverIfStalled()
      }
    })

    // 混音模式下偶发「播放中但没声音」：其它 App 抢走会话后底层音量可能被清零。
    // 进入播放态时把配置音量重新应用一次（幂等，不会影响用户手动调节的音量）。
    TrackPlayer.addEventListener(TPEvent.PlaybackState, ({ state }: { state: State }) => {
      if (state != State.Playing) return
      if (!settingState.setting['player.isPlayWithOtherApps']) return
      const configuredVolume = settingState.setting['player.volume']
      TrackPlayer.getVolume().then(current => {
        // 仅在异常（接近 0 / 超出范围）时纠正，避免打断用户的音量调节
        if (current == null || current <= 0.01 || current > 1) {
          void TrackPlayer.setVolume(configuredVolume).catch(() => {})
        }
      }).catch(() => {})
    })

    AppState.addEventListener('change', (state) => {
      if (state != 'active') return
      recoverIfStalled()
    })
  }
}
