import { useCallback } from 'react'
import { toast } from '@/utils/tools'
import { MUSIC_TOGGLE_MODE_LIST, MUSIC_TOGGLE_MODE } from '@/config/constant'
import settingState from '@/store/setting/state'
import { useI18n } from '@/lang'
import { updateSetting } from '@/core/common'

/**
 * 轮换播放模式（列表循环 → 随机 → 顺序 → 单曲循环 …）。
 * 抽成 hook 是因为播放页和「更多」菜单都要用同一套逻辑。
 */
export const useTogglePlayMode = () => {
  const t = useI18n()
  return useCallback(() => {
    const cur = settingState.setting['player.togglePlayMethod']
    let index = MUSIC_TOGGLE_MODE_LIST.indexOf(cur)
    if (++index >= MUSIC_TOGGLE_MODE_LIST.length) index = 0
    const mode = MUSIC_TOGGLE_MODE_LIST[index]
    updateSetting({ 'player.togglePlayMethod': mode })

    let modeName: 'play_list_loop' | 'play_list_random' | 'play_list_order' | 'play_single_loop' | 'play_single'
    switch (mode) {
      case MUSIC_TOGGLE_MODE.listLoop: modeName = 'play_list_loop'; break
      case MUSIC_TOGGLE_MODE.random: modeName = 'play_list_random'; break
      case MUSIC_TOGGLE_MODE.list: modeName = 'play_list_order'; break
      case MUSIC_TOGGLE_MODE.singleLoop: modeName = 'play_single_loop'; break
      default: modeName = 'play_single'; break
    }
    toast(t(modeName))
  }, [t])
}
