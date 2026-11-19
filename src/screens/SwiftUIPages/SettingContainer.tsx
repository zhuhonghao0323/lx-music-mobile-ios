import { memo, useEffect, useMemo } from 'react'
import { View, StyleSheet } from 'react-native'
import { NativeSettingView, updatePageState, onPageCommand } from './swiftUIPageBridge'
import { useTheme } from '@/store/theme/hook'
import { setNavActiveId } from '@/core/common'
import commonState from '@/store/common/state'

const PAGE_ID = 'setting'

/** 设置页 SwiftUI 容器：分组导航，点击后打开原有 RN 设置子页 */
export default memo(() => {
  const theme = useTheme()

  useEffect(() => onPageCommand((pageId, command, payload) => {
    if (pageId != PAGE_ID) return
    switch (command) {
      case 'openSettingPage': {
        // 交给原有 RN 设置页处理（保证所有设置项与交互完整保留）
        const id = String(payload.id ?? '')
        if (id) {
          global.lx.settingActiveId = id as never
          setNavActiveId('nav_setting')
        }
        break
      }
      case 'back': setNavActiveId(commonState.lastNavActiveId ?? 'nav_mine'); break
      default: break
    }
  }), [])

  const state = useMemo(() => ({
    version: process.versions.app ?? '',
    themeName: theme.name ?? '',
  }), [theme])

  useEffect(() => { updatePageState(PAGE_ID, state) }, [state])

  if (!NativeSettingView) return null
  return <View style={styles.container}><NativeSettingView style={styles.view} /></View>
})

const styles = StyleSheet.create({ container: { flex: 1 }, view: { flex: 1 } })
