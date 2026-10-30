import { checkUserApiUpdate } from '@/core/userApiUpdater'
import { updateUserApiInfo } from '@/utils/data'
import { action } from '@/store/userApi'
import { log } from '@/utils/log'
import { confirmDialog, toast } from '@/utils/tools'

/**
 * 手动触发一次音源更新检查（点击更新图标 / 弹窗内的更新按钮）。
 * 与后台自动更新的区别：忽略检查间隔，且遇到 userModified 时用二次确认代替直接跳过。
 */
export const handleManualUpdate = async(info: LX.UserApi.UserApiInfo): Promise<void> => {
  if (!info.sourceUrl) return

  // 用户手动改过脚本 → 覆盖前必须确认
  if (info.userModified) {
    const confirmed = await confirmDialog({
      title: global.i18n.t('user_api_update_user_modified_title'),
      message: global.i18n.t('user_api_update_user_modified_message'),
      confirmButtonText: global.i18n.t('user_api_update_btn_continue'),
      cancelButtonText: global.i18n.t('cancel'),
    })
    if (!confirmed) return
  }

  toast(global.i18n.t('user_api_update_manual_checking'))
  const result = await checkUserApiUpdate(info, { force: true })

  switch (result.status) {
    case 'updated':
      toast(global.i18n.t('user_api_update_manual_success', { version: result.toVersion ?? '' }))
      break
    case 'latest':
      toast(global.i18n.t('user_api_update_manual_latest'))
      break
    case 'skipped':
      toast(global.i18n.t('user_api_update_manual_skipped'))
      break
    default:
      toast(global.i18n.t('user_api_update_manual_failed'))
      break
  }
}

/**
 * 该音源是否支持更新：只要绑定了来源地址就显示更新按钮。
 *
 * 版本号是否合法交给点击时判断——如果本地版本不合法，
 * checkUserApiUpdate 会返回 skipped，UI 提示「该音源不支持更新」。
 * 这样用户总能看见按钮，不会因为版本格式问题以为功能没生效。
 */
export const canUpdateUserApi = (info: LX.UserApi.UserApiInfo): boolean => {
  return !!info.sourceUrl
}

/**
 * 给存量音源补绑更新地址并立即检查一次。
 *
 * 背景：`sourceUrl` 只有在「在线导入」时才会被记录，升级前导入的音源没有这个字段，
 * 脚本内容本身也不包含下载地址，所以只能让用户手动补一次。
 *
 * 输入交互由调用方（列表内联输入框）负责——之前用 Alert.prompt，
 * 但在 iOS 上不可靠，改成内联输入后这个函数只做校验与保存。
 */
export const saveSourceUrl = async(info: LX.UserApi.UserApiInfo, input: string): Promise<boolean> => {
  const url = input.trim()
  if (!/^https?:\/\//.test(url)) {
    toast(global.i18n.t('user_api_bind_url_invalid'))
    return false
  }
  const next: LX.UserApi.UserApiInfo = {
    ...info,
    sourceUrl: url,
    autoUpdate: info.autoUpdate !== false,
    lastCheckTime: 0,
  }
  // 先更新 store：界面必须立刻出现更新按钮，不能等持久化结果
  action.updateUserApi(next)

  try {
    const saved = await updateUserApiInfo(info.id, next)
    if (!saved) log.warn('[userApi] 绑定地址未能写入存储，仅更新了内存状态')
  } catch (error: any) {
    log.warn(`[userApi] 绑定地址持久化失败: ${error?.message ?? ''}`)
  }

  // 绑定后立刻检查一次，用户不用再去找更新按钮
  void handleManualUpdate(next)
  return true
}
