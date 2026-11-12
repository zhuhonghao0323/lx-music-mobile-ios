import { version } from '../../package.json'
import { createAppEventHub } from '@/event/appEvent'
import { createListEventHub } from '@/event/listEvent'
import { createDislikeEventHub } from '@/event/dislikeEvent'
import { createStateEventHub } from '@/event/stateEvent'
if (process.versions == null) {
  // @ts-expect-error
  process.versions = {
    app: version,
  }
} else process.versions.app = version

// global.i18n = null

// let screenW = Dimensions.get('window').width
// let screenH = Dimensions.get('window').height
// if (screenW > screenH) {
//   const temp = screenW
//   screenW = screenH
//   screenH = temp
// }


global.lx = {
  fontSize: 1,
  playerStatus: {
    isInitialized: false,
    isRegisteredService: false,
    isIniting: false,
    ignoreTrackPlayerLifecycle: false,
  },

  restorePlayInfo: null,
  // allList: null,
  // globalObj: null,
  // listScrollPosition: {},
  // listSort: {},

  isScreenKeepAwake: false,

  // 是否播放完后退出应用
  isPlayedStop: false,

  /**
   * 用户主动暂停的意图标记。
   *
   * 混音模式（与其他应用同时播放）下有一个「底层停了自动恢复」的守护，
   * 但用户主动点暂停时底层会先变 Paused 而 UI 状态尚未更新，
   * 守护会把它误恢复。此标记在 pause/stop 时置 true，play 时清掉，
   * 守护看到它就不会恢复，保证暂停键始终有效。
   */
  isUserPauseIntent: false,

  // prevListPlayIndex: -1,

  // syncKeyInfo: {},

  isEnableSyncLog: false,
  isEnableUserApiLog: false,

  playerTrackId: '',

  gettingUrlId: '',

  qualityList: {},
  apis: {},
  apiInitPromise: [Promise.resolve(false), true, () => {}],

  jumpMyListPosition: false,

  settingActiveId: 'basic',

  homePagerIdle: true,

  // syncKeyInfo: initValue as LX.Sync.KeyInfo,

  // windowInfo: {
  //   screenW,
  //   screenH,
  //   fontScale: PixelRatio.getFontScale(),
  //   pixelRatio: PixelRatio.get(),
  //   screenPxW: PixelRatio.getPixelSizeForLayoutSize(screenW),
  //   screenPxH: PixelRatio.getPixelSizeForLayoutSize(screenH),
  // },
}

global.app_event = createAppEventHub()
global.list_event = createListEventHub()
global.dislike_event = createDislikeEventHub()
global.state_event = createStateEventHub()
