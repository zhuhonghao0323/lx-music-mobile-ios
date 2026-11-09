import settingState from '@/store/setting/state'

/** 所有可用的在线音源（与 musicSdk/index.js 的 sources.sources 保持一致） */
export const ALL_SOURCES = ['kw', 'kg', 'tx', 'wy', 'mg'] as const
export type OnlineSourceId = typeof ALL_SOURCES[number]

export const SOURCE_NAMES: Record<OnlineSourceId, string> = {
  kw: '酷我音乐',
  kg: '酷狗音乐',
  tx: 'QQ音乐',
  wy: '网易音乐',
  mg: '咪咕音乐',
}

/** 默认优先级：与内置 sources 顺序一致 */
export const DEFAULT_SOURCE_PRIORITY: string[] = [...ALL_SOURCES]

/**
 * 读取当前生效的音源优先级（已排序、只保留启用且合法的音源）。
 * 顺序即自动切换的尝试顺序；第一个即每次切歌开始尝试的音源。
 */
export const getSourcePriority = (): string[] => {
  const configured = settingState.setting['player.sourcePriority']
  const enabled = settingState.setting['player.enabledSources']
  const enabledSet = new Set<string>(enabled)
  const order = Array.isArray(configured) && configured.length ? configured : DEFAULT_SOURCE_PRIORITY
  const result: string[] = []
  for (const id of order) {
    if (!ALL_SOURCES.includes(id as OnlineSourceId)) continue
    if (!enabledSet.has(id)) continue
    if (result.includes(id)) continue
    result.push(id)
  }
  // 配置里没列到的启用音源追加到末尾
  for (const id of ALL_SOURCES) {
    if (enabledSet.has(id) && !result.includes(id)) result.push(id)
  }
  return result
}

/** 是否启用了至少一个音源 */
export const hasEnabledSource = () => getSourcePriority().length > 0
