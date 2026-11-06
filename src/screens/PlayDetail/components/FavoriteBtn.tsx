import { useCallback, useRef } from 'react'
import { type LayoutRectangle } from 'react-native'
import MusicAddModal, { type MusicAddModalType } from '@/components/MusicAddModal'
import { getPlayMusicInfo, toggleFavorite } from '@/core/favorite'
import { useIsMusicFavorited } from '@/store/list/hook'
import { usePlayMusicInfo } from '@/store/player/hook'
import { toast } from '@/utils/tools'
import { playFavoriteDockAnimation } from './FavoriteDockAnimation'

export interface FavoriteBtnRenderProps {
  /** 是否已收藏 */
  favorited: boolean
  /** 轻点（切换收藏状态） */
  onPress: () => void
  /** 长按（弹出收藏列表目录） */
  onLongPress: () => void
  /** 供按钮把自身 ref 交给收藏逻辑，用于测量心形位置 */
  setAnchorRef: (node: MeasurableNode | null) => void
}

/** 只需要能 measureInWindow 的节点即可，TouchableOpacity / View 都满足 */
interface MeasurableNode {
  measureInWindow: (cb: (x: number, y: number, width: number, height: number) => void) => void
}

/**
 * 收藏按钮的公共逻辑：
 * - 显示收藏状态（已收藏时由各端 Btn 渲染实心红心）
 * - 轻点：切换收藏状态，并播放「封面收进/抽出心形」的 Dock 动画
 * - 长按：弹出收藏列表目录，选择列表收藏
 * 动画坐标全部通过 measureInWindow 运行时测量，天然适配所有机型。
 */
export default ({ children }: {
  children: (props: FavoriteBtnRenderProps) => React.ReactNode
}) => {
  const playMusicInfo = usePlayMusicInfo()
  const musicInfo = getPlayMusicInfo()
  const favorited = useIsMusicFavorited(musicInfo)
  const musicAddModalRef = useRef<MusicAddModalType>(null)
  const anchorRef = useRef<MeasurableNode | null>(null)

  const setAnchorRef = useCallback((node: MeasurableNode | null) => {
    anchorRef.current = node
    if (node) {
      registerHeartSource((cb) => {
        const target = anchorRef.current
        if (!target) { cb(null); return }
        target.measureInWindow((x, y, width, height) => { cb({ x, y, width, height }) })
      })
    } else {
      clearHeartSource()
    }
  }, [])

  const handlePress = () => {
    if (!musicInfo) return
    const anchor = anchorRef.current
    if (!anchor) {
      void toggleFavorite(musicInfo)
      return
    }
    // 先测量心形与封面位置，再起动画；收藏数据立即生效，动画只做视觉反馈
    void measureHeart().then(target => {
      void measureCover().then(from => {
        void toggleFavorite(musicInfo).then(result => {
          toast(global.i18n.t(result ? 'collect_success' : 'collect_cancel'))
          if (!from || !target || from.width <= 0) return
          playFavoriteDockAnimation({
            from,
            to: target,
            pic: currentCoverPic(),
            direction: result ? 'add' : 'remove',
          })
        })
      })
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
      {children({ favorited, onPress: handlePress, onLongPress: handleLongPress, setAnchorRef })}
      <MusicAddModal ref={musicAddModalRef} />
    </>
  )
}

/* 由播放页封面注册：提供封面测量函数与当前封面图，供动画克隆使用 */
let coverRectProvider: ((cb: (rect: LayoutRectangle | null) => void) => void) | null = null
let coverPicProvider: (() => string | null) | null = null
/* 由心形按钮注册：提供心形测量函数 */
let heartRectProvider: ((cb: (rect: LayoutRectangle | null) => void) => void) | null = null

export const registerCoverSource = (
  measure: (cb: (rect: LayoutRectangle | null) => void) => void,
  pic: () => string | null,
) => {
  coverRectProvider = measure
  coverPicProvider = pic
}

export const clearCoverSource = () => {
  coverRectProvider = null
  coverPicProvider = null
}

export const registerHeartSource = (measure: (cb: (rect: LayoutRectangle | null) => void) => void) => {
  heartRectProvider = measure
}

export const clearHeartSource = () => {
  heartRectProvider = null
}

const measureCover = async(): Promise<LayoutRectangle | null> => await new Promise(resolve => {
  if (!coverRectProvider) resolve(null)
  else coverRectProvider(resolve)
})

const measureHeart = async(): Promise<LayoutRectangle | null> => await new Promise(resolve => {
  if (!heartRectProvider) resolve(null)
  else heartRectProvider(resolve)
})

const currentCoverPic = () => coverPicProvider?.() ?? null

/**
 * 供封面手势（长按收藏模式下的上/下滑）复用同一套 Dock 动画。
 * 数据变更由调用方负责，这里只负责测量 + 播放动画。
 */
export const triggerFavoriteDockAnimation = async(direction: 'add' | 'remove') => {
  const [from, to] = await Promise.all([measureCover(), measureHeart()])
  if (!from || !to || from.width <= 0 || to.width <= 0) return
  playFavoriteDockAnimation({ from, to, pic: currentCoverPic(), direction })
}
