import { memo, useCallback, useRef, useState } from 'react'
import { View } from 'react-native'

import { updateSetting } from '@/core/common'
import { useI18n } from '@/lang'
import { createStyle } from '@/utils/tools'
import { useSettingValue } from '@/store/setting/hook'
import CheckBox from '@/components/common/CheckBox'
import ConfirmAlert, { type ConfirmAlertType } from '@/components/common/ConfirmAlert'
import Text from '@/components/common/Text'
import { reloadConfig } from '@/plugins/player'

import CheckBoxItem from '../../components/CheckBoxItem'

export default memo(() => {
  const t = useI18n()
  const isEnabled = useSettingValue('player.isPlayWithOtherApps')
  const isTipDisabled = useSettingValue('player.isPlayWithOtherAppsTipDisabled')

  const alertRef = useRef<ConfirmAlertType>(null)
  const [noMoreTip, setNoMoreTip] = useState(false)
  // 弹窗确认后要切到的目标状态
  const pendingRef = useRef(false)

  const applyChange = useCallback((enabled: boolean) => {
    updateSetting({ 'player.isPlayWithOtherApps': enabled })
    // iOS 的音频会话只在 setupPlayer 时配置，updateOptions 不会处理，
    // 所以这里必须走「销毁 + 重建 + 恢复播放」。
    // reloadConfig 内部已处理 FLAC 播放快照与当前曲目/进度的恢复，
    // 播放器未初始化时它会直接返回，安全。
    void reloadConfig()
  }, [])

  const handleChange = useCallback((check: boolean) => {
    // 关闭时不需要风险提示（关闭即恢复默认行为）
    if (!check) {
      applyChange(false)
      return
    }
    // 用户已勾选「下次不再提醒」
    if (isTipDisabled) {
      applyChange(true)
      return
    }
    pendingRef.current = true
    setNoMoreTip(false)
    alertRef.current?.setVisible(true)
  }, [applyChange, isTipDisabled])

  const handleConfirm = useCallback(() => {
    if (noMoreTip) updateSetting({ 'player.isPlayWithOtherAppsTipDisabled': true })
    alertRef.current?.setVisible(false)
    applyChange(pendingRef.current)
  }, [applyChange, noMoreTip])

  const handleCancel = useCallback(() => {
    alertRef.current?.setVisible(false)
  }, [])

  return (
    <View style={styles.content}>
      <CheckBoxItem check={isEnabled} onChange={handleChange} label={t('setting_play_with_other_apps')} />
      <ConfirmAlert
        ref={alertRef}
        title={t('setting_play_with_other_apps_tip_title')}
        cancelText={t('setting_play_with_other_apps_cancel')}
        confirmText={t('setting_play_with_other_apps_confirm')}
        onCancel={handleCancel}
        onConfirm={handleConfirm}
      >
        <View>
          <Text style={styles.tipLine}>{t('setting_play_with_other_apps_tip_1')}</Text>
          <Text style={styles.tipLine}>{t('setting_play_with_other_apps_tip_2')}</Text>
          <View style={styles.checkbox}>
            <CheckBox
              check={noMoreTip}
              label={t('setting_play_with_other_apps_no_more_tip')}
              onChange={setNoMoreTip}
              size={0.86}
            />
          </View>
        </View>
      </ConfirmAlert>
    </View>
  )
})

const styles = createStyle({
  content: {
    marginTop: 5,
  },
  tipLine: {
    lineHeight: 20,
  },
  checkbox: {
    marginTop: 12,
  },
})
