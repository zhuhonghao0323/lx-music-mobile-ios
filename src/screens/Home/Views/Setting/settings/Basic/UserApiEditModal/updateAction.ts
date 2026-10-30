import { Alert, Platform } from 'react-native'

import { checkUserApiUpdate } from '@/core/userApiUpdater'
import { updateUserApiInfo } from '@/utils/data'
import { action } from '@/store/userApi'
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

/**
 * 给存量音源补绑更新地址。
 *
 * 背景：`sourceUrl` 只有在「在线导入」时才会被记录，而升级前导入的音源没有这个字段，
 * 脚本内容本身也不包含下载地址，所以只能让用户手动补一次。
 * 绑定之后这个音源就能正常参与版本检查与自动更新。
 */
export const bindSourceUrl = (info: LX.UserApi.UserApiInfo): void => {
  const applyUrl = (input?: string) => {
    const url = (input ?? '').trim()
    if (!/^https?:\/\//.test(url)) {
      toast(global.i18n.t('user_api_bind_url_invalid'))
      return
    }
    const next: LX.UserApi.UserApiInfo = {
      ...info,
      sourceUrl: url,
      autoUpdate: info.autoUpdate !== false,
      lastCheckTime: 0,
    }
    void updateUserApiInfo(info.id, next).then(() => {
      action.updateUserApi(next)
      toast(global.i18n.t('user_api_bind_url_success'))
    })
  }

  if (Platform.OS == 'ios') {
    // 用系统原生 prompt，避免在「自定义源管理」这个 Modal 里再套一层 Modal
    Alert.prompt(
      global.i18n.t('user_api_bind_url_title'),
      global.i18n.t('user_api_bind_url_message'),
      [
        { text: global.i18n.t('cancel'), style: 'cancel' },
        { text: global.i18n.t('confirm'), onPress: applyUrl },
      ],
      'plain-text',
      info.sourceUrl ?? '',
    )
  }
}
