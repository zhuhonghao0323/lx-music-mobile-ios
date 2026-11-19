const defaultSetting: LX.AppSetting = {
  version: '2.1',
  'common.isAutoTheme': false,
  'common.langId': null,
  'common.apiSource': '',
  'common.userApiAutoUpdateEnabled': true,
  'common.sourceNameType': 'alias',
  'common.shareType': 'system',
  'common.isAgreePact': false,
  'common.autoHidePlayBar': true,
  'common.drawerLayoutPosition': 'left',
  'common.homePageScroll': true,
  'common.allowProgressBarSeek': true,
  'common.showBackBtn': false,
  'common.showExitBtn': true,
  'common.useSystemFileSelector': true,
  'common.alwaysKeepStatusbarHeight': false,

  'player.startupAutoPlay': false,
  'player.startupPushPlayDetailScreen': false,
  'player.togglePlayMethod': 'listLoop',
  'player.playQuality': '128k',
  'player.isSavePlayTime': false,
  'player.volume': 1,
  'player.playbackRate': 1,
  'player.cacheSize': '1024',
  'player.timeoutExit': '',
  'player.timeoutExitCustomMinutes': '',
  'player.timeoutExitTimerType': 'preset',
  'player.timeoutExitPlayed': true,
  'player.isAutoCleanPlayedList': false,
  'player.isHandleAudioFocus': true,
  'player.isEnableAudioOffload': false,
  'player.isPlayWithOtherApps': false,
  'player.isPlayWithOtherAppsTipDisabled': false,
  // SwiftUI 播放页开关：默认关闭，关闭时使用原有 RN 播放页
  'player.useSwiftUIPlayer': false,
  // 播放页封面下方三行歌词预览的外观
  'theme.lyricPreviewColor': 'white',
  'theme.lyricPreviewFontSize': 15,
  'player.isShowLyricTranslation': false,
  'player.isShowLyricRoma': false,
  'player.isShowNotificationImage': true,
  'player.isS2t': false,
  'player.isShowBluetoothLyric': false,
  'player.soundEffect.enabled': false,
  'player.soundEffect.preset': 'none',
  'player.soundEffect.eq.31': 0,
  'player.soundEffect.eq.62': 0,
  'player.soundEffect.eq.125': 0,
  'player.soundEffect.eq.250': 0,
  'player.soundEffect.eq.500': 0,
  'player.soundEffect.eq.1000': 0,
  'player.soundEffect.eq.2000': 0,
  'player.soundEffect.eq.4000': 0,
  'player.soundEffect.eq.8000': 0,
  'player.soundEffect.eq.16000': 0,
  'player.soundEffect.convolution.fileName': '',
  'player.soundEffect.convolution.mainGain': 10,
  'player.soundEffect.convolution.sendGain': 0,
  'player.soundEffect.panner.enable': false,
  'player.soundEffect.panner.soundR': 5,
  'player.soundEffect.panner.speed': 25,
  'player.soundEffect.pitchShifter.playbackRate': 1,

  // 'playDetail.isZoomActiveLrc': false,
  // 'playDetail.isShowLyricProgressSetting': false,
  'playDetail.style.align': 'left',
  'playDetail.vertical.style.lrcFontSize': 210,
  'playDetail.horizontal.style.lrcFontSize': 220,
  'playDetail.isShowLyricProgressSetting': false,

  'desktopLyric.enable': false,
  'desktopLyric.isLock': false,
  'desktopLyric.width': 100,
  'desktopLyric.maxLineNum': 5,
  'desktopLyric.isSingleLine': false,
  'desktopLyric.showToggleAnima': true,
  'desktopLyric.position.x': 0,
  'desktopLyric.position.y': 0,
  'desktopLyric.textPosition.x': 'left',
  'desktopLyric.textPosition.y': 'top',
  'desktopLyric.style.fontSize': 180,
  'desktopLyric.style.opacity': 100,
  'desktopLyric.style.lyricUnplayColor': 'rgba(255, 255, 255, 1)',
  'desktopLyric.style.lyricPlayedColor': 'rgba(7, 197, 86, 1)',
  'desktopLyric.style.lyricShadowColor': 'rgba(0, 0, 0, 0.6)',

  'search.isShowHotSearch': false,
  'search.isShowHistorySearch': false,

  'list.isClickPlayList': false,
  'list.isShowSource': true,
  'list.isShowAlbumName': false,
  'list.isShowInterval': true,
  'list.isSaveScrollLocation': true,
  'list.addMusicLocationType': 'top',

  'download.fileName': '歌名 - 歌手',

  'sync.enable': false,

  // 全局默认主题：液态玻璃（深色）。浅色/深色模式分别映射。
  'theme.id': 'liquid_glass',
  'theme.lightId': 'liquid_glass_light',
  'theme.darkId': 'liquid_glass',
  'theme.hideBgDark': false,
  'theme.dynamicBg': false,
  'theme.fontShadow': false,
}

// 主题迁移：旧皮肤（green/black/happy_new_year 等 16 个）已在 v1.9.1 移除，
// 若用户设备上还存有旧主题 id，回退到液态玻璃主题。
const LEGACY_THEME_IDS = new Set([
  'green', 'blue', 'blue_plus', 'orange', 'brown', 'red', 'pink', 'purple',
  'grey', 'ming', 'blue2', 'black', 'mid_autumn', 'naruto', 'china_ink', 'happy_new_year',
])
for (const key of ['theme.id', 'theme.lightId', 'theme.darkId'] as const) {
  if (LEGACY_THEME_IDS.has(defaultSetting[key])) {
    defaultSetting[key] = key == 'theme.lightId' ? 'liquid_glass_light' : 'liquid_glass'
  }
}

export default defaultSetting
