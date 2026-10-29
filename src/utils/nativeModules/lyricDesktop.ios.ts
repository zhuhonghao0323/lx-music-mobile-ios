/**
 * 桌面歌词 —— iOS 占位实现
 *
 * Android 的「桌面歌词」是一个 TYPE_APPLICATION_OVERLAY 悬浮窗（LyricView + LyricPlayer），
 * iOS 沙盒不允许 App 在其他应用之上绘制窗口，系统层面没有对应能力，
 * 也没有越狱依赖之外的合法替代方案。因此这个模块在 iOS 上整体降级为空实现。
 *
 * 与之配套的改动：
 *   - 设置页的「桌面歌词」入口在 iOS 上隐藏（见 Setting 相关页面）
 *   - 所有调用点保持原有调用方式，不需要判断平台，避免散落的 Platform.OS 分支
 */

export const setSendLyricTextEvent = async(_isSend: boolean) => {}

export const showDesktopLyricView = async(_options: any): Promise<void> => {}

export const hideDesktopLyricView = async(): Promise<void> => {}

export const play = async(_time: number): Promise<void> => {}

export const pause = async(): Promise<void> => {}

export const setLyric = async(_lyric: string, _translation: string, _romalrc: string): Promise<void> => {}

export const setPlaybackRate = async(_rate: number): Promise<void> => {}

export const toggleTranslation = async(_isShowTranslation: boolean): Promise<void> => {}

export const toggleRoma = async(_isShowRoma: boolean): Promise<void> => {}

export const toggleLock = async(_isLock: boolean): Promise<void> => {}

export const setColor = async(_unplayColor: string, _playedColor: string, _shadowColor: string): Promise<void> => {}

export const setAlpha = async(_alpha: number): Promise<void> => {}

export const setTextSize = async(_size: number): Promise<void> => {}

export const setShowToggleAnima = async(_isShowToggleAnima: boolean): Promise<void> => {}

export const setSingleLine = async(_isSingleLine: boolean): Promise<void> => {}

export const setPosition = async(_x: number, _y: number): Promise<void> => {}

export const setMaxLineNum = async(_maxLineNum: number): Promise<void> => {}

export const setWidth = async(_width: number): Promise<void> => {}

export const setLyricTextPosition = async(_textX: any, _textY: any): Promise<void> => {}

/// iOS 没有悬浮窗权限的概念，恒视为「已授权」，避免 UI 卡在授权引导上
export const checkOverlayPermission = async(): Promise<void> => {}

export const openOverlayPermissionActivity = async(): Promise<void> => {}

export const onPositionChange = (_handler: (position: { x: number, y: number }) => void): () => void => {
  return () => {}
}

export const onLyricLinePlay = (_handler: (lineInfo: { text: string, extendedLyrics: string[] }) => void): () => void => {
  return () => {}
}
