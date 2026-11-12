import { memo, useCallback, useMemo, useRef, useState } from 'react'
import { Animated, Dimensions, Easing, PanResponder, StyleSheet, View, type GestureResponderEvent, type PanResponderGestureState } from 'react-native'
import Lyric from '@/screens/PlayDetail/Vertical/Lyric'
import { haptic } from '@/utils/haptics'

/**
 * 右滑展开全屏歌词。
 *
 * 手势策略：
 * - 透明层用 onStartShouldSetPanResponder=true 抢占开始，
 *   然后在移动阶段判定：是横滑才接管（开始拖拽 translateX），否则立即释放
 *   并把事件放回，保证不影响上下滑切歌和点击。
 * - 展开后：歌词层自己接管左滑收回。
 */
const SCREEN_WIDTH = Dimensions.get('window').width
const OPEN_THRESHOLD = 70
const AXIS_RATIO = 1.1

export default memo(({ disabled = false }: { disabled?: boolean }) => {
  const [opened, setOpened] = useState(false)
  const translateX = useRef(new Animated.Value(SCREEN_WIDTH)).current
  const capturingRef = useRef(false)
  const disabledRef = useRef(disabled)
  disabledRef.current = disabled

  const open = useCallback(() => {
    haptic.tap()
    setOpened(true)
    Animated.timing(translateX, {
      toValue: 0,
      duration: 240,
      easing: Easing.out(Easing.cubic),
      useNativeDriver: true,
    }).start()
  }, [translateX])

  const close = useCallback(() => {
    Animated.timing(translateX, {
      toValue: SCREEN_WIDTH,
      duration: 200,
      easing: Easing.out(Easing.cubic),
      useNativeDriver: true,
    }).start(() => { setOpened(false) })
  }, [translateX])

  /** 未展开时的右滑捕获层：onStart 不抢点击，onMove 判定明确右滑才接管 */
  const openResponder = useMemo(() => PanResponder.create({
    onStartShouldSetPanResponder: () => false,
    onMoveShouldSetPanResponder: (_e: GestureResponderEvent, gs: PanResponderGestureState) => {
      if (disabledRef.current) return false
      const ax = Math.abs(gs.dx)
      const ay = Math.abs(gs.dy)
      if (gs.dx > 24 && ax > ay * AXIS_RATIO) {
        return true
      }
      return false
    },
    onPanResponderGrant: () => {
      capturingRef.current = true
    },
    onPanResponderMove: (_e: GestureResponderEvent, gs: PanResponderGestureState) => {
      const offset = Math.max(0, Math.min(SCREEN_WIDTH, SCREEN_WIDTH - gs.dx))
      translateX.setValue(offset)
    },
    onPanResponderRelease: (_e: GestureResponderEvent, gs: PanResponderGestureState) => {
      capturingRef.current = false
      if (gs.dx >= OPEN_THRESHOLD) {
        open()
      } else {
        Animated.spring(translateX, { toValue: SCREEN_WIDTH, friction: 8, tension: 90, useNativeDriver: true }).start()
      }
    },
    onPanResponderTerminate: () => {
      capturingRef.current = false
      Animated.spring(translateX, { toValue: SCREEN_WIDTH, friction: 8, tension: 90, useNativeDriver: true }).start()
    },
    onPanResponderTerminationRequest: () => true,
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }), [open, translateX])

  /** 展开后歌词层的左滑收回 */
  const closeResponder = useMemo(() => PanResponder.create({
    onStartShouldSetPanResponder: () => false,
    onMoveShouldSetPanResponder: (_e: GestureResponderEvent, gs: PanResponderGestureState) => {
      if (!opened) return false
      const ax = Math.abs(gs.dx)
      const ay = Math.abs(gs.dy)
      return gs.dx < -12 && ax > ay * AXIS_RATIO
    },
    onPanResponderMove: (_e: GestureResponderEvent, gs: PanResponderGestureState) => {
      const offset = Math.max(0, Math.min(SCREEN_WIDTH, -gs.dx))
      translateX.setValue(offset)
    },
    onPanResponderRelease: (_e: GestureResponderEvent, gs: PanResponderGestureState) => {
      if (-gs.dx > OPEN_THRESHOLD) {
        haptic.tap()
        close()
      } else {
        Animated.spring(translateX, { toValue: 0, friction: 8, tension: 90, useNativeDriver: true }).start()
      }
    },
    onPanResponderTerminate: () => {
      Animated.spring(translateX, { toValue: 0, friction: 8, tension: 90, useNativeDriver: true }).start()
    },
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }), [opened, close, translateX])

  return (
    <>
      {/* 未展开：透明捕获层（最高 zIndex），只接管明确右滑 */}
      {!opened
        ? <View style={[StyleSheet.absoluteFill, styles.captureLayer]} {...openResponder.panHandlers} />
        : null}

      {/* 歌词层：从右侧滑入 */}
      {opened
        ? (
            <Animated.View style={[styles.lyricLayer, { transform: [{ translateX }] }]}>
              <View style={styles.lyricInner} {...closeResponder.panHandlers}>
                <Lyric />
              </View>
              {/* 顶部提示 */}
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
  captureLayer: {
    zIndex: 90,
  },
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
