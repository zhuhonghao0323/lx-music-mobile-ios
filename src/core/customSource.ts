/**
 * 自定义音源顺序与自动切换。
 *
 * 说明：
 * - 「音源」在这里指的是用户导入的自定义源（user_api_* 脚本），不是内置的
 *   kw/kg/tx/wy/mg。自定义源列表（state.list）的**顺序就是优先级**：
 *   第一个是默认音源，切歌都从它开始；某个源解析/播放失败时自动切到下一个。
 * - 顺序直接复用 userApi 列表顺序持久化（saveUserApiOrder），不新增设置项。
 */
import { state as userApiState } from '@/store/userApi'
import { setUserApiList } from '@/core/userApi'
import { saveUserApiOrder } from '@/utils/data'
import settingState from '@/store/setting/state'

/** 当前生效的自定义源 id 列表（按优先级） */
export const getCustomSourceIds = (): string[] => userApiState.list.map(item => item.id)

/** 默认音源 = 排序第一个 */
export const getDefaultCustomSourceId = (): string | null => getCustomSourceIds()[0] ?? null

/** 当前音源是否为自定义源 */
export const isCustomSource = (id: string): boolean => /^user_api/.test(id)

/** 当前正在使用的音源 id */
export const getCurrentSourceId = (): string => settingState.setting['common.apiSource']

/** 当前音源的显示名（自定义源用脚本名，内置源用 id） */
export const getSourceDisplayName = (id: string): string => {
  const custom = userApiState.list.find(item => item.id == id)
  return custom?.name ?? id
}

/**
 * 取当前音源之后的下一个自定义源 id（循环回第一个）。
 * 用于播放失败自动切换；没有自定义源或只有一个时返回 null。
 */
export const getNextCustomSourceId = (currentId: string): string | null => {
  const ids = getCustomSourceIds()
  if (ids.length < 2) return null
  const index = ids.indexOf(currentId)
  // 当前不在列表里（比如当前是内置源）→ 从第一个自定义源开始
  if (index < 0) return ids[0]
  return ids[(index + 1) % ids.length]
}

/**
 * 把自定义源列表按给定 id 顺序重排（拖拽排序用）并持久化。
 * 未出现在 order 里的项按原顺序追加到末尾。
 * 返回重排后的 id 顺序。
 */
export const reorderCustomSources = async(orderedIds: string[]): Promise<string[]> => {
  const rank = new Map(orderedIds.map((id, index) => [id, index]))
  const next = [...userApiState.list].sort((a, b) => {
    const ra = rank.get(a.id) ?? Number.MAX_SAFE_INTEGER
    const rb = rank.get(b.id) ?? Number.MAX_SAFE_INTEGER
    return ra - rb
  })
  const ids = next.map(item => item.id)
  // 先落盘，再更新内存/UI，保证顺序在重启后依然有效
  await saveUserApiOrder(ids)
  setUserApiList(next)
  return ids
}
