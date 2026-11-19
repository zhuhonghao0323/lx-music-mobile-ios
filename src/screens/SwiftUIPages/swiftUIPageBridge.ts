import { NativeEventEmitter, NativeModules, Platform, requireNativeComponent, type ViewProps } from 'react-native'

/**
 * 通用 SwiftUI 页面桥（iOS）。
 * 与播放页桥接同构：JS 推状态 → SwiftUI 渲染；SwiftUI 操作 → 命令回传 JS。
 * 业务逻辑始终留在 RN，SwiftUI 只负责呈现。
 */
const Module = NativeModules.LXSwiftUIPageModule as {
  updatePageState?: (payload: { pageId: string, state: Record<string, unknown> }) => void
} | undefined

export const isSwiftUIPageSupported = Platform.OS == 'ios' && !!Module

export const NativeMineView = isSwiftUIPageSupported
  ? requireNativeComponent<ViewProps>('LXSwiftUIMineView')
  : null

let emitter: NativeEventEmitter | null = null
const getEmitter = () => {
  if (!isSwiftUIPageSupported) return null
  if (!emitter) emitter = new NativeEventEmitter(Module as never)
  return emitter
}

export const updatePageState = (pageId: string, state: Record<string, unknown>) => {
  Module?.updatePageState?.({ pageId, state })
}

export type PageCommand = 'openSetting' | 'createList' | 'openList' | 'listOp'

export const onPageCommand = (
  handler: (pageId: string, command: PageCommand, payload: Record<string, unknown>) => void,
): (() => void) => {
  const e = getEmitter()
  if (!e) return () => {}
  const sub = e.addListener('lx-swiftui-page-command', (evt: { pageId: string, command: string, payload?: Record<string, unknown> }) => {
    handler(evt.pageId, evt.command as PageCommand, evt.payload ?? {})
  })
  return () => { sub.remove() }
}
