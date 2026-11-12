import { memo, useCallback, useMemo, useRef, useState } from 'react'
import { Animated, Dimensions, Easing, PanResponder, StyleSheet, View, type GestureResponderEvent, type PanResponderGestureState } from 'react-native'
import Lyric from '@/screens/PlayDetail/Vertical/Lyric'
import { haptic } from '@/utils/haptics'

/**
 * 右滑展开全屏歌词（通过 hook 把手势挂到播放页根容器上）。
 *
 * 关键点：**不额外渲染全屏捕获层**。
 * 之前用 absoluteFill 的透明 View 捕获手势，会盖住下方收藏/音质等按钮，
 * 导致按钮全部点不动。这里改为返回 panHandlers，由播放页根容器直接挂载，
 * 配合 onStart=false + onMove 判定的方式，点击仍能落到按钮上。
 */
const SCREEN_WIDTH = Dimensions.get('window').width
const OPEN_THRESHOLD = 70
const AXIS_RATIO = 1.1

export interface LyricOverlayController {
  /** 挂到播放页根容器的手势 */
  panHandlers: ReturnType<typeof PanResponder.create>['panHandlers']
  /** 是否已展开（播放页可据此隐藏底部栏等） */
  opened: boolean
}

/** 右滑手势 + 歌词层的组合 hook */
export const useLyricOverlay = ({ disabled = false }: { disabled?: boolean } = {}) => {
  const [opened, setOpened] = useState(false)
  const translateX = useRef(new Animated.Value(SCREEN_WIDTH)).current
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

  const openResponder = useMemo(() => PanResponder.create({
    // 不抢点击：按钮照常响应
    onStartShouldSetPanResponder: () => false,
    onMoveShouldSetPanResponder: (_e: GestureResponderEvent, gs: PanResponderGestureState) => {
      if (disabledRef.current || opened) return false
      const ax = Math.abs(gs.dx)
      const ay = Math.abs(gs.dy)
      // 明确右滑才接管
      return gs.dx > 24 && ax > ay * AXIS_RATIO
    },
    onPanResponderMove: (_e: GestureResponderEvent, gs: PanResponderGestureState) => {
      translateX.setValue(Math.max(0, Math.min(SCREEN_WIDTH, SCREEN_WIDTH - gs.dx)))
    },
    onPanResponderRelease: (_e: GestureResponderEvent, gs: PanResponderGestureState) => {
      if (gs.dx >= OPEN_THRESHOLD) open()
      else Animated.spring(translateX, { toValue: SCREEN_WIDTH, friction: 8, tension: 90, useNativeDriver: true }).start()
    },
    onPanResponderTerminate: () => {
      Animated.spring(translateX, { toValue: SCREEN_WIDTH, friction: 8, tension: 90, useNativeDriver: true }).start()
    },
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }), [open, translateX, opened])

  const closeResponder = useMemo(() => PanResponder.create({
    onStartShouldSetPanResponder: () => false,
    onMoveShouldSetPanResponder: (_e: GestureResponderEvent, gs: PanResponderGestureState) => {
      if (!opened) return false
      const ax = Math.abs(gs.dx)
      const ay = Math.abs(gs.dy)
      return gs.dx < -12 && ax > ay * AXIS_RATIO
    },
    onPanResponderMove: (_e: GestureResponderEvent, gs: PanResponderGestureState) => {
      translateX.setValue(Math.max(0, Math.min(SCREEN_WIDTH, -gs.dx)))
    },
    onPanResponderRelease: (_e: GestureResponderEvent, gs: PanResponderGestureState) => {
      if (-gs.dx > OPEN_THRESHOLD) { haptic.tap(); close() } else Animated.spring(translateX, { toValue: 0, friction: 8, tension: 90, useNativeDriver: true }).start()
    },
    onPanResponderTerminate: () => {
      Animated.spring(translateX, { toValue: 0, friction: 8, tension: 90, useNativeDriver: true }).start()
    },
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }), [opened, close, translateX])

  const handlers = opened ? closeResponder : openResponder

  return {
    panHandlers: handlers.panHandlers,
    opened,
    translateX,
  }
}

/**
 * 全屏歌词层（由播放页按需渲染在根容器之上）。
 * 不渲染时返回 null，不会挡住任何按钮。
 */
export const LyricLayer = memo(({ translateX, onCloseHandlers }: {
  translateX: Animated.Value
  onCloseHandlers: ReturnType<typeof PanResponder.create>['panHandlers']
}) => {
  return (
    <Animated.View style={[styles.lyricLayer, { transform: [{ translateX }] }]}>
      <View style={styles.lyricInner} {...onCloseHandlers}>
        <Lyric />
      </View>
      <View style={styles.hintBar} pointerEvents="none">
        <View style={styles.hintPill} />
      </View>
    </Animated.View>
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
