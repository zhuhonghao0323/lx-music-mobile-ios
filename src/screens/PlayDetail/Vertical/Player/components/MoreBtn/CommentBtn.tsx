import Btn from './Btn'
import { navigations } from '@/navigation'
import commonState from '@/store/common/state'

export default ({ onPress }: {
  /** 自定义点击行为（新版播放 Tab 用底部抽屉展示评论） */
  onPress?: () => void
} = {}) => {
  const handleShowCommentScreen = () => {
    // 自定义行为优先
    if (onPress) {
      onPress()
      return
    }
    // 旧版独立播放页：push 评论页。componentId 可能不存在，需判空避免静默失败。
    const componentId = commonState.componentIds.playDetail
    if (!componentId) return
    navigations.pushCommentScreen(componentId)
  }

  return <Btn icon="comment" onPress={handleShowCommentScreen} />
}
