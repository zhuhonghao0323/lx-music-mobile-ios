import Content from './Content'
import BottomTabs from './BottomTabs'
import PlayerBar from '@/components/player/PlayerBar'

/**
 * 首页容器。
 *
 * 布局重构后不再有「左滑抽屉」，改为：
 *   内容区（三 Tab，由 Content 承载）
 *   → 底部迷你播放条（全局常驻）
 *   → 底部主导航（主页 / 正在播放 / 我的）
 *
 * 迷你条与导航在三个 Tab 之间保持一致，切 Tab 不会中断播放。
 */
export default () => {
  return (
    <>
      <Content />
      <PlayerBar isHome />
      <BottomTabs />
    </>
  )
}
