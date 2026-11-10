import { NativeEventEmitter, NativeModules, Platform, requireNativeComponent, type ViewProps } from 'react-native'

/**
 * SwiftUI 播放页桥接（仅 iOS）。
 *
 * 设计边界：JS 只负责「把状态推下去」和「接住 SwiftUI 上来的操作」，
 * 真正的播放/收藏/音源/主题逻辑仍然复用 RN 现有的实现，
 * 这样 SwiftUI 版播放页与 RN 版行为完全一致。
 */

const Module = NativeModules.LXSwiftUIPlayerModule as {
  updateState?: (state: Record<string, unknown>) => void
} | undefined

const ViewManager = NativeModules.LXSwiftUIPlayerViewManager

/** 当前平台是否支持 SwiftUI 播放页 */
export const isSwiftUIPlayerSupported = Platform.OS == 'ios' && !!Module && !!ViewManager

/** 供 JS 渲染的原生视图（内部是 UIHostingController 承载的 SwiftUI 页面） */
export const SwiftUIPlayerView = isSwiftUIPlayerSupported
  ? requireNativeComponent<ViewProps>('LXSwiftUIPlayerView')
  : null

export type SwiftUIPlayerCommand =
  | 'back'
  | 'prev'
  | 'next'
  | 'togglePlay'
  | 'seek'
  | 'toggleFavorite'
  | 'openFavoriteListPicker'
  | 'openSourcePicker'
  | 'openQualityPicker'
  | 'selectSource'
  | 'selectQuality'
  | 'openComment'
  | 'togglePlayMode'
  | 'openSetting'

let emitter: NativeEventEmitter | null = null
const getEmitter = () => {
  if (!isSwiftUIPlayerSupported) return null
  if (!emitter) emitter = new NativeEventEmitter(Module as never)
  return emitter
}

/** 把当前播放状态推给 SwiftUI */
export const updateSwiftUIPlayerState = (state: Record<string, unknown>) => {
  Module?.updateState?.(state)
}

/** 订阅 SwiftUI 上来的操作 */
export const onSwiftUIPlayerCommand = (
  handler: (command: SwiftUIPlayerCommand, payload: Record<string, unknown>) => void,
): (() => void) => {
  const e = getEmitter()
  if (!e) return () => {}
  const sub = e.addListener('lx-swiftui-player-command', (event: { command: string, payload?: Record<string, unknown> }) => {
    handler(event.command as SwiftUIPlayerCommand, event.payload ?? {})
  })
  return () => { sub.remove() }
}
