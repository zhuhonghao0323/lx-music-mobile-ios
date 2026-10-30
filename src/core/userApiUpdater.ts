/**
 * 在线音源（URL 导入的自定义音源脚本）版本检查与更新
 *
 * 设计要点：
 * - 只对比脚本头部注释里的 @version 语义化版本号，不用 hash。
 *   远端版本 > 本地版本才算有更新；≤ 直接跳过。
 * - 没有 sourceUrl（本地文件导入）或版本号不合法的音源，全部跳过。
 * - 更新本质是「静默重新执行一次 URL 在线导入」：拉取 → 解析 → 覆盖脚本 → 重新初始化，
 *   校验规则与手动导入完全一致。
 * - 失败一律静默回滚到旧脚本，不影响播放、不弹错误。
 */

import { compareVer } from '@/utils'
import { getUserApiScript, parseUserApiScriptInfo, updateUserApiInfo, updateUserApiScript } from '@/utils/data'
import { action, state as userApiState } from '@/store/userApi'
import { httpFetch } from '@/utils/request'
import settingState from '@/store/setting/state'
import { log, setUserApi } from './userApi'

export type UpdateStatus =
  /** 已更新到新版本 */
  | 'updated'
  /** 远端版本不高于本地 */
  | 'latest'
  /** 不满足更新条件（无 sourceUrl / 版本不合法 / 用户改过脚本） */
  | 'skipped'
  /** 拉取、解析或初始化失败，已回滚 */
  | 'failed'

export interface UpdateCheckResult {
  status: UpdateStatus
  fromVersion?: string
  toVersion?: string
  error?: string
}

/** 脚本体积上限，与在线导入保持一致 */
const MAX_SCRIPT_SIZE = 9_000_000
/** 等待音源重新初始化结果的上限 */
const INIT_TIMEOUT = 15_000

/** 版本号是否可用于比较：必须以数字开头（排除空串、`beta` 之类） */
const isComparableVersion = (version?: string): version is string => !!version && /^\d/.test(version)

const fetchRemoteScript = async(url: string): Promise<string> => {
  const resp = await httpFetch(url).promise
  const body = resp.body
  if (typeof body != 'string') throw new Error('invalid response body')
  if (body.length > MAX_SCRIPT_SIZE) throw new Error('script too large')
  return body
}

/**
 * 如果这个音源正被使用，重新加载它并等待初始化结果。
 * 非当前音源直接返回 true（不需要重载）。
 */
const reloadIfActive = async(id: string): Promise<boolean> => {
  if (settingState.setting['common.apiSource'] !== id) return true
  // 已有一次初始化在进行中，避免覆盖全局 promise
  if (!global.lx.apiInitPromise[1]) return true

  global.lx.apiInitPromise[0] = new Promise<boolean>(resolve => {
    global.lx.apiInitPromise[1] = false
    global.lx.apiInitPromise[2] = (result: boolean) => {
      global.lx.apiInitPromise[1] = true
      resolve(result)
    }
  })
  await setUserApi(id)

  const timeout = new Promise<boolean>(resolve => {
    setTimeout(() => { resolve(false) }, INIT_TIMEOUT)
  })
  return Promise.race([global.lx.apiInitPromise[0], timeout])
}

/**
 * 用远端脚本覆盖本地音源，失败则回滚。
 * 调用前已确认「远端版本 > 本地版本」。
 */
const applyUpdate = async(
  info: LX.UserApi.UserApiInfo,
  script: string,
  parsed: Record<string, string>,
): Promise<UpdateCheckResult> => {
  const fromVersion = info.version
  const oldScript = await getUserApiScript(info.id)
  const oldInfo = { ...info }

  try {
    // 先落脚本，再落元数据
    await updateUserApiScript(info.id, script)
    const newInfo: LX.UserApi.UserApiInfo = {
      ...info,
      // 只覆盖脚本头部能提供的描述字段，用户配置与来源信息保持不变
      name: parsed.name || info.name,
      description: parsed.description || info.description,
      author: parsed.author || info.author,
      homepage: parsed.homepage || info.homepage,
      version: parsed.version,
      lastCheckTime: Date.now(),
      // 更新成功后，脚本已与远端一致，不再是「用户改过的版本」
      userModified: false,
    }
    await updateUserApiInfo(info.id, newInfo)
    action.updateUserApi(newInfo)

    const inited = await reloadIfActive(info.id)
    if (!inited) throw new Error('init failed')

    log.r_info(`[userApi] 更新成功: ${info.name} ${fromVersion} -> ${parsed.version}`)
    return { status: 'updated', fromVersion, toVersion: parsed.version }
  } catch (error: any) {
    // 回滚：脚本、元数据、运行中的实例全部恢复到更新前
    await updateUserApiScript(info.id, oldScript).catch(() => {})
    await updateUserApiInfo(info.id, oldInfo).catch(() => {})
    action.updateUserApi(oldInfo)
    await reloadIfActive(info.id).catch(() => {})
    log.r_warn(`[userApi] 更新失败已回滚: ${info.name} ${error?.message ?? ''}`)
    return { status: 'failed', error: error?.message }
  }
}

/**
 * 检查并更新单个音源。
 * @param info 目标音源
 * @param options.force 手动触发时为 true：忽略 autoUpdate 开关与 userModified 保护
 */
export const checkUserApiUpdate = async(
  info: LX.UserApi.UserApiInfo,
  options: { force?: boolean } = {},
): Promise<UpdateCheckResult> => {
  // 只有 URL 导入的音源才支持更新
  if (!info.sourceUrl) return { status: 'skipped' }
  // 用户手动改过脚本，自动更新不静默覆盖（手动触发时允许，由调用方二次确认）
  if (info.userModified && !options.force) return { status: 'skipped' }
  // 本地版本不合法 → 无法判断，跳过
  if (!isComparableVersion(info.version)) return { status: 'skipped' }

  let script: string
  try {
    script = await fetchRemoteScript(info.sourceUrl)
  } catch (error: any) {
    return { status: 'failed', error: error?.message }
  }

  const parsed = parseUserApiScriptInfo(script)
  // 远端脚本没有头部信息或没有版本号 → 不具备更新条件
  if (!parsed || !isComparableVersion(parsed.version)) return { status: 'skipped' }

  // compareVer(本地, 远端) === -1 表示本地更低，即远端有更新
  if (compareVer(info.version, parsed.version) !== -1) {
    // 顺手记录检查时间，供间隔轮询使用
    const lastCheckTime = Date.now()
    await updateUserApiInfo(info.id, { lastCheckTime }).catch(() => {})
    action.updateUserApi({ ...info, lastCheckTime })
    return { status: 'latest', fromVersion: info.version, toVersion: parsed.version }
  }

  return applyUpdate(info, script, parsed)
}

/**
 * 冷启动时批量检查一次。
 *
 * 只处理开启了自动更新、且不是「用户手动改过脚本」的音源。
 * 顺序执行，避免同时初始化多个脚本互相干扰；
 * 任何单个音源的失败都不会影响其他音源。
 *
 * 注意：这个函数只应在 App 冷启动时调用一次。
 * 从后台切回前台、解锁回到 App 都不应该触发（不注册 AppState 监听即可）。
 */
export const runAutoUpdate = async(): Promise<void> => {
  // 总开关关闭时，所有音源都不自动检查
  if (!settingState.setting['common.userApiAutoUpdateEnabled']) return
  const list = [...userApiState.list]
  for (const info of list) {
    if (!info.sourceUrl || info.autoUpdate === false) continue
    if (info.userModified) continue
    await checkUserApiUpdate(info).catch(() => {})
  }
}
