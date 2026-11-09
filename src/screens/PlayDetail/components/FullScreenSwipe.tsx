import { useCallback, useMemo, useRef } from 'react'
import { PanResponder, StyleSheet, View, type GestureResponderEvent, type PanResponderGestureState } from 'react-native'
import { playNext, playPrev } from '@/core/player/player'
import { markTimeoutExitInteraction } from '@/core/player/timeoutExit'

/** 全屏上下轻滑切歌的最小距离 */
const SWIPE_THRESHOLD = 60
/** 判定为「竖直」的轴比，斜向/横向不处理，避免与翻页冲突 */
const AXIS_RATIO = 1.5

/**
 * 全屏上下轻滑切歌（覆盖整个播放页，方便单手操作）。
 *
 * 只在「明显竖直」的拖动上抢走 responder，普通点击仍然落到底下的按钮上，
 * 横向滑动也仍然交给 PagerView 翻页，互不干扰。
 */
export default ({ children, onSwiped }: {
  children: React.ReactNode
  onSwiped?: (action: 'prev' | 'next') => void
}) => {
  const busyRef = useRef(false)

  const run = useCallback((action: 'prev' | 'next') => {
    markTimeoutExitInteraction()
    if (action == 'next') void playNext()
    else void playPrev()
    onSwiped?.(action)
  }, [onSwiped])

  const panResponder = useMemo(() => PanResponder.create({
    // 不抢按下事件：普通点击继续交给下面的按钮
    onStartShouldSetPanResponder: () => false,
    onMoveShouldSetPanResponder: (_e: GestureResponderEvent, gs: PanResponderGestureState) => {
      if (busyRef.current) return false
      const ax = Math.abs(gs.dx)
      const ay = Math.abs(gs.dy)
      return ay > 10 && ay >= ax * AXIS_RATIO
    },
    onPanResponderTerminationRequest: () => false,
    onPanResponderRelease: (_e: GestureResponderEvent, gs: PanResponderGestureState) => {
      const ay = Math.abs(gs.dy)
      const ax = Math.abs(gs.dx)
      if (ay < SWIPE_THRESHOLD || ay < ax * AXIS_RATIO) return
      busyRef.current = true
      run(gs.dy < 0 ? 'next' : 'prev')
      // 给切歌动画一点时间，避免连续触发
      setTimeout(() => { busyRef.current = false }, 350)
    },
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }), [run])

  return (
    <View style={styles.container} {...panResponder.panHandlers}>
      {children}
    </View>
  )
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
})
