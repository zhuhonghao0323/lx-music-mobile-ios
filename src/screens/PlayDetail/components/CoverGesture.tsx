import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { Animated, Easing, PanResponder, StyleSheet, View, type GestureResponderEvent, type PanResponderGestureState } from 'react-native'
import Text from '@/components/common/Text'
import { FAVORITE_COLOR } from './FavoriteIcon'
import { triggerFavoriteDockAnimation } from './FavoriteBtn'
import { addToFavorite, getPlayMusicInfo, isMusicFavorited, removeFromFavorite } from '@/core/favorite'
import { playNext, playPrev } from '@/core/player/player'
import { markTimeoutExitInteraction } from '@/core/player/timeoutExit'
import { useI18n } from '@/lang'
import { scaleSizeW } from '@/utils/pixelRatio'

/** 轻滑触发切歌的最小距离 */
const SWIPE_THRESHOLD = 42
/** 轻滑判定为「竖直」的轴比（斜向一律不处理） */
const AXIS_RATIO = 1.6
/** 进入收藏模式所需的长按时长 */
const LONG_PRESS_DELAY = 1000
/** 收藏模式内拖动多少即给出提示（不触发动作） */
const HINT_DRAG = 28
/** 收藏模式内拖动多少才真正执行动作 */
const ACTION_DRAG = 88

type SwipeAction = 'next' | 'prev' | null
type Mode = 'idle' | 'favorite'

/**
 * 判定普通模式的轻滑：只有足够「竖直」的上划/下滑才切歌，斜上/斜下不处理。
 */
const classifySwipe = (dx: number, dy: number): SwipeAction => {
  const ax = Math.abs(dx)
  const ay = Math.abs(dy)
  if (Math.max(ax, ay) < SWIPE_THRESHOLD) return null
  if (ay <= ax * AXIS_RATIO) return null
  return dy < 0 ? 'next' : 'prev'
}

/**
 * 播放界面封面手势容器：
 * - 普通模式：轻滑上=下一曲、轻滑下=上一曲；斜向无动作
 * - 长按 1 秒：封面 3D 悬浮进入收藏模式，卡片上下方居中显示操作按钮
 *     · 已收藏：只显示「取消收藏」；下滑一小段即提示「已收藏」并取消收藏，无飞入动画
 *     · 未收藏：不显示「取消收藏」；上划一小段提示「未收藏」
 *     · 松开手指自动退出悬浮
 */
export default ({ children, width, height }: {
  children: React.ReactNode
  width: number
  height: number
}) => {
  const t = useI18n()
  const pan = useRef(new Animated.ValueXY()).current
  const fade = useRef(new Animated.Value(1)).current
  const lift = useRef(new Animated.Value(0)).current
  const actionTop = useRef(new Animated.Value(0)).current
  const actionBottom = useRef(new Animated.Value(0)).current
  const shake = useRef(new Animated.Value(0)).current
  const [mode, setMode] = useState<Mode>('idle')
  const [favorited, setFavorited] = useState(false)
  const [dragHint, setDragHint] = useState<string | null>(null)
  const [resultTip, setResultTip] = useState<string | null>(null)

  const modeRef = useRef<Mode>('idle')
  const favRef = useRef(false)
  const busyRef = useRef(false)
  const longPressTimer = useRef<ReturnType<typeof setTimeout> | null>(null)
  const startPoint = useRef({ x: 0, y: 0 })
  const dragHandledRef = useRef(false)
  const hintRef = useRef<string | null>(null)
  const tipTimer = useRef<ReturnType<typeof setTimeout> | null>(null)

  const cancelLongPress = useCallback(() => {
    if (longPressTimer.current) { clearTimeout(longPressTimer.current); longPressTimer.current = null }
  }, [])

  const setModeBoth = useCallback((m: Mode) => {
    modeRef.current = m
    setMode(m)
  }, [])

  // 收藏状态：进入悬浮前先同步一次，保证按钮显隐正确
  useEffect(() => {
    const info = getPlayMusicInfo()
    if (!info) { setFavorited(false); favRef.current = false; return }
    void isMusicFavorited(info).then(v => { setFavorited(v); favRef.current = v })
  }, [])

  const showResultTip = useCallback((text: string) => {
    if (tipTimer.current) clearTimeout(tipTimer.current)
    setResultTip(text)
    tipTimer.current = setTimeout(() => { setResultTip(null) }, 1500)
  }, [])

  const triggerDockAnimation = useCallback((direction: 'add' | 'remove') => {
    void triggerFavoriteDockAnimation(direction)
  }, [])

  /** 心形晃动 + 变红的「已收藏」反馈（用于没有飞入动画的场景） */
  const playHeartShake = useCallback(() => {
    shake.setValue(0)
    Animated.sequence([
      Animated.timing(shake, { toValue: 1, duration: 70, useNativeDriver: false }),
      Animated.timing(shake, { toValue: -1, duration: 70, useNativeDriver: false }),
      Animated.timing(shake, { toValue: 0.6, duration: 60, useNativeDriver: false }),
      Animated.timing(shake, { toValue: -0.4, duration: 60, useNativeDriver: false }),
      Animated.spring(shake, { toValue: 0, friction: 4, tension: 140, useNativeDriver: false }),
    ]).start()
  }, [shake])

  // ---------- 进入 / 退出悬浮 ----------
  const enterFavoriteMode = useCallback(() => {
    if (busyRef.current || modeRef.current == 'favorite') return
    setModeBoth('favorite')
    pan.setValue({ x: 0, y: 0 })
    setDragHint(null)
    hintRef.current = null
    // 悬浮时刷新一次收藏态，避免状态滞后导致按钮显隐错误
    const info = getPlayMusicInfo()
    if (info) {
      void isMusicFavorited(info).then(v => { setFavorited(v); favRef.current = v })
    }
    Animated.parallel([
      Animated.spring(lift, { toValue: 1, friction: 6, tension: 90, useNativeDriver: false }),
      // 按钮从卡片边缘滑入：上按钮来自上方、下按钮来自下方
      Animated.spring(actionTop, { toValue: 1, friction: 7, tension: 110, useNativeDriver: false }),
      Animated.spring(actionBottom, { toValue: 1, friction: 7, tension: 110, useNativeDriver: false }),
    ]).start()
  }, [lift, actionTop, actionBottom, pan, setModeBoth])

  const exitFavoriteMode = useCallback((run?: () => void) => {
    Animated.parallel([
      Animated.timing(lift, { toValue: 0, duration: 240, easing: Easing.out(Easing.cubic), useNativeDriver: false }),
      Animated.timing(actionTop, { toValue: 0, duration: 180, useNativeDriver: false }),
      Animated.timing(actionBottom, { toValue: 0, duration: 180, useNativeDriver: false }),
      Animated.timing(pan, { toValue: { x: 0, y: 0 }, duration: 240, easing: Easing.out(Easing.cubic), useNativeDriver: false }),
    ]).start(() => {
      setModeBoth('idle')
      setDragHint(null)
      hintRef.current = null
      run?.()
    })
  }, [lift, actionTop, actionBottom, pan, setModeBoth])

  /** 已收藏时下滑：直接取消收藏，不播放飞入动画，仅给文字与心形反馈 */
  const doRemoveWithoutFly = useCallback(() => {
    const info = getPlayMusicInfo()
    if (!info) return
    busyRef.current = true
    void removeFromFavorite(info).then(() => {
      setFavorited(false)
      favRef.current = false
      showResultTip(t('favorite_removed'))
      playHeartShake()
      exitFavoriteMode(() => { busyRef.current = false })
    })
  }, [showResultTip, playHeartShake, exitFavoriteMode, t])

  /** 未收藏时下滑：加入收藏并播放收进心形的动画 */
  const doAddWithFly = useCallback(() => {
    const info = getPlayMusicInfo()
    if (!info) return
    busyRef.current = true
    Animated.parallel([
      Animated.timing(fade, { toValue: 0, duration: 200, easing: Easing.out(Easing.cubic), useNativeDriver: false }),
      Animated.timing(lift, { toValue: 0.2, duration: 200, useNativeDriver: false }),
      Animated.timing(actionTop, { toValue: 0, duration: 160, useNativeDriver: false }),
      Animated.timing(actionBottom, { toValue: 0, duration: 160, useNativeDriver: false }),
    ]).start(() => {
      pan.setValue({ x: 0, y: 0 })
      lift.setValue(0)
      setModeBoth('idle')
      setDragHint(null)
      hintRef.current = null
      void addToFavorite(info).then(() => {
        setFavorited(true)
        favRef.current = true
        showResultTip(t('favorite_added'))
        triggerDockAnimation('add')
        playHeartShake()
      })
      Animated.timing(fade, { toValue: 1, duration: 240, easing: Easing.out(Easing.cubic), useNativeDriver: false }).start(() => {
        busyRef.current = false
      })
    })
  }, [pan, fade, lift, actionTop, actionBottom, setModeBoth, showResultTip, triggerDockAnimation, playHeartShake, t])

  // ---------- 普通切歌 ----------
  const runSwipe = useCallback((action: Exclude<SwipeAction, null>) => {
    busyRef.current = true
    const flyY = action == 'next' ? -height * 0.85 : height * 0.85
    Animated.parallel([
      Animated.timing(pan, { toValue: { x: 0, y: flyY }, duration: 200, easing: Easing.out(Easing.cubic), useNativeDriver: false }),
      Animated.timing(fade, { toValue: 0, duration: 200, useNativeDriver: false }),
    ]).start(() => {
      if (action == 'next') void playNext()
      else void playPrev()
      pan.setValue({ x: 0, y: 0 })
      Animated.timing(fade, { toValue: 1, duration: 260, easing: Easing.out(Easing.cubic), useNativeDriver: false }).start(() => {
        busyRef.current = false
      })
    })
  }, [pan, fade, height])

  const snapBack = useCallback(() => {
    Animated.parallel([
      Animated.spring(pan.x, { toValue: 0, friction: 7, tension: 90, useNativeDriver: false }),
      Animated.spring(pan.y, { toValue: 0, friction: 7, tension: 90, useNativeDriver: false }),
    ]).start()
  }, [pan])

  // ---------- PanResponder ----------
  const onPanResponderRelease = useCallback((_e: GestureResponderEvent, gs: PanResponderGestureState) => {
    if (longPressTimer.current) { clearTimeout(longPressTimer.current); longPressTimer.current = null }
    markTimeoutExitInteraction()

    if (modeRef.current == 'favorite') {
      const dy = gs.dy
      // 幅度不足：直接退出悬浮，不产生任何动作
      if (Math.abs(dy) < ACTION_DRAG) {
        dragHandledRef.current = true
        exitFavoriteMode()
        return
      }
      dragHandledRef.current = true
      setDragHint(null); hintRef.current = null
      if (dy > 0) {
        // 下滑：已收藏->取消收藏（无飞入）；未收藏->加入收藏（有飞入）
        if (favRef.current) doRemoveWithoutFly()
        else doAddWithFly()
      } else {
        // 上滑：已收藏时无意义，保持悬浮让用户下滑取消；未收藏时提示未收藏
        if (!favRef.current) {
          showResultTip(t('favorite_not_collected'))
          snapBack()
        } else {
          showResultTip(t('favorite_already_collected'))
          snapBack()
        }
      }
      return
    }

    // 普通模式
    setModeBoth('idle')
    const action = classifySwipe(gs.dx, gs.dy)
    if (!action || busyRef.current) { snapBack(); return }
    runSwipe(action)
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [exitFavoriteMode, doAddWithFly, doRemoveWithoutFly, runSwipe, snapBack, setModeBoth, showResultTip, t])

  const panResponder = useMemo(() => PanResponder.create({
    onStartShouldSetPanResponder: () => false,
    onMoveShouldSetPanResponder: (_e, gs) => {
      if (busyRef.current) return false
      const ax = Math.abs(gs.dx)
      const ay = Math.abs(gs.dy)
      return modeRef.current == 'favorite' ? true : ay > 4 && ay >= ax * 0.7
    },
    onPanResponderTerminationRequest: () => false,
    onPanResponderGrant: (e: GestureResponderEvent) => {
      markTimeoutExitInteraction()
      pan.stopAnimation()
      pan.setValue({ x: 0, y: 0 })
      startPoint.current = { x: e.nativeEvent.pageX, y: e.nativeEvent.pageY }
      dragHandledRef.current = false
    },
    onPanResponderMove: Animated.event(
      [null, { dx: pan.x, dy: pan.y }],
      {
        useNativeDriver: false,
        listener: (...args: any[]) => {
          const gs = args[1] as PanResponderGestureState
          if (modeRef.current != 'favorite') return
          const dy = gs.dy
          let label: string | null = null
          if (dy > HINT_DRAG) {
            label = favRef.current
              ? `↓  ${t('favorite_option_remove')}`
              : `↓  ${t('favorite_option_add')}`
          } else if (dy < -HINT_DRAG) {
            label = favRef.current ? t('favorite_already_collected') : t('favorite_not_collected')
          }
          if (label != hintRef.current) { hintRef.current = label; setDragHint(label) }
        },
      },
    ),
    onPanResponderRelease,
    onPanResponderTerminate: () => {
      cancelLongPress()
      if (modeRef.current == 'favorite') exitFavoriteMode()
      else { setModeBoth('idle'); snapBack() }
    },
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }), [pan, onPanResponderRelease, exitFavoriteMode, snapBack, cancelLongPress, t, setModeBoth])

  // 长按检测：用 touch 事件，避免与 PagerView 横向翻页抢占 responder
  const onTouchStart = useCallback((e: GestureResponderEvent) => {
    if (busyRef.current || modeRef.current == 'favorite') return
    const { pageX, pageY } = e.nativeEvent
    startPoint.current = { x: pageX, y: pageY }
    cancelLongPress()
    longPressTimer.current = setTimeout(() => { enterFavoriteMode() }, LONG_PRESS_DELAY)
  }, [enterFavoriteMode, cancelLongPress])

  const onTouchMove = useCallback((e: GestureResponderEvent) => {
    if (!longPressTimer.current) return
    const { pageX, pageY } = e.nativeEvent
    if (Math.abs(pageX - startPoint.current.x) > 10 || Math.abs(pageY - startPoint.current.y) > 10) cancelLongPress()
  }, [cancelLongPress])

  const onTouchEnd = useCallback(() => {
    cancelLongPress()
    // 悬浮后松手即取消悬浮
    if (modeRef.current == 'favorite' && !dragHandledRef.current) {
      exitFavoriteMode()
    }
  }, [cancelLongPress, exitFavoriteMode])

  // 3D 悬浮变换
  const coverTransform = [
    ...pan.getTranslateTransform(),
    { scale: lift.interpolate({ inputRange: [0, 1], outputRange: [1, 1.06] }) },
    { rotateX: lift.interpolate({ inputRange: [0, 1], outputRange: ['0deg', '8deg'] }) },
  ]
  const coverShadow = lift.interpolate({ inputRange: [0, 1], outputRange: [0, 0.42] })
  const shakeX = shake.interpolate({ inputRange: [-1, 0, 1], outputRange: [-7, 0, 7] })
  const shakeScale = shake.interpolate({ inputRange: [-1, 0, 1], outputRange: [1.12, 1, 1.12] })

  const topAction = favorited
    ? { icon: '♥', label: t('favorite_option_remove') }
    : null

  return (
    <View style={styles.container} collapsable={false}>
      <Animated.View
        pointerEvents="none"
        style={[styles.shadow, { width: width * 0.9, height: height * 0.16, bottom: -height * 0.02, opacity: coverShadow }]}
      />

      {/* 悬浮时卡片上方的操作按钮（居中） */}
      {
        mode == 'favorite' && topAction
          ? <Animated.View
              pointerEvents="none"
              style={[styles.actionBar, styles.actionTop, {
                opacity: actionTop,
                transform: [
                  { translateY: actionTop.interpolate({ inputRange: [0, 1], outputRange: [14, 0] }) },
                  { scale: actionTop.interpolate({ inputRange: [0, 1], outputRange: [0.86, 1] }) },
                  { translateX: shakeX },
                  { scale: shakeScale },
                ],
              }]}
            >
              <View style={[styles.actionPill, styles.actionRemove]}>
                <Text style={[styles.actionGlyph, { color: FAVORITE_COLOR }]}>{topAction.icon}</Text>
                <Text style={styles.actionLabel}>{topAction.label}</Text>
              </View>
            </Animated.View>
          : null
      }

      <Animated.View
        {...panResponder.panHandlers}
        onTouchStart={onTouchStart}
        onTouchMove={onTouchMove}
        onTouchEnd={onTouchEnd}
        onTouchCancel={onTouchEnd}
        style={[styles.gesture, { opacity: fade, transform: coverTransform }]}
      >
        {children}
      </Animated.View>

      {/* 悬浮时卡片下方的操作按钮（居中） */}
      {
        mode == 'favorite'
          ? <Animated.View
              pointerEvents="none"
              style={[styles.actionBar, styles.actionBottom, {
                opacity: actionBottom,
                transform: [
                  { translateY: actionBottom.interpolate({ inputRange: [0, 1], outputRange: [-14, 0] }) },
                  { scale: actionBottom.interpolate({ inputRange: [0, 1], outputRange: [0.86, 1] }) },
                  { translateX: shakeX },
                  { scale: shakeScale },
                ],
              }]}
            >
              <View style={[styles.actionPill, favorited ? styles.actionRemove : styles.actionAdd]}>
                <Text style={[styles.actionGlyph, { color: favorited ? FAVORITE_COLOR : '#ffd0dc' }]}>{favorited ? '♥' : '♡'}</Text>
                <Text style={styles.actionLabel}>{favorited ? t('favorite_option_remove') : t('favorite_option_add')}</Text>
              </View>
            </Animated.View>
          : null
      }

      {dragHint ? <View style={styles.hint} pointerEvents="none"><Text size={13} color="#ffffff">{dragHint}</Text></View> : null}
      {resultTip ? <View style={styles.hint} pointerEvents="none"><Text size={13} color={FAVORITE_COLOR}>{resultTip}</Text></View> : null}
    </View>
  )
}

const styles = StyleSheet.create({
  container: { justifyContent: 'center', alignItems: 'center' },
  gesture: { justifyContent: 'center', alignItems: 'center' },
  shadow: { position: 'absolute', borderRadius: 100, backgroundColor: 'rgba(0, 0, 0, 0.55)' },
  actionBar: {
    position: 'absolute',
    left: 0,
    right: 0,
    alignItems: 'center',
    justifyContent: 'center',
  },
  actionTop: { top: -scaleSizeW(54) },
  actionBottom: { bottom: -scaleSizeW(54) },
  actionPill: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: scaleSizeW(8),
    paddingHorizontal: scaleSizeW(18),
    paddingVertical: scaleSizeW(10),
    borderRadius: scaleSizeW(24),
    borderWidth: StyleSheet.hairlineWidth,
    shadowColor: 'rgba(6, 10, 30, 0.5)',
    shadowOffset: { width: 0, height: 6 },
    shadowOpacity: 0.4,
    shadowRadius: 14,
  },
  actionAdd: { backgroundColor: 'rgba(255, 77, 109, 0.92)', borderColor: 'rgba(255, 190, 205, 0.9)' },
  actionRemove: { backgroundColor: 'rgba(28, 34, 58, 0.88)', borderColor: 'rgba(255, 255, 255, 0.4)' },
  actionGlyph: { fontSize: scaleSizeW(17), fontWeight: 'bold' },
  actionLabel: { color: '#ffffff', fontSize: scaleSizeW(13), fontWeight: '600' },
  hint: {
    position: 'absolute',
    top: 8,
    paddingHorizontal: 12,
    paddingVertical: 5,
    borderRadius: 14,
    backgroundColor: 'rgba(0, 0, 0, 0.62)',
  },
})
