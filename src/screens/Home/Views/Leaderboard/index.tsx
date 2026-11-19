import { useHorizontalMode } from '@/utils/hooks'
import Vertical from './Vertical'
import Horizontal from './Horizontal'
import { isSwiftUIPageSupported } from '@/screens/SwiftUIPages/swiftUIPageBridge'
import LeaderboardSwiftUIContainer from '@/screens/SwiftUIPages/LeaderboardContainer'

export default () => {
  const isHorizontalMode = useHorizontalMode()

  // iOS 使用 SwiftUI 实现，其它平台保留 RN
  if (isSwiftUIPageSupported) return <LeaderboardSwiftUIContainer />

  return isHorizontalMode
    ? <Horizontal />
    : <Vertical />
}
