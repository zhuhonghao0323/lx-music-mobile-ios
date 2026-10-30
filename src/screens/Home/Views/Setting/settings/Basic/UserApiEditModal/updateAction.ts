import { checkUserApiUpdate } from '@/core/userApiUpdater'
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

/** 该音源是否支持更新：必须来自 URL 导入，且本地版本号可比较 */
export const canUpdateUserApi = (info: LX.UserApi.UserApiInfo): boolean => {
  return !!info.sourceUrl && /^\d/.test(info.version ?? '')
}
