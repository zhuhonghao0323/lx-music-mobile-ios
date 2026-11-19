import { NativeEventEmitter, NativeModules, Platform, UIManager, requireNativeComponent, type ViewProps } from 'react-native'

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

/**
 * 检测原生 ViewManager 是否已注册。
 *
 * 注意：RCT_EXPORT_MODULE(LXSwiftUIPlayerView) 注册的是「组件名」，
 * ViewManager 类本身不会出现在 NativeModules 里，所以不能用
 * NativeModules.LXSwiftUIPlayerViewManager 判断——那样永远为 undefined，
 * 会导致 SwiftUI 播放页永远启不了、一直显示老版 RN 页面。
 * 正确方式是通过 UIManager 查询组件配置。
 */
const hasViewManager = (name: string) => {
  try {
    return !!UIManager.getViewManagerConfig?.(name)
  } catch {
    return false
  }
}

/**
 * 是否支持 SwiftUI 播放页。
 * 惰性求值：不能在建模块时就定死，因为原生组件注册可能晚于 JS 模块加载。
 */
export const isSwiftUIPlayerSupported = (): boolean => {
  // iOS 上直接启用（不再依赖运行时检测）：
  // 之前依赖 UIManager / NativeModules 探测，一旦探测失败就静默退回 RN 老页面，
  // 导致 SwiftUI 实现永远不生效且难以定位。原生组件已确认编译进包，
  // 这里让 iOS 无条件走 SwiftUI，若组件真的缺失 render 会报错而不是静默降级。
  return Platform.OS === 'ios'
}

let cachedPlayerView: React.ComponentType<ViewProps> | null | undefined
/** 供 JS 渲染的原生视图（惰性创建，避免模块加载时组件尚未注册） */
export const getSwiftUIPlayerView = () => {
  if (cachedPlayerView !== undefined) return cachedPlayerView
  try {
    cachedPlayerView = requireNativeComponent<ViewProps>('LXSwiftUIPlayerView')
  } catch (e) {
    console.log('[SwiftUIPlayer] requireNativeComponent failed', e)
    cachedPlayerView = null
  }
  return cachedPlayerView
}

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
  | 'goHome'
  | 'goMine'

let emitter: NativeEventEmitter | null = null
const getEmitter = () => {
  if (Platform.OS !== 'ios') return null
  if (!NativeModules.LXSwiftUIPlayerModule) return null
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
