import { useHorizontalMode } from '@/utils/hooks'
import Vertical from './Vertical'
import Horizontal from './Horizontal'
import { useBackHandler } from '@/utils/hooks/useBackHandler'
import { useCallback } from 'react'
// import { AppColors } from '@/theme'
import commonState from '@/store/common/state'
import { setNavActiveId } from '@/core/common'
import { isSwiftUIPageSupported } from '@/screens/SwiftUIPages/swiftUIPageBridge'
import SettingSwiftUIContainer from '@/screens/SwiftUIPages/SettingContainer'

export type { SettingScreenIds } from './Main'

export default () => {
  const isHorizontalMode = useHorizontalMode()
  const settingActiveId = global.lx.settingActiveId
  useBackHandler(useCallback(() => {
    if (Object.keys(commonState.componentIds).length == 1 && commonState.navActiveId == 'nav_setting') {
      setNavActiveId(commonState.lastNavActiveId)
      return true
    }
    return false
  }, []))

  // iOS：未选中具体子页时用 SwiftUI 分组导航；选中子页后走原有 RN 子页
  if (isSwiftUIPageSupported && !settingActiveId) return <SettingSwiftUIContainer />

  return isHorizontalMode
    ? <Horizontal />
    : <Vertical />
}
