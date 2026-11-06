import { useRef } from 'react'
import MusicAddModal, { type MusicAddModalType } from '@/components/MusicAddModal'
import { getPlayMusicInfo, toggleFavorite } from '@/core/favorite'
import { useIsMusicFavorited } from '@/store/list/hook'
import { usePlayMusicInfo } from '@/store/player/hook'
import { toast } from '@/utils/tools'

export interface FavoriteBtnRenderProps {
  /** 是否已收藏 */
  favorited: boolean
  /** 轻点（切换收藏状态） */
  onPress: () => void
  /** 长按（弹出收藏列表目录） */
  onLongPress: () => void
}

/**
 * 收藏按钮的公共逻辑：
 * - 显示收藏状态（已收藏时由各端 Btn 渲染实心红心）
 * - 轻点：直接切换收藏状态（未收藏→加入「我的收藏」；已收藏→取消收藏）
 * - 长按：弹出收藏列表目录，选择列表收藏（保持原来的轻点逻辑）
 *「我的收藏」是全量聚合清单，收藏到任意列表后由 core/favorite 的同步逻辑补充进去。
 * 具体的图标/布局由各端 Btn 渲染，通过 children 回调注入。
 */
export default ({ children }: {
  children: (props: FavoriteBtnRenderProps) => React.ReactNode
}) => {
  const playMusicInfo = usePlayMusicInfo()
  const musicInfo = getPlayMusicInfo()
  const favorited = useIsMusicFavorited(musicInfo)
  const musicAddModalRef = useRef<MusicAddModalType>(null)

  const handlePress = () => {
    if (!musicInfo) return
    void toggleFavorite(musicInfo).then(result => {
      // toast 在 iOS 上是空操作，这里仅用于 Android 上的轻提示
      toast(global.i18n.t(result ? 'collect_success' : 'collect_cancel'))
    })
  }

  const handleLongPress = () => {
    if (!musicInfo) return
    musicAddModalRef.current?.show({
      musicInfo,
      isMove: false,
      listId: playMusicInfo.listId!,
    })
  }

  return (
    <>
      {children({ favorited, onPress: handlePress, onLongPress: handleLongPress })}
      <MusicAddModal ref={musicAddModalRef} />
    </>
  )
}
