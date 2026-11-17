/**
 * 锁屏/控制中心媒体控件显隐标志（轻量模块，无依赖，避免循环引用）。
 *
 * 「与其他应用同时播放」（混音）模式下隐藏控件：
 * - 用户不希望混音时出现不可用的锁屏控件
 * - 后台音频由 AVAudioSession Playback + MixWithOthers 维持，
 *   与是否显示锁屏控件无关
 */
let hidden = false

export const setNowPlayingHidden = (value: boolean) => { hidden = value }
export const isNowPlayingHidden = () => hidden
