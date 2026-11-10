import { memo, useEffect, useMemo, useRef } from 'react'
import { View, StyleSheet } from 'react-native'
import {
  SwiftUIPlayerView,
  updateSwiftUIPlayerState,
  onSwiftUIPlayerCommand,
  type SwiftUIPlayerCommand,
} from './swiftUIPlayerBridge'
import { usePlayerMusicInfo, useIsPlay, useProgress } from '@/store/player/hook'
import { useIsMusicFavorited } from '@/store/list/hook'
import { useSettingValue } from '@/store/setting/hook'
import { useTheme } from '@/store/theme/hook'
import { useLrcPlay, useLrcSet } from '@/plugins/lyric'
import { useCurrentPlayQuality, formatQuality } from '@/store/player/quality'
import { getPlayMusicInfo, toggleFavorite } from '@/core/favorite'
import { playNext, playPrev, togglePlay } from '@/core/player/player'
import { getSourceDisplayName } from '@/core/customSource'
import { useUserApiList } from '@/store/userApi'
import playerState from '@/store/player/state'
import { pop } from '@/navigation'
import commonState from '@/store/common/state'
import { markTimeoutExitInteraction } from '@/core/player/timeoutExit'

const LYRIC_COLORS: Record<string, string> = {
  white: '#ffffff',
  blue: '#7fc4ff',
  pink: '#ff8fb1',
  green: '#7ee8a2',
}

/**
 * SwiftUI 播放页容器（RN 侧）：
 * - 把 RN 的播放状态持续推给 SwiftUI
 * - 接住 SwiftUI 上来的操作，复用现有 RN 逻辑执行
 * 开关关闭时不会走到这里，仍然用原来的 RN 播放页。
 */
export default memo(() => {
  const musicInfo = usePlayerMusicInfo()
  const isPlay = useIsPlay()
  const { progress, nowPlayTimeStr, maxPlayTimeStr, nowPlayTime, maxPlayTime } = useProgress()
  const favorited = useIsMusicFavorited(getPlayMusicInfo())
  const theme = useTheme()
  const lyricLines = useLrcSet()
  const { line: currentLine } = useLrcPlay()
  const quality = useCurrentPlayQuality()
  const playQuality = useSettingValue('player.playQuality')
  const apiSource = useSettingValue('common.apiSource')
  const userApiList = useUserApiList()
  const lyricColorKey = useSettingValue('theme.lyricPreviewColor')
  const lyricFontSize = useSettingValue('theme.lyricPreviewFontSize')

  const getLyric = (index: number) => lyricLines[index]?.text?.trim() ?? ''

  // 把状态推给 SwiftUI；高频字段（进度）也一并推送，SwiftUI 侧仅做渲染
  const state = useMemo(() => ({
    title: musicInfo.name ?? '',
    artist: musicInfo.singer ?? '',
    picUrl: musicInfo.pic ?? '',
    isPlaying: isPlay,
    favorited,

    currentTime: nowPlayTime,
    duration: maxPlayTime,
    progress: progress ?? 0,
    buffered: 0,
    currentTimeText: nowPlayTimeStr,
    durationText: maxPlayTimeStr,

    lyricPrev: currentLine > 0 ? getLyric(currentLine - 1) : '',
    lyricCurrent: getLyric(currentLine),
    lyricNext: getLyric(currentLine + 1),

    sourceName: userApiList.length ? getSourceDisplayName(apiSource) : '',
    qualityText: formatQuality(quality ?? playQuality),

    backgroundColor: theme['c-app-background'],
    cardColor: theme['c-content-background'],
    primaryColor: theme['c-primary-font'],
    fontColor: theme['c-font'],
    fontLabelColor: theme['c-font-label'],
    isDark: theme.isDark,

    lyricColor: LYRIC_COLORS[lyricColorKey] ?? theme['c-primary-font'],
    lyricFontSize,
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }), [
    musicInfo.name, musicInfo.singer, musicInfo.pic, isPlay, favorited,
    nowPlayTimeStr, maxPlayTimeStr, progress, currentLine, lyricLines,
    userApiList, apiSource, quality, playQuality, theme, lyricColorKey, lyricFontSize,
  ])

  useEffect(() => {
    updateSwiftUIPlayerState(state)
  }, [state])

  // 接住 SwiftUI 上的操作，交给现有 RN 逻辑
  const stateRef = useRef(state)
  stateRef.current = state

  useEffect(() => {
    return onSwiftUIPlayerCommand((command: SwiftUIPlayerCommand, payload) => {
      switch (command) {
        case 'back':
          void pop(commonState.componentIds.playDetail!)
          break
        case 'prev':
          markTimeoutExitInteraction()
          void playPrev()
          break
        case 'next':
          markTimeoutExitInteraction()
          void playNext()
          break
        case 'togglePlay':
          markTimeoutExitInteraction()
          togglePlay()
          break
        case 'seek': {
          const ratio = Number(payload.ratio ?? 0)
          const info = playerState.playMusicInfo.musicInfo
          if (!info) break
          const target = Math.max(0, Math.min(1, ratio)) * (stateRef.current.duration / 1000)
          global.app_event.setProgress(target)
          break
        }
        case 'toggleFavorite': {
          const info = getPlayMusicInfo()
          if (info) void toggleFavorite(info)
          break
        }
        case 'openSourcePicker':
        case 'openQualityPicker':
        case 'openFavoriteListPicker':
        case 'openComment':
        case 'togglePlayMode':
        case 'openSetting':
          // 这些需要弹窗/二级页，暂由 RN 原页面承接，这里先留空不打断播放
          break
        default:
          break
      }
    })
  }, [])

  if (!SwiftUIPlayerView) return null

  return (
    <View style={styles.container}>
      <SwiftUIPlayerView style={styles.view} />
    </View>
  )
})

const styles = StyleSheet.create({
  container: { flex: 1 },
  view: { flex: 1 },
})
