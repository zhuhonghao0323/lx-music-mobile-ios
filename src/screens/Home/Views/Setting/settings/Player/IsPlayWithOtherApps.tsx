import { memo, useCallback, useRef, useState } from 'react'
import { View } from 'react-native'

import { updateSetting } from '@/core/common'
import { useI18n } from '@/lang'
import { createStyle } from '@/utils/tools'
import { useSettingValue } from '@/store/setting/hook'
import CheckBox from '@/components/common/CheckBox'
import ConfirmAlert, { type ConfirmAlertType } from '@/components/common/ConfirmAlert'
import Text from '@/components/common/Text'
import { applyAudioMix } from '@/plugins/player'

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
    // 直接改音频会话，不销毁播放器：
    // dependencies-patch.js 给 RNTrackPlayer.swift 的 updateOptions 补了
    // applyAudioSessionOptions，传 iosCategory 就会重新 setCategory + setActive。
    // 这样切换时播放不中断，和酷狗/波点的做法一致。
    void applyAudioMix(enabled)
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
