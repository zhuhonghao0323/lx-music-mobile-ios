import { useCallback } from 'react'
import Text from '@/components/common/Text'
import { View, TouchableOpacity, ScrollView } from 'react-native'
import { confirmDialog, createStyle } from '@/utils/tools'
import { useTheme } from '@/store/theme/hook'
import { useI18n } from '@/lang'
import { useUserApiList, state as userApiState } from '@/store/userApi'
import { useSettingValue } from '@/store/setting/hook'
import { removeUserApi, setUserApiAllowShowUpdateAlert, setUserApiAutoUpdate } from '@/core/userApi'
import { bindSourceUrl, canUpdateUserApi, handleManualUpdate } from './updateAction'
import { BorderRadius } from '@/theme'
import CheckBox from '@/components/common/CheckBox'
import { Icon } from '@/components/common/Icon'
import settingState from '@/store/setting/state'
import apiSourceInfo from '@/utils/musicSdk/api-source-info'
import { setApiSource } from '@/core/apiSource'

const formatVersionName = (version: string) => {
  return /^\d/.test(version) ? `v${version}` : version
}
const ListItem = ({ item, activeId, onRemove, onChangeAllowShowUpdateAlert, onChangeAutoUpdate, onUpdate, onBindUrl }: {
  item: LX.UserApi.UserApiInfo
  activeId: string
  onRemove: (id: string, name: string) => void
  onChangeAllowShowUpdateAlert: (id: string, enabled: boolean) => void
  onChangeAutoUpdate: (id: string, enabled: boolean) => void
  onUpdate: (item: LX.UserApi.UserApiInfo) => void
  onBindUrl: (item: LX.UserApi.UserApiInfo) => void
}) => {
  const theme = useTheme()
  const t = useI18n()
  // 只有 URL 导入且版本号可比较的音源才提供更新能力
  const canUpdate = canUpdateUserApi(item)
  const changeAllowShowUpdateAlert = (check: boolean) => {
    onChangeAllowShowUpdateAlert(item.id, check)
  }
  const changeAutoUpdate = (check: boolean) => {
    onChangeAutoUpdate(item.id, check)
  }
  const handleRemove = () => {
    onRemove(item.id, item.name)
  }

  return (
    <View style={{ ...styles.listItem, backgroundColor: activeId == item.id ? theme['c-primary-background-active'] : 'transparent' }}>
      <View style={styles.listItemLeft}>
        <Text size={14}>
          {item.name}
          {
            item.version ? (
              <Text size={12} color={theme['c-font-label']}>{ '   ' + formatVersionName(item.version) }</Text>
            ) : null
          }
          {
            item.author ? (
              <Text size={12} color={theme['c-font-label']}>{ '   ' + item.author }</Text>
            ) : null
          }
        </Text>
        {
          item.description ? (
            <Text size={12} color={theme['c-font-label']}>{item.description}</Text>
          ) : null
        }
        <CheckBox check={item.allowShowUpdateAlert} label={t('user_api_allow_show_update_alert')} onChange={changeAllowShowUpdateAlert} size={0.86} />
        {
          canUpdate
            ? <CheckBox check={item.autoUpdate !== false} label={t('user_api_auto_update')} onChange={changeAutoUpdate} size={0.86} />
            : (
                // 存量音源没有记录来源地址，给个入口手动补绑一次
                <TouchableOpacity style={styles.bindBtn} onPress={() => { onBindUrl(item) }}>
                  <Text size={12} color={theme['c-primary']}>{t('user_api_bind_url_btn')}</Text>
                </TouchableOpacity>
              )
        }
      </View>
      <View style={styles.listItemRight}>
        {
          canUpdate
            ? (
                <TouchableOpacity style={styles.btn} onPress={() => { onUpdate(item) }}>
                  <Icon name="available_updates" color={theme['c-button-font']} />
                </TouchableOpacity>
              )
            : null
        }
        <TouchableOpacity style={styles.btn} onPress={handleRemove}>
          <Icon name="close" color={theme['c-button-font']} />
        </TouchableOpacity>
      </View>
    </View>
  )
}

export interface UserApiEditModalProps {
  onSave: (rules: string) => void
  // onSourceChange: SourceSelectorProps['onSourceChange']
}
export interface UserApiEditModalType {
  show: (rules: string) => void
}


export default () => {
  const userApiList = useUserApiList()
  const apiSource = useSettingValue('common.apiSource')
  const theme = useTheme()
  const t = useI18n()

  const handleRemove = useCallback(async(id: string, name: string) => {
    const confirm = await confirmDialog({
      message: global.i18n.t('user_api_remove_tip', { name }),
      cancelButtonText: global.i18n.t('cancel_button_text_2'),
      confirmButtonText: global.i18n.t('confirm_button_text'),
      bgClose: false,
    })
    if (!confirm) return
    void removeUserApi([id]).finally(() => {
      if (settingState.setting['common.apiSource'] == id) {
        let backApiId = apiSourceInfo.find(api => !api.disabled)?.id
        if (!backApiId) backApiId = userApiState.list[0]?.id
        setApiSource(backApiId ?? '')
      }
    })
  }, [])
  const handleChangeAllowShowUpdateAlert = useCallback((id: string, enabled: boolean) => {
    void setUserApiAllowShowUpdateAlert(id, enabled)
  }, [])
  const handleChangeAutoUpdate = useCallback((id: string, enabled: boolean) => {
    void setUserApiAutoUpdate(id, enabled)
  }, [])
  const handleUpdate = useCallback((item: LX.UserApi.UserApiInfo) => {
    void handleManualUpdate(item)
  }, [])
  const handleBindUrl = useCallback((item: LX.UserApi.UserApiInfo) => {
    bindSourceUrl(item)
  }, [])

  return (
    <ScrollView style={styles.scrollView} keyboardShouldPersistTaps={'always'}>
      <View onStartShouldSetResponder={() => true}>
        {
          userApiList.length
            ? userApiList.map((item) => {
              return (
              <ListItem
                key={item.id}
                item={item}
                activeId={apiSource}
                onRemove={handleRemove}
                onChangeAllowShowUpdateAlert={handleChangeAllowShowUpdateAlert}
                onChangeAutoUpdate={handleChangeAutoUpdate}
                onUpdate={handleUpdate}
                onBindUrl={handleBindUrl}
              />
              )
            })
            : <Text style={styles.tipText} color={theme['c-font-label']}>{t('user_api_empty')}</Text>
        }
      </View>
    </ScrollView>
  )
}


const styles = createStyle({
  scrollView: {
    paddingHorizontal: 7,
    flexGrow: 0,
  },
  list: {
    paddingBottom: 15,
    flexDirection: 'column',
  },
  listItem: {
    padding: 10,
    borderRadius: BorderRadius.normal,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  listItemLeft: {
    paddingRight: 10,
    flex: 1,
    gap: 2,
  },
  listItemRight: {
    flex: 0,
    // backgroundColor: 'rgba(0, 0, 0, 0.2)',
  },
  // btns: {
  //   padding: 5,
  // },
  btn: {
    padding: 10,
    // backgroundColor: 'rgba(0, 0, 0, 0.2)',
  },
  bindBtn: {
    paddingTop: 4,
    paddingBottom: 2,
    alignSelf: 'flex-start',
  },
  tipText: {
    textAlign: 'center',
    marginTop: 25,
    marginBottom: 15,
  },
})


