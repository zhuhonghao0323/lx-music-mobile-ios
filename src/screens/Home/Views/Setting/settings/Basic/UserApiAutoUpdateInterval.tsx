import { memo, useMemo } from 'react'
import { View } from 'react-native'

import CheckBox from '@/components/common/CheckBox'
import Text from '@/components/common/Text'
import { useSettingValue } from '@/store/setting/hook'
import { useI18n } from '@/lang'
import { updateSetting } from '@/core/common'
import { useTheme } from '@/store/theme/hook'
import { createStyle } from '@/utils/tools'

type Interval = LX.AppSetting['common.userApiAutoUpdateInterval']

const setIntervalValue = (value: Interval) => {
  updateSetting({ 'common.userApiAutoUpdateInterval': value })
}

const Item = ({ id, name }: { id: Interval, name: string }) => {
  const current = useSettingValue('common.userApiAutoUpdateInterval')
  return <CheckBox marginBottom={3} check={current == id} label={name} onChange={() => { setIntervalValue(id) }} need />
}

/**
 * URL 音源后台自动更新的检查间隔。
 * 只有音源自身开启了「自动更新URL音源」时，这个间隔才有意义。
 */
export default memo(() => {
  const t = useI18n()
  const theme = useTheme()
  const list = useMemo(() => ([
    { id: '1' as const, name: t('setting_basic_user_api_auto_update_interval_1') },
    { id: '3' as const, name: t('setting_basic_user_api_auto_update_interval_3') },
    { id: '7' as const, name: t('setting_basic_user_api_auto_update_interval_7') },
  ]), [t])

  return (
    <View style={styles.container}>
      <Text size={13} color={theme['c-500']} style={styles.title}>{t('setting_basic_user_api_auto_update_interval')}</Text>
      {list.map(({ id, name }) => <Item id={id} name={name} key={id} />)}
    </View>
  )
})

const styles = createStyle({
  container: {
    marginTop: 10,
  },
  title: {
    marginBottom: 6,
  },
})
