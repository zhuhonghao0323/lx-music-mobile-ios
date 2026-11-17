/* eslint-disable @typescript-eslint/no-misused-promises */
import TrackPlayer, { Event as TPEvent } from 'react-native-track-player'
import { Platform } from 'react-native'
import { pause, play, playNext, playPrev } from '@/core/player/player'
import { markTimeoutExitInteraction } from '@/core/player/timeoutExit'
import { initUnifiedPlayerController } from './controller'
import { exitApp } from '@/core/common'
import { applyAudioMix } from './utils'
import playerState from '@/store/player/state'
import settingState from '@/store/setting/state'

let isInitialized = false
let shouldResumeAfterDuck = false
let duckRecoveryTimeouts: Array<ReturnType<typeof setTimeout>> = []

const clearDuckRecoveryTimeouts = () => {
  for (const timeout of duckRecoveryTimeouts) clearTimeout(timeout)
  duckRecoveryTimeouts = []
}

const restoreConfiguredVolume = () => {
  clearDuckRecoveryTimeouts()

  const applyVolume = () => {
    void TrackPlayer.setVolume(settingState.setting['player.volume']).catch(() => {})
  }

  applyVolume()
  duckRecoveryTimeouts = [250, 1000].map(delay => setTimeout(applyVolume, delay))
}

const registerPlaybackService = async() => {
  if (isInitialized) return

  console.log('reg services...')
  initUnifiedPlayerController()
  TrackPlayer.addEventListener(TPEvent.RemotePlay, () => {
    // console.log('remote-play')
    markTimeoutExitInteraction()
    play()
  })

  TrackPlayer.addEventListener(TPEvent.RemotePause, () => {
    // console.log('remote-pause')
    markTimeoutExitInteraction()
    void pause()
  })

  TrackPlayer.addEventListener(TPEvent.RemoteNext, () => {
    // console.log('remote-next')
    markTimeoutExitInteraction()
    void playNext()
  })

  TrackPlayer.addEventListener(TPEvent.RemotePrevious, () => {
    // console.log('remote-previous')
    markTimeoutExitInteraction()
    void playPrev()
  })

  TrackPlayer.addEventListener(TPEvent.RemoteStop, () => {
    // console.log('remote-stop')
    shouldResumeAfterDuck = false
    clearDuckRecoveryTimeouts()
    global.lx.isPlayedStop = false
    exitApp('Remote Stop')
  })

  TrackPlayer.addEventListener(TPEvent.RemoteDuck, ({ permanent, paused, ducking }) => {
    // 「与其他应用同时播放」模式（mixWithOthers）下的中断处理。
    //
    // 原生层（RNTrackPlayer.swift 的 handleInterruption）收到
    // AVAudioSession.interruptionNotification 时只发这个 remote-duck 事件，不会自己暂停、
    // 也不会在中断结束后重新激活会话。真正的动作都在下面这段 JS。
    //
    // 【关键 bug 修复】旧实现在这里无条件 return，导致：
    //   其它 App 独占激活 → 系统中断我们 → 会话被 deactivate（底层停了）
    //   → 中断结束的 remote-duck(paused:false) 也被忽略 → 会话永远不再激活 → 没声音，
    //   只能手动关开「与其他应用同时播放」触发 applyAudioMix 才恢复。
    // 现改为：中断开始时仍忽略（保持混音、不暂停）；中断「结束且可恢复」时重新激活会话并续播。
    if (settingState.setting['player.isPlayWithOtherApps']) {
      // ducking（被临时压低音量）或中断开始：保持混音，不暂停、不改动会话
      if (ducking || paused || permanent) return
      // 到这里是 paused:false 且非 ducking —— 中断结束、系统允许恢复。
      // 只有我们本就在播放才需要恢复，避免把用户主动暂停的 state 拉起来。
      if (!playerState.isPlay) return
      void (async() => {
        // 重新 setCategory + setActive，恢复被 deactivate 的会话
        await applyAudioMix(true)
        // 幂等：已是 Playing 时 play() 无副作用（play 返回 void）
        play()
      })()
      return
    }

    // On iOS, interruptions surface through RemoteDuck and we need to explicitly
    // restore playback/volume after the system finishes ducking or pausing audio.
    if (permanent) {
      shouldResumeAfterDuck = false
      clearDuckRecoveryTimeouts()
      if (paused) void pause()
      return
    }

    if (ducking) {
      shouldResumeAfterDuck ||= playerState.isPlay
      clearDuckRecoveryTimeouts()
      return
    }

    if (paused) {
      shouldResumeAfterDuck = playerState.isPlay
      clearDuckRecoveryTimeouts()
      void pause()
      return
    }

    if (Platform.OS == 'ios' || ducking === false) restoreConfiguredVolume()

    if (shouldResumeAfterDuck) {
      shouldResumeAfterDuck = false
      play()
    }
  })

  TrackPlayer.addEventListener(TPEvent.RemoteSeek, async({ position }) => {
    markTimeoutExitInteraction()
    global.app_event.setProgress(position as number)
  })
  isInitialized = true
}


export default () => {
  if (global.lx.playerStatus.isRegisteredService) return
  console.log('handle registerPlaybackService...')
  TrackPlayer.registerPlaybackService(() => registerPlaybackService)
  global.lx.playerStatus.isRegisteredService = true
}
