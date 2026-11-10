import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { Animated, Easing, PanResponder, StyleSheet, View, type GestureResponderEvent, type PanResponderGestureState } from 'react-native'
import Text from '@/components/common/Text'
import { FAVORITE_COLOR } from './FavoriteIcon'
import { triggerFavoriteDockAnimation } from './FavoriteBtn'
import { addToFavorite, getPlayMusicInfo, isMusicFavorited, removeFromFavorite, toggleFavorite } from '@/core/favorite'
import { markTimeoutExitInteraction } from '@/core/player/timeoutExit'
import { useI18n } from '@/lang'
import { scaleSizeW } from '@/utils/pixelRatio'
import { haptic } from '@/utils/haptics'

/** 进入收藏模式所需的长按时长 */
const LONG_PRESS_DELAY = 1000
/** 收藏模式内拖动多少即给出提示 */
const HINT_DRAG = 28
/** 收藏模式内拖动多少才真正执行动作 */
const ACTION_DRAG = 88
/** 悬浮状态的安全超时：即使收不到抬手事件也能自动恢复 */
const LIFT_SAFETY_TIMEOUT = 8000
/** 双击间隔阈值（ms） */
const DOUBLE_TAP_INTERVAL = 300
/** 双击两次按下之间的最大位移，超出则不算双击 */
const DOUBLE_TAP_SLOP = 24

type Mode = 'idle' | 'favorite'

/**
 * 播放界面封面手势容器：
 * - 普通模式：轻滑上=下一曲、轻滑下=上一曲；**只做垂直位移，不左右晃动**
 * - 长按 1 秒：封面 3D 悬浮，上下方居中显示操作按钮
 *     · 下滑 = 加入收藏（已收藏则提示「已存在」）
 *     · 上滑 = 取消收藏（未收藏则提示「未收藏」）
 *     · 松手 / 点击任意位置 / 安全超时 都会恢复正常状态
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
  const [mode, setMode] = useState<Mode>('idle')
  const [favorited, setFavorited] = useState(false)
  const [dragHint, setDragHint] = useState<string | null>(null)
  const [resultTip, setResultTip] = useState<string | null>(null)

  const modeRef = useRef<Mode>('idle')
  const favRef = useRef(false)
  const busyRef = useRef(false)
  const longPressTimer = useRef<ReturnType<typeof setTimeout> | null>(null)
  const safetyTimer = useRef<ReturnType<typeof setTimeout> | null>(null)
  const startPoint = useRef({ x: 0, y: 0 })
  const hintRef = useRef<string | null>(null)
  const tipTimer = useRef<ReturnType<typeof setTimeout> | null>(null)
  const lastTapRef = useRef<{ time: number, x: number, y: number } | null>(null)
  const doubleTapLockRef = useRef(false)

  const cancelLongPress = useCallback(() => {
    if (longPressTimer.current) { clearTimeout(longPressTimer.current); longPressTimer.current = null }
  }, [])

  const cancelSafetyTimer = useCallback(() => {
    if (safetyTimer.current) { clearTimeout(safetyTimer.current); safetyTimer.current = null }
  }, [])

  const setModeBoth = useCallback((m: Mode) => {
    modeRef.current = m
    setMode(m)
  }, [])

  // 收藏状态：进入悬浮前先同步一次，保证按钮显隐与提示文案正确
  const refreshFavorited = useCallback(() => {
    const info = getPlayMusicInfo()
    if (!info) { setFavorited(false); favRef.current = false; return }
    void isMusicFavorited(info).then(v => { setFavorited(v); favRef.current = v })
  }, [])

  useEffect(() => {
    refreshFavorited()
  }, [refreshFavorited])

  const showResultTip = useCallback((text: string) => {
    if (tipTimer.current) clearTimeout(tipTimer.current)
    setResultTip(text)
    tipTimer.current = setTimeout(() => { setResultTip(null) }, 1500)
  }, [])

  const triggerDockAnimation = useCallback((direction: 'add' | 'remove') => {
    void triggerFavoriteDockAnimation(direction)
  }, [])

  /**
   * 双击封面：切换收藏状态，并复用与拖拽封面一致的 Dock 动画
   * （加入=封面收进左下角心形，取消=从心形反向抽出）。
   */
  const handleDoubleTap = useCallback(() => {
    if (busyRef.current || doubleTapLockRef.current) return
    const info = getPlayMusicInfo()
    if (!info) return
    doubleTapLockRef.current = true
    haptic.tap()
    void toggleFavorite(info).then(result => {
      if (result) haptic.favorite()
      else haptic.unfavorite()
      setFavorited(result)
      favRef.current = result
      showResultTip(t(result ? 'favorite_added' : 'favorite_removed'))
      triggerDockAnimation(result ? 'add' : 'remove')
      setTimeout(() => { doubleTapLockRef.current = false }, 600)
    })
  }, [t, showResultTip, triggerDockAnimation])

  // ---------- 进入 / 退出悬浮 ----------
  /** 退出悬浮并确保恢复常态：所有动画值归零，任何情况下都能回到正常播放状态 */
  const exitFavoriteMode = useCallback((run?: () => void) => {
    cancelSafetyTimer()
    setDragHint(null)
    hintRef.current = null
    Animated.parallel([
      Animated.timing(lift, { toValue: 0, duration: 240, easing: Easing.out(Easing.cubic), useNativeDriver: false }),
      Animated.timing(actionTop, { toValue: 0, duration: 180, useNativeDriver: false }),
      Animated.timing(actionBottom, { toValue: 0, duration: 180, useNativeDriver: false }),
      Animated.timing(pan, { toValue: { x: 0, y: 0 }, duration: 240, easing: Easing.out(Easing.cubic), useNativeDriver: false }),
    ]).start(() => {
      // 兜底：即使动画被打断，也强制复位
      lift.setValue(0)
      actionTop.setValue(0)
      actionBottom.setValue(0)
      pan.setValue({ x: 0, y: 0 })
      setModeBoth('idle')
      run?.()
    })
  }, [lift, actionTop, actionBottom, pan, setModeBoth, cancelSafetyTimer])

  const enterFavoriteMode = useCallback(() => {
    if (busyRef.current || modeRef.current == 'favorite') return
    haptic.longPress()
    setModeBoth('favorite')
    pan.setValue({ x: 0, y: 0 })
    setDragHint(null)
    hintRef.current = null
    refreshFavorited()
    // 安全超时：即便收不到抬手事件，也强制恢复
    cancelSafetyTimer()
    safetyTimer.current = setTimeout(() => {
      if (modeRef.current == 'favorite') exitFavoriteMode()
    }, LIFT_SAFETY_TIMEOUT)
    Animated.parallel([
      Animated.spring(lift, { toValue: 1, friction: 6, tension: 90, useNativeDriver: false }),
      Animated.spring(actionTop, { toValue: 1, friction: 7, tension: 110, useNativeDriver: false }),
      Animated.spring(actionBottom, { toValue: 1, friction: 7, tension: 110, useNativeDriver: false }),
    ]).start()
  }, [lift, actionTop, actionBottom, pan, setModeBoth, refreshFavorited, cancelSafetyTimer, exitFavoriteMode])

  /** 已收藏再下滑：提示「已存在」，不重复加入 */
  const doAddFavorite = useCallback(() => {
    const info = getPlayMusicInfo()
    if (!info) return
    if (favRef.current) {
      showResultTip(t('favorite_exists'))
      exitFavoriteMode()
      return
    }
    busyRef.current = true
    Animated.parallel([
      Animated.timing(fade, { toValue: 0, duration: 200, easing: Easing.out(Easing.cubic), useNativeDriver: false }),
      Animated.timing(lift, { toValue: 0.2, duration: 200, useNativeDriver: false }),
      Animated.timing(actionTop, { toValue: 0, duration: 160, useNativeDriver: false }),
      Animated.timing(actionBottom, { toValue: 0, duration: 160, useNativeDriver: false }),
    ]).start(() => {
      cancelSafetyTimer()
      pan.setValue({ x: 0, y: 0 })
      lift.setValue(0)
      setModeBoth('idle')
      setDragHint(null)
      hintRef.current = null
      void addToFavorite(info).then(() => {
        haptic.favorite()
        setFavorited(true)
        favRef.current = true
        showResultTip(t('favorite_added'))
        triggerDockAnimation('add')
      })
      Animated.timing(fade, { toValue: 1, duration: 240, easing: Easing.out(Easing.cubic), useNativeDriver: false }).start(() => {
        busyRef.current = false
      })
    })
  }, [pan, fade, lift, actionTop, actionBottom, setModeBoth, showResultTip, triggerDockAnimation, t, cancelSafetyTimer, exitFavoriteMode])

  /** 未收藏再上滑：提示「未收藏」 */
  const doRemoveFavorite = useCallback(() => {
    const info = getPlayMusicInfo()
    if (!info) return
    if (!favRef.current) {
      showResultTip(t('favorite_not_collected'))
      exitFavoriteMode()
      return
    }
    busyRef.current = true
    Animated.parallel([
      Animated.timing(fade, { toValue: 0, duration: 200, easing: Easing.out(Easing.cubic), useNativeDriver: false }),
      Animated.timing(lift, { toValue: 0.2, duration: 200, useNativeDriver: false }),
      Animated.timing(actionTop, { toValue: 0, duration: 160, useNativeDriver: false }),
      Animated.timing(actionBottom, { toValue: 0, duration: 160, useNativeDriver: false }),
    ]).start(() => {
      cancelSafetyTimer()
      pan.setValue({ x: 0, y: 0 })
      lift.setValue(0)
      setModeBoth('idle')
      setDragHint(null)
      hintRef.current = null
      void removeFromFavorite(info).then(() => {
        haptic.unfavorite()
        setFavorited(false)
        favRef.current = false
        showResultTip(t('favorite_removed'))
        triggerDockAnimation('remove')
      })
      Animated.timing(fade, { toValue: 1, duration: 240, easing: Easing.out(Easing.cubic), useNativeDriver: false }).start(() => {
        busyRef.current = false
      })
    })
  }, [pan, fade, lift, actionTop, actionBottom, setModeBoth, showResultTip, triggerDockAnimation, t, cancelSafetyTimer, exitFavoriteMode])

  // ---------- 普通切歌已迁到全屏 FullScreenSwipe，这里只保留复位 ----------
  const snapBack = useCallback(() => {
    Animated.spring(pan.y, { toValue: 0, friction: 7, tension: 90, useNativeDriver: false }).start()
  }, [pan])

  // ---------- PanResponder ----------
  const onPanResponderRelease = useCallback((_e: GestureResponderEvent, gs: PanResponderGestureState) => {
    cancelLongPress()
    markTimeoutExitInteraction()

    if (modeRef.current == 'favorite') {
      const dy = gs.dy
      // 幅度不足：仅退出悬浮
      if (Math.abs(dy) < ACTION_DRAG) {
        exitFavoriteMode()
        return
      }
      setDragHint(null); hintRef.current = null
      // 回到上一版：下滑=加入收藏，上滑=取消收藏
      if (dy > 0) doAddFavorite()
      else doRemoveFavorite()
      return
    }

    // 普通模式不在这里处理切歌（已交给全屏 FullScreenSwipe），仅复位
    setModeBoth('idle')
    snapBack()
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [exitFavoriteMode, doAddFavorite, doRemoveFavorite, snapBack, setModeBoth, cancelLongPress])

  const panResponder = useMemo(() => PanResponder.create({
    onStartShouldSetPanResponder: () => false,
    onMoveShouldSetPanResponder: (_e, gs) => {
      if (busyRef.current) return false
      // 只有长按悬浮（收藏模式）时才抢手势；
      // 普通模式的上下滑切歌已统一交给全屏 FullScreenSwipe 处理，这里不再抢。
      return modeRef.current == 'favorite' && Math.abs(gs.dy) > 2
    },
    onPanResponderTerminationRequest: () => false,
    onPanResponderGrant: (e: GestureResponderEvent) => {
      markTimeoutExitInteraction()
      pan.stopAnimation()
      pan.setValue({ x: 0, y: 0 })
      startPoint.current = { x: e.nativeEvent.pageX, y: e.nativeEvent.pageY }
    },
    // 只跟手垂直方向：把 dx 固定为 0，避免封面左右摆动
    onPanResponderMove: (_e: GestureResponderEvent, gs: PanResponderGestureState) => {
      pan.setValue({ x: 0, y: gs.dy })
      if (modeRef.current != 'favorite') return
      const dy = gs.dy
      let label: string | null = null
      if (dy > HINT_DRAG) {
        label = favRef.current ? t('favorite_exists') : `↓  ${t('favorite_option_add')}`
      } else if (dy < -HINT_DRAG) {
        label = favRef.current ? `↑  ${t('favorite_option_remove')}` : t('favorite_not_collected')
      }
      if (label != hintRef.current) { hintRef.current = label; setDragHint(label) }
    },
    onPanResponderRelease,
    onPanResponderTerminate: () => {
      cancelLongPress()
      if (modeRef.current == 'favorite') exitFavoriteMode()
      else { setModeBoth('idle'); snapBack() }
    },
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }), [pan, onPanResponderRelease, exitFavoriteMode, snapBack, cancelLongPress, t, setModeBoth])

  // 长按 / 双击检测：用 touch 事件，避免与 PagerView 横向翻页抢占 responder
  const onTouchStart = useCallback((e: GestureResponderEvent) => {
    cancelLongPress()
    if (busyRef.current || modeRef.current == 'favorite') return
    const { pageX, pageY } = e.nativeEvent
    const now = Date.now()
    const prev = lastTapRef.current
    const isDoubleTap = !!prev &&
      now - prev.time < DOUBLE_TAP_INTERVAL &&
      Math.abs(pageX - prev.x) < DOUBLE_TAP_SLOP &&
      Math.abs(pageY - prev.y) < DOUBLE_TAP_SLOP
    if (isDoubleTap) {
      lastTapRef.current = null
      // 双击：不启动长按计时，直接切换收藏
      handleDoubleTap()
      return
    }
    lastTapRef.current = { time: now, x: pageX, y: pageY }
    startPoint.current = { x: pageX, y: pageY }
    longPressTimer.current = setTimeout(() => { enterFavoriteMode() }, LONG_PRESS_DELAY)
  }, [enterFavoriteMode, cancelLongPress, handleDoubleTap])

  const onTouchMove = useCallback((e: GestureResponderEvent) => {
    if (!longPressTimer.current) return
    const { pageX, pageY } = e.nativeEvent
    if (Math.abs(pageX - startPoint.current.x) > 10 || Math.abs(pageY - startPoint.current.y) > 10) cancelLongPress()
  }, [cancelLongPress])

  const onTouchEnd = useCallback(() => {
    cancelLongPress()
    // 悬浮后松手即恢复正常状态
    if (modeRef.current == 'favorite') exitFavoriteMode()
  }, [cancelLongPress, exitFavoriteMode])

  // 组件卸载清理计时器
  useEffect(() => () => {
    cancelLongPress()
    cancelSafetyTimer()
    if (tipTimer.current) clearTimeout(tipTimer.current)
  }, [cancelLongPress, cancelSafetyTimer])

  // 3D 悬浮变换（不含横向位移）
  const coverTransform = [
    { translateY: pan.y },
    { scale: lift.interpolate({ inputRange: [0, 1], outputRange: [1, 1.06] }) },
    { rotateX: lift.interpolate({ inputRange: [0, 1], outputRange: ['0deg', '8deg'] }) },
  ]
  const coverShadow = lift.interpolate({ inputRange: [0, 1], outputRange: [0, 0.42] })

  return (
    <View style={styles.container} collapsable={false}>
      {/* 悬浮期间的全屏透明层：点击任意位置即可恢复正常状态 */}
      {
        mode == 'favorite'
          ? <View
              style={StyleSheet.absoluteFill}
              onStartShouldSetResponder={() => true}
              onResponderRelease={() => { exitFavoriteMode() }}
            />
          : null
      }

      <Animated.View
        pointerEvents="none"
        style={[styles.shadow, { width: width * 0.9, height: height * 0.16, bottom: -height * 0.02, opacity: coverShadow }]}
      />

      {/* 上方操作按钮：取消收藏（白色） */}
      {
        mode == 'favorite'
          ? <Animated.View
              pointerEvents="none"
              style={[styles.actionBar, styles.actionTop, {
                opacity: actionTop,
                transform: [
                  { translateY: actionTop.interpolate({ inputRange: [0, 1], outputRange: [14, 0] }) },
                  { scale: actionTop.interpolate({ inputRange: [0, 1], outputRange: [0.86, 1] }) },
                ],
              }]}
            >
              <View style={[styles.actionPill, styles.actionRemove]}>
                <Text style={[styles.actionGlyph, styles.glyphWhite]}>♡</Text>
                <Text style={[styles.actionLabel, styles.labelWhite]}>{t('favorite_option_remove')}</Text>
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

      {/* 下方操作按钮：加入收藏（红色） */}
      {
        mode == 'favorite'
          ? <Animated.View
              pointerEvents="none"
              style={[styles.actionBar, styles.actionBottom, {
                opacity: actionBottom,
                transform: [
                  { translateY: actionBottom.interpolate({ inputRange: [0, 1], outputRange: [-14, 0] }) },
                  { scale: actionBottom.interpolate({ inputRange: [0, 1], outputRange: [0.86, 1] }) },
                ],
              }]}
            >
              <View style={[styles.actionPill, styles.actionAdd, favorited && styles.actionAddDone]}>
                <Text style={[styles.actionGlyph, styles.glyphRed]}>{'♥'}</Text>
                <Text style={[styles.actionLabel, favorited ? styles.labelDim : styles.labelWhite]}>
                  {favorited ? t('favorite_exists') : t('favorite_option_add')}
                </Text>
              </View>
            </Animated.View>
          : null
      }

      {dragHint ? <View style={styles.hint} pointerEvents="none"><Text size={13} color="#ffffff">{dragHint}</Text></View> : null}
      {resultTip ? <View style={styles.hint} pointerEvents="none"><Text size={13} color={FAVORITE_COLOR}>{resultTip}</Text></View> : null}
    </View>
  )
}

const GLYPH_SIZE = scaleSizeW(18)

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
    shadowColor: 'rgba(6, 4, 4, 0.55)',
    shadowOffset: { width: 0, height: 8 },
    shadowOpacity: 0.45,
    shadowRadius: 16,
  },
  // 加入收藏：红色实底
  actionAdd: { backgroundColor: '#ff4d6d', borderColor: 'rgba(255, 214, 224, 0.95)' },
  // 已收藏状态：降低不透明度，视觉上表示「已完成 / 不可再操作」
  actionAddDone: { opacity: 0.55 },
  // 取消收藏：白色实底
  actionRemove: { backgroundColor: '#ffffff', borderColor: 'rgba(255, 255, 255, 0.95)' },
  // 3D 立体感图标：深色投影 + 浅色高光，模拟凸起的抛光质感
  actionGlyph: {
    fontSize: GLYPH_SIZE,
    fontWeight: 'bold',
    textShadowColor: 'rgba(0, 0, 0, 0.45)',
    textShadowOffset: { width: 0, height: 1.5 },
    textShadowRadius: 2.5,
  },
  glyphRed: { color: '#ffffff' },
  glyphWhite: { color: '#ff4d6d' },
  actionLabel: { fontSize: scaleSizeW(13), fontWeight: '600' },
  labelWhite: { color: '#ffffff' },
  labelDim: { color: 'rgba(255, 255, 255, 0.75)' },
  hint: {
    position: 'absolute',
    top: 8,
    paddingHorizontal: 12,
    paddingVertical: 5,
    borderRadius: 14,
    backgroundColor: 'rgba(0, 0, 0, 0.62)',
  },
})
