import { memo } from 'react'
import { View } from 'react-native'

import CheckBoxItem from '../../components/CheckBoxItem'
import { useSettingValue } from '@/store/setting/hook'
import { updateSetting } from '@/core/common'
import { useI18n } from '@/lang'
import { isSwiftUIPlayerSupported } from '@/screens/PlayDetail/SwiftUI/swiftUIPlayerBridge'

/** SwiftUI 播放页开关（默认关闭，随时可切回 RN 播放页） */
export default memo(() => {
  const t = useI18n()
  const enabled = useSettingValue('player.useSwiftUIPlayer')
  if (!isSwiftUIPlayerSupported) return null

  return (
    <View>
      <CheckBoxItem
        check={enabled}
        label={t('setting_player_use_swiftui_player')}
        onChange={(check: boolean) => { updateSetting({ 'player.useSwiftUIPlayer': check }) }}
      />
    </View>
  )
})
