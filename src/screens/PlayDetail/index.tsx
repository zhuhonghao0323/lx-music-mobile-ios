import { useEffect } from 'react'
// import { View, StyleSheet } from 'react-native'
import { useHorizontalMode } from '@/utils/hooks'
import { useSettingValue } from '@/store/setting/hook'

import Vertical from './Vertical'
import Horizontal from './Horizontal'
import SwiftUIPlayerContainer from './SwiftUI/SwiftUIPlayerContainer'
import { isSwiftUIPlayerSupported } from './SwiftUI/swiftUIPlayerBridge'
import PageContent from '@/components/PageContent'
import StatusBar from '@/components/common/StatusBar'
import { setComponentId } from '@/core/common'
import { COMPONENT_IDS } from '@/config/constant'

export default ({ componentId }: { componentId: string }) => {
  const isHorizontalMode = useHorizontalMode()
  // SwiftUI 播放页开关：默认关闭；仅 iOS 且原生模块就绪时才可用
  const useSwiftUIPlayer = useSettingValue('player.useSwiftUIPlayer')

  useEffect(() => {
    setComponentId(COMPONENT_IDS.playDetail, componentId)
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  // SwiftUI 版自带完整全屏背景与顶栏，直接用原生视图铺满，
  // 不再套 PageContent（否则 RN 的主题背景层会盖住 SwiftUI 的背景）
  if (useSwiftUIPlayer && isSwiftUIPlayerSupported) {
    return <SwiftUIPlayerContainer />
  }

  return (
    <PageContent>
      <StatusBar />
      {
        isHorizontalMode
          ? <Horizontal componentId={componentId} />
          : <Vertical componentId={componentId} />
      }
    </PageContent>
  )
}
