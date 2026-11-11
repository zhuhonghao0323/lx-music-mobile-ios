import Content from './Content'
import BottomTabs from './BottomTabs'
import PlayerBar from '@/components/player/PlayerBar'
import { useNavActiveId } from '@/store/common/hook'

/**
 * 首页容器。
 *
 * 底部顺序：内容区 → 迷你播放条 → 悬浮胶囊导航。
 *
 * 迷你条在「正在播放」Tab 隐藏：
 * 该 Tab 本身就是全屏播放页，再叠一条迷你条会重复展示播放信息
 * （对接波点的做法：进入播放页后底部只留胶囊导航）。
 */
export default () => {
  const activeId = useNavActiveId()
  return (
    <>
      <Content />
      {activeId == 'nav_player' ? null : <PlayerBar isHome />}
      <BottomTabs />
    </>
  )
}
