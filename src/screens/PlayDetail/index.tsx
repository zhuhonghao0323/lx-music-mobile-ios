import { useEffect } from 'react'
// import { View, StyleSheet } from 'react-native'
import { useHorizontalMode } from '@/utils/hooks'

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

  useEffect(() => {
    setComponentId(COMPONENT_IDS.playDetail, componentId)
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  // iOS 上无条件使用 SwiftUI 播放页（产品级重构）。
  // 不再依赖 setting 开关，避免 updateSetting 异步写入导致
  // 进入页面时读到的还是旧值、退回到老版 RN 播放页。
  if (isSwiftUIPlayerSupported) {
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
