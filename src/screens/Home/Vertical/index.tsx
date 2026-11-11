import Content from './Content'
import BottomNavBar from './BottomNavBar'
import PlayerBar from '@/components/player/PlayerBar'
import PlayPauseButton from './PlayPauseButton'
import { useNavActiveId } from '@/store/common/hook'

/**
 * 首页容器。
 *
 * 底部结构（对标波点，统一三按钮）：
 *   内容区
 *   → BottomNavBar（左「首页」图标 + 中间插槽 + 右「我的」图标）
 *
 * - 非播放 Tab：中间插槽 = 迷你条胶囊（点进播放页）
 * - 播放 Tab：中间插槽 = 播放/暂停按钮（与左右图标组成「三个按钮」一行）
 */
export default () => {
  const activeId = useNavActiveId()
  return (
    <>
      <Content />
      <BottomNavBar>
        {activeId == 'nav_player' ? <PlayPauseButton /> : <PlayerBar isHome />}
      </BottomNavBar>
    </>
  )
}
