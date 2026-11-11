import Content from './Content'
import BottomTabs from './BottomTabs'
import PlayerBar from '@/components/player/PlayerBar'
import { useNavActiveId } from '@/store/common/hook'

/**
 * 首页容器。
 *
 * 底部结构（对标波点）：
 *   内容区
 *   → BottomTabs（左「主页」图标 + 中间迷你条胶囊 + 右「我的」图标）
 *
 * - 迷你条胶囊 = 原 PlayerBar，放在 BottomTabs 的中间插槽里
 * - 播放页（nav_player）时中间插槽为空，只留左右导航图标
 */
export default () => {
  const activeId = useNavActiveId()
  return (
    <>
      <Content />
      <BottomTabs>
        {activeId == 'nav_player' ? null : <PlayerBar isHome />}
      </BottomTabs>
    </>
  )
}
