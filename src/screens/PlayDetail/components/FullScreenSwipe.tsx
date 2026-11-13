import { useCallback, useMemo, useRef } from 'react'
import { Animated, Dimensions, Easing, PanResponder, StyleSheet, type GestureResponderEvent, type PanResponderGestureState } from 'react-native'
import { playNext, playPrev } from '@/core/player/player'
import { markTimeoutExitInteraction } from '@/core/player/timeoutExit'
import { haptic } from '@/utils/haptics'

/**
 * 切歌阈值：参考主流音乐 App 的手感，取屏幕高度的一个适中比例。
 * - 太小：手一抖就切歌，太灵敏
 * - 太大：需要拖很远，单手不方便
 * 这里按屏幕高度约 1/9（iPhone 14 PM 上约 100px）动态计算，并夹在 68~120 之间。
 */
const getSwipeThreshold = (height: number) => Math.max(68, Math.min(120, height / 9))
/** 判定为「竖直」的轴比：竖直位移需达到水平的 1.4 倍以上才接管 */
const AXIS_RATIO = 1.4
/** 接管手势的最小竖直位移：避免横向翻页时的微小竖直抖动被误判 */
const MIN_VERTICAL_DELTA = 14
/** 达到阈值后松手，界面飞出动画时长 */
const FLY_DURATION = 220

/**
 * 全屏上下轻滑切歌，带跟手拖动效果。
 *
 * 丝滑要点（对齐歌词翻页的手感）：
 * - 所有动画走 useNativeDriver（原生驱动），避免 JS 线程抖动导致卡顿
 * - 跟手位移用 1:1 映射（不再乘阻尼），手指与内容完全同步
 * - 松手后用 spring 曲线回弹/飞出，而不是固定时长的 timing
 */
export default ({ children, onSwiped, disabled = false }: {
  children: React.ReactNode
  onSwiped?: (action: 'prev' | 'next') => void
  /** 有二级弹窗/抽屉打开时禁用切歌手势，避免弹窗内滑动误切歌 */
  disabled?: boolean
}) => {
  const busyRef = useRef(false)
  const disabledRef = useRef(disabled)
  disabledRef.current = disabled
  const armedRef = useRef(false)
  const translateY = useRef(new Animated.Value(0)).current
  const scale = useRef(new Animated.Value(1)).current
  const opacity = useRef(new Animated.Value(1)).current

  const reset = useCallback(() => {
    Animated.parallel([
      Animated.spring(translateY, { toValue: 0, friction: 9, tension: 120, useNativeDriver: true }),
      Animated.spring(scale, { toValue: 1, friction: 9, tension: 120, useNativeDriver: true }),
      Animated.timing(opacity, { toValue: 1, duration: 160, useNativeDriver: true }),
    ]).start()
  }, [translateY, scale, opacity])

  const run = useCallback((action: 'prev' | 'next', flyY: number) => {
    markTimeoutExitInteraction()
    haptic.trackChange()
    Animated.parallel([
      Animated.timing(translateY, { toValue: flyY, duration: FLY_DURATION, easing: Easing.out(Easing.cubic), useNativeDriver: true }),
      Animated.timing(opacity, { toValue: 0, duration: FLY_DURATION, useNativeDriver: true }),
    ]).start(() => {
      if (action == 'next') void playNext()
      else void playPrev()
      onSwiped?.(action)
      // 复位后淡入新页面（瞬时置位，避免看到回弹）
      translateY.setValue(0)
      scale.setValue(1)
      opacity.setValue(1)
      Animated.timing(opacity, { toValue: 1, duration: 180, useNativeDriver: true }).start()
      setTimeout(() => { busyRef.current = false }, 320)
    })
  }, [onSwiped, translateY, scale, opacity])

  const panResponder = useMemo(() => PanResponder.create({
    // 不抢按下事件：普通点击继续交给下面的按钮
    onStartShouldSetPanResponder: () => false,
    onMoveShouldSetPanResponder: (_e: GestureResponderEvent, gs: PanResponderGestureState) => {
      // 弹窗/抽屉打开时完全不接管手势
      if (disabledRef.current || busyRef.current) return false
      const ax = Math.abs(gs.dx)
      const ay = Math.abs(gs.dy)
      // 必须明确是竖直滑动：绝对位移够大 + 明显比水平大
      return ay > MIN_VERTICAL_DELTA && ay >= ax * AXIS_RATIO
    },
    onPanResponderTerminationRequest: () => false,
    onPanResponderGrant: () => {
      armedRef.current = false
    },
    onPanResponderMove: (_e: GestureResponderEvent, gs: PanResponderGestureState) => {
      if (disabledRef.current || busyRef.current) return
      const dy = gs.dy
      const ay = Math.abs(dy)
      const ax = Math.abs(gs.dx)
      if (ay <= ax * AXIS_RATIO) return
      // 1:1 跟手（与歌词翻页手感一致，不做阻尼拖拽）
      translateY.setValue(dy)
      // 拖得越远缩得越小（最多缩到 0.94），制造「整页被推走」的层次感
      const ratio = Math.min(1, ay / 320)
      scale.setValue(1 - ratio * 0.06)
      opacity.setValue(1 - ratio * 0.22)
      // 越过阈值只提示一次，避免连续震动
      const threshold = getSwipeThreshold(screenHeight())
      if (ay >= threshold && !armedRef.current) {
        armedRef.current = true
        haptic.select()
      } else if (ay < threshold && armedRef.current) {
        armedRef.current = false
      }
    },
    onPanResponderRelease: (_e: GestureResponderEvent, gs: PanResponderGestureState) => {
      const ay = Math.abs(gs.dy)
      const ax = Math.abs(gs.dx)
      const threshold = getSwipeThreshold(screenHeight())
      if (disabledRef.current || ay < threshold || ay < ax * AXIS_RATIO) {
        reset()
        return
      }
      busyRef.current = true
      armedRef.current = false
      const isNext = gs.dy < 0
      run(isNext ? 'next' : 'prev', isNext ? -screenHeight() * 0.32 : screenHeight() * 0.32)
    },
    onPanResponderTerminate: () => {
      reset()
    },
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }), [run, reset, translateY, scale, opacity])

  return (
    <Animated.View
      style={[styles.container, { transform: [{ translateY }, { scale }], opacity }]}
      {...panResponder.panHandlers}
    >
      {children}
    </Animated.View>
  )
}

/** 运行时取屏幕高度 */
const screenHeight = () => Dimensions.get('window').height

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
})
