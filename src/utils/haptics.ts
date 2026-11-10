import { NativeModules, Platform } from 'react-native'

/**
 * 全局触感反馈（Taptic Engine）。
 * 走原生 `LXHaptics` 模块；非 iOS 或模块不可用时安全忽略。
 */
const Haptics = NativeModules.LXHaptics

export type HapticImpact = 'light' | 'medium' | 'heavy' | 'soft' | 'rigid'
export type HapticNotification = 'success' | 'warning' | 'error'

/** 轻/中/重 冲击反馈 */
export const hapticImpact = (style: HapticImpact = 'light') => {
  if (Platform.OS != 'ios') return
  Haptics?.impact?.(style)
}

/** 成功/警告/错误 通知反馈 */
export const hapticNotification = (type: HapticNotification = 'success') => {
  if (Platform.OS != 'ios') return
  Haptics?.notification?.(type)
}

/** 选择变化反馈（滑动、切换选项） */
export const hapticSelection = () => {
  if (Platform.OS != 'ios') return
  Haptics?.selection?.()
}

/** 常用语义化封装：播放页各处统一用这些，保证手感一致 */
export const haptic = {
  /** 播放/暂停：轻触 */
  playToggle: () => { hapticImpact('light') },
  /** 切歌：中等冲击 */
  trackChange: () => { hapticImpact('medium') },
  /** 收藏成功：成功通知 */
  favorite: () => { hapticNotification('success') },
  /** 取消收藏：轻触 */
  unfavorite: () => { hapticImpact('light') },
  /** 普通按钮点击 */
  tap: () => { hapticImpact('light') },
  /** 选项切换（音源/音质/播放模式） */
  select: () => { hapticSelection() },
  /** 长按进入悬浮/弹出菜单 */
  longPress: () => { hapticImpact('medium') },
  /** 进度条拖动到新位置 */
  seek: () => { hapticSelection() },
}
