import { useCallback, useState } from 'react'
import Text from '@/components/common/Text'
import { ActivityIndicator, View, TouchableOpacity, ScrollView } from 'react-native'
import { confirmDialog, createStyle, tipDialog } from '@/utils/tools'
import { useTheme } from '@/store/theme/hook'
import { useI18n } from '@/lang'
import { useUserApiList, state as userApiState } from '@/store/userApi'
import { useSettingValue } from '@/store/setting/hook'
import { removeUserApi, setUserApiAllowShowUpdateAlert, setUserApiAutoUpdate } from '@/core/userApi'
import { canUpdateUserApi, handleManualUpdate, saveSourceUrl } from './updateAction'
import { BorderRadius } from '@/theme'
import CheckBox from '@/components/common/CheckBox'
import Input from '@/components/common/Input'
import { Icon } from '@/components/common/Icon'
import settingState from '@/store/setting/state'
import apiSourceInfo from '@/utils/musicSdk/api-source-info'
import { setApiSource } from '@/core/apiSource'
import { reorderCustomSources } from '@/core/customSource'

const formatVersionName = (version: string) => {
  return /^\d/.test(version) ? `v${version}` : version
}
const ListItem = ({ item, activeId, index, total, isDefault, onRemove, onChangeAllowShowUpdateAlert, onChangeAutoUpdate, onUpdate, onSaveUrl, onMove }: {
  item: LX.UserApi.UserApiInfo
  activeId: string
  index: number
  total: number
  isDefault: boolean
  onRemove: (id: string, name: string) => void
  onChangeAllowShowUpdateAlert: (id: string, enabled: boolean) => void
  onChangeAutoUpdate: (id: string, enabled: boolean) => void
  onUpdate: (item: LX.UserApi.UserApiInfo) => Promise<void>
  onSaveUrl: (item: LX.UserApi.UserApiInfo, url: string) => void
  onMove: (index: number, delta: number) => void
}) => {
  const theme = useTheme()
  const t = useI18n()
  // 只有 URL 导入且版本号可比较的音源才提供更新能力
  const canUpdate = canUpdateUserApi(item)
  // 未绑定时点「绑定更新地址」展开一个内联输入框，
  // 不用弹窗：这个列表本身已经在 Modal 里，再套一层弹层在 iOS 上不可靠
  const [binding, setBinding] = useState(false)
  const [bindUrl, setBindUrl] = useState('')
  const [updating, setUpdating] = useState(false)
  const handleUpdate = async() => {
    if (updating) return
    setUpdating(true)
    try {
      await onUpdate(item)
    } finally {
      setUpdating(false)
    }
  }
  const confirmBind = () => {
    const url = bindUrl.trim()
    if (!url) return
    onSaveUrl(item, url)
    setBinding(false)
    setBindUrl('')
  }
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
        <View style={styles.nameRow}>
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
        </View>
        {
          isDefault
            ? <Text size={11} color={theme['c-primary']}>{t('user_api_priority_default')}</Text>
            : null
        }
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
                binding
                  ? (
                      <View style={styles.bindRow}>
                        <Input
                          value={bindUrl}
                          onChangeText={setBindUrl}
                          placeholder="https://.../script.js"
                          style={{ ...styles.bindInput, backgroundColor: theme['c-primary-input-background'] }}
                        />
                        <TouchableOpacity style={styles.bindOk} onPress={confirmBind}>
                          <Text size={13} color={theme['c-primary']}>{t('confirm')}</Text>
                        </TouchableOpacity>
                      </View>
                    )
                  : (
                      // 存量音源没有记录来源地址，给个入口手动补绑一次
                      <TouchableOpacity style={styles.bindBtn} onPress={() => { setBinding(true) }}>
                        <Text size={12} color={theme['c-primary']}>{t('user_api_bind_url_btn')}</Text>
                      </TouchableOpacity>
                    )
              )
        }
      </View>
      <View style={styles.listItemRight}>
        <View style={styles.priorityBtns}>
          <TouchableOpacity style={styles.priorityBtn} onPress={() => { onMove(index, -1) }} disabled={index == 0}>
            <Icon name="chevron-left-2" color={index == 0 ? theme['c-font-label'] : theme['c-primary']} size={14} style={{ transform: [{ rotate: '90deg' }] }} />
          </TouchableOpacity>
          <TouchableOpacity style={styles.priorityBtn} onPress={() => { onMove(index, 1) }} disabled={index == total - 1}>
            <Icon name="chevron-right-2" color={index == total - 1 ? theme['c-font-label'] : theme['c-primary']} size={14} style={{ transform: [{ rotate: '90deg' }] }} />
          </TouchableOpacity>
        </View>
        {
          canUpdate
            ? (
                <TouchableOpacity style={styles.btn} onPress={handleUpdate} disabled={updating}>
                  {
                    updating
                      ? <ActivityIndicator size="small" color={theme['c-button-font']} />
                      : <Icon name="available_updates" color={theme['c-button-font']} />
                  }
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
  const handleUpdate = useCallback(async(item: LX.UserApi.UserApiInfo) => { await handleManualUpdate(item) }, [])
  const handleSaveUrl = useCallback((item: LX.UserApi.UserApiInfo, url: string) => {
    void saveSourceUrl(item, url).catch((error: any) => {
      // toast 在 iOS 上是空操作，这里必须用 tipDialog 才能真的弹出来
      void tipDialog({ message: global.i18n.t('user_api_bind_url_invalid') })
      console.log('saveSourceUrl failed', error)
    })
  }, [])

  const handleMove = useCallback((index: number, delta: number) => {
    const target = index + delta
    if (target < 0 || target >= userApiList.length) return
    const next = userApiList.map(item => item.id)
    const tmp = next[index]
    next[index] = next[target]
    next[target] = tmp
    void reorderCustomSources(next).then(() => {
      // 排序变化后把当前音源切回新的默认源，保证「第一个是默认音源」
      const first = next[0]
      if (first && settingState.setting['common.apiSource'] != first && /^user_api/.test(settingState.setting['common.apiSource'])) {
        setApiSource(first)
      }
    })
  }, [userApiList])

  return (
    <ScrollView style={styles.scrollView} keyboardShouldPersistTaps={'always'}>
      <View onStartShouldSetResponder={() => true}>
        {
          userApiList.length
            ? <>
                <Text style={styles.priorityTitle} size={13} color={theme['c-primary']}>{t('user_api_priority_title')}</Text>
                <Text style={styles.priorityDesc} size={11} color={theme['c-font-label']}>{t('user_api_priority_desc')}</Text>
                {userApiList.map((item, index) => {
                  return (
                  <ListItem
                    key={item.id}
                    item={item}
                    activeId={apiSource}
                    index={index}
                    total={userApiList.length}
                    isDefault={index == 0}
                    onRemove={handleRemove}
                    onChangeAllowShowUpdateAlert={handleChangeAllowShowUpdateAlert}
                    onChangeAutoUpdate={handleChangeAutoUpdate}
                    onUpdate={handleUpdate}
                    onSaveUrl={handleSaveUrl}
                    onMove={handleMove}
                  />
                  )
                })}
              </>
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
    alignItems: 'center',
    // backgroundColor: 'rgba(0, 0, 0, 0.2)',
  },
  priorityBtns: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 2,
  },
  priorityBtn: {
    padding: 5,
  },
  nameRow: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  priorityTitle: {
    marginTop: 6,
    marginBottom: 2,
  },
  priorityDesc: {
    marginBottom: 8,
    lineHeight: 15,
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
  bindRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginTop: 4,
    gap: 6,
  },
  bindInput: {
    flexGrow: 1,
    flexShrink: 1,
    borderRadius: 4,
    height: 30,
  },
  bindOk: {
    paddingVertical: 6,
    paddingHorizontal: 4,
  },
  tipText: {
    textAlign: 'center',
    marginTop: 25,
    marginBottom: 15,
  },
})


