import { memo, useCallback, useMemo, useRef, useState } from 'react'
import { Animated, Dimensions, Easing, PanResponder, StyleSheet, View, type GestureResponderEvent, type PanResponderGestureState } from 'react-native'
import Lyric from '@/screens/PlayDetail/Vertical/Lyric'
import { haptic } from '@/utils/haptics'

/**
 * 右滑展开全屏歌词。
 *
 * 播放页原本右滑会被外层 PagerView 抢走切成「我的」Tab；
 * 现在 Main 已对播放页禁用横滑，由此组件接管：
 * - 右滑超过阈值 → 歌词页从右侧滑入并铺满
 * - 在歌词页上左滑（或点返回）→ 收回
 */
const SCREEN_WIDTH = Dimensions.get('window').width
/** 触发展开的最小水平位移 */
const OPEN_THRESHOLD = 60
/** 判定为「横向」的轴比 */
const AXIS_RATIO = 1.2

export default memo(({ disabled = false }: { disabled?: boolean }) => {
  const [opened, setOpened] = useState(false)
  const translateX = useRef(new Animated.Value(SCREEN_WIDTH)).current
  const draggingRef = useRef(false)
  const disabledRef = useRef(disabled)
  disabledRef.current = disabled

  const open = useCallback(() => {
    haptic.tap()
    setOpened(true)
    Animated.timing(translateX, {
      toValue: 0,
      duration: 260,
      easing: Easing.out(Easing.cubic),
      useNativeDriver: true,
    }).start()
  }, [translateX])

  const close = useCallback(() => {
    Animated.timing(translateX, {
      toValue: SCREEN_WIDTH,
      duration: 220,
      easing: Easing.out(Easing.cubic),
      useNativeDriver: true,
    }).start(() => { setOpened(false) })
  }, [translateX])

  /** 只在「未展开」时监听右滑；展开后由歌词层的左滑监听负责收回 */
  const openResponder = useMemo(() => PanResponder.create({
    onStartShouldSetPanResponder: () => false,
    onMoveShouldSetPanResponder: (_e: GestureResponderEvent, gs: PanResponderGestureState) => {
      if (disabledRef.current || opened) return false
      const ax = Math.abs(gs.dx)
      const ay = Math.abs(gs.dy)
      // 仅接管明确的右滑
      return gs.dx > 16 && ax >= ay * AXIS_RATIO
    },
    onPanResponderRelease: (_e: GestureResponderEvent, gs: PanResponderGestureState) => {
      const ax = Math.abs(gs.dx)
      const ay = Math.abs(gs.dy)
      if (gs.dx >= OPEN_THRESHOLD && ax >= ay * AXIS_RATIO) open()
    },
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }), [open, opened])

  const closeResponder = useMemo(() => PanResponder.create({
    onStartShouldSetPanResponder: () => false,
    onMoveShouldSetPanResponder: (_e: GestureResponderEvent, gs: PanResponderGestureState) => {
      if (!opened) return false
      const ax = Math.abs(gs.dx)
      const ay = Math.abs(gs.dy)
      return gs.dx < -16 && ax >= ay * AXIS_RATIO
    },
    onPanResponderMove: (_e: GestureResponderEvent, gs: PanResponderGestureState) => {
      if (!draggingRef.current) draggingRef.current = true
      // 跟手：只允许往右拖（dx<0 时向右位移）
      const next = Math.min(SCREEN_WIDTH, Math.max(0, -gs.dx))
      translateX.setValue(next)
    },
    onPanResponderRelease: (_e: GestureResponderEvent, gs: PanResponderGestureState) => {
      draggingRef.current = false
      const ax = Math.abs(gs.dx)
      if (ax > OPEN_THRESHOLD) {
        haptic.tap()
        close()
      } else {
        // 回弹
        Animated.spring(translateX, { toValue: 0, friction: 8, tension: 90, useNativeDriver: true }).start()
      }
    },
    onPanResponderTerminate: () => {
      draggingRef.current = false
      Animated.spring(translateX, { toValue: 0, friction: 8, tension: 90, useNativeDriver: true }).start()
    },
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }), [opened, close, translateX])

  return (
    <>
      {/* 未展开：铺一层透明层只用来捕获右滑（不拦截点击） */}
      {!opened ? <View style={StyleSheet.absoluteFill} pointerEvents="box-none" {...openResponder.panHandlers} /> : null}

      {/* 歌词层：展开后才渲染，节省歌词列表开销 */}
      {opened
        ? (
            <Animated.View style={[styles.lyricLayer, { transform: [{ translateX }] }]} {...closeResponder.panHandlers}>
              <View style={styles.lyricInner}>
                <Lyric />
              </View>
              {/* 右上角关闭提示 */}
              <View style={styles.hintBar} pointerEvents="none">
                <View style={styles.hintPill} />
              </View>
            </Animated.View>
          )
        : null}
    </>
  )
})

const styles = StyleSheet.create({
  lyricLayer: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: 'rgba(12,10,10,0.98)',
    zIndex: 100,
  },
  lyricInner: {
    flex: 1,
  },
  hintBar: {
    position: 'absolute',
    top: 6,
    left: 0,
    right: 0,
    alignItems: 'center',
  },
  hintPill: {
    width: 36,
    height: 4,
    borderRadius: 2,
    backgroundColor: 'rgba(255,255,255,0.25)',
  },
})
