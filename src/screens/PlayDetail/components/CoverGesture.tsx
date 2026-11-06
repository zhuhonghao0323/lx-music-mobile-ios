import { useCallback, useMemo, useRef, useState } from 'react'
import { Animated, Easing, PanResponder, StyleSheet, View, type GestureResponderEvent, type PanResponderGestureState } from 'react-native'
import Text from '@/components/common/Text'
import { FAVORITE_COLOR } from './FavoriteIcon'
import { triggerFavoriteDockAnimation } from './FavoriteBtn'
import { addToFavorite, getPlayMusicInfo, removeFromFavorite } from '@/core/favorite'
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
/** 收藏模式内拖动的触发距离 */
const FAVORITE_DRAG_THRESHOLD = 70

type SwipeAction = 'next' | 'prev' | null
type Mode = 'idle' | 'swipe' | 'favorite'

/**
 * 判定普通模式的轻滑：只有足够「竖直」的上划/下滑才切歌，斜上/斜下不处理。
 */
const classifySwipe = (dx: number, dy: number): SwipeAction => {
  const ax = Math.abs(dx)
  const ay = Math.abs(dy)
  if (Math.max(ax, ay) < SWIPE_THRESHOLD) return null
  if (ay <= ax * AXIS_RATIO) return null // 斜向或横向：不处理，交还 PagerView
  return dy < 0 ? 'next' : 'prev'
}

/**
 * 播放界面封面手势容器：
 * - 普通模式：轻滑上=下一曲、轻滑下=上一曲，斜向无动作
 * - 长按 1 秒：封面 3D 悬浮进入「收藏模式」，显示加入/取消两个选项及右上角垃圾桶
 *     · 此模式下上一曲/下一曲不可用
 *     · 向下拖 = 加入我的收藏（封面飞入心形）
 *     · 向上拖 = 取消收藏（封面丢入垃圾桶）
 */
export default ({ children, width, height }: {
  children: React.ReactNode
  width: number
  height: number
}) => {
  const t = useI18n()
  const pan = useRef(new Animated.ValueXY()).current
  const fade = useRef(new Animated.Value(1)).current
  const lift = useRef(new Animated.Value(0)).current // 0 常态 / 1 悬浮
  const heartScale = useRef(new Animated.Value(0)).current
  const trashScale = useRef(new Animated.Value(0)).current
  const [mode, setMode] = useState<Mode>('idle')
  const [favHint, setFavHint] = useState<string | null>(null)
  const [resultTip, setResultTip] = useState<string | null>(null)

  const modeRef = useRef<Mode>('idle')
  const busyRef = useRef(false)
  const longPressTimer = useRef<ReturnType<typeof setTimeout> | null>(null)
  const startPoint = useRef({ x: 0, y: 0 })
  const dragHandledRef = useRef(false)
  const favHintRef = useRef<string | null>(null)
  const tipTimer = useRef<ReturnType<typeof setTimeout> | null>(null)

  const cancelLongPress = useCallback(() => {
    if (longPressTimer.current) { clearTimeout(longPressTimer.current); longPressTimer.current = null }
  }, [])

  const setModeBoth = useCallback((m: Mode) => {
    modeRef.current = m
    setMode(m)
  }, [])

  // ---------- 收藏模式 3D 悬浮 ----------
  const enterFavoriteMode = useCallback(() => {
    if (busyRef.current || modeRef.current == 'favorite') return
    setModeBoth('favorite')
    pan.setValue({ x: 0, y: 0 })
    Animated.parallel([
      Animated.spring(lift, { toValue: 1, friction: 6, tension: 90, useNativeDriver: false }),
      Animated.spring(heartScale, { toValue: 1, friction: 5, tension: 110, useNativeDriver: false }),
      Animated.spring(trashScale, { toValue: 1, friction: 5, tension: 110, useNativeDriver: false }),
    ]).start()
  }, [lift, heartScale, trashScale, pan, setModeBoth])

  const exitFavoriteMode = useCallback((run?: () => void) => {
    Animated.parallel([
      Animated.timing(lift, { toValue: 0, duration: 260, easing: Easing.out(Easing.cubic), useNativeDriver: false }),
      Animated.timing(heartScale, { toValue: 0, duration: 200, useNativeDriver: false }),
      Animated.timing(trashScale, { toValue: 0, duration: 200, useNativeDriver: false }),
      Animated.timing(pan, { toValue: { x: 0, y: 0 }, duration: 260, easing: Easing.out(Easing.cubic), useNativeDriver: false }),
    ]).start(() => {
      setModeBoth('idle')
      setFavHint(null)
      favHintRef.current = null
      run?.()
    })
  }, [lift, heartScale, trashScale, pan, setModeBoth])

  const showResultTip = useCallback((text: string) => {
    if (tipTimer.current) clearTimeout(tipTimer.current)
    setResultTip(text)
    tipTimer.current = setTimeout(() => { setResultTip(null) }, 1400)
  }, [])

  /** 调用播放页的 Dock 动画（封面↔心形），失败时静默忽略 */
  const triggerDockAnimation = useCallback((direction: 'add' | 'remove') => {
    void triggerFavoriteDockAnimation(direction)
  }, [])

  // ---------- 收藏动画 ----------
  /** 加入收藏：数据立即生效，同时把封面交给 Dock 动画收进左下角心形 */
  const animateAddToHeart = useCallback(() => {
    const musicInfo = getPlayMusicInfo()
    busyRef.current = true
    // 封面先柔和淡出，飞行动画由 FavoriteDockAnimation 接管（避免两套动画打架）
    Animated.parallel([
      Animated.timing(fade, { toValue: 0, duration: 220, easing: Easing.out(Easing.cubic), useNativeDriver: false }),
      Animated.timing(lift, { toValue: 0.2, duration: 220, useNativeDriver: false }),
    ]).start(() => {
      pan.setValue({ x: 0, y: 0 })
      lift.setValue(0)
      heartScale.setValue(0)
      trashScale.setValue(0)
      setModeBoth('idle')
      setFavHint(null)
      favHintRef.current = null
      if (musicInfo) {
        void addToFavorite(musicInfo).then(() => {
          showResultTip(t('favorite_added'))
          triggerDockAnimation('add')
        })
      } else {
        triggerDockAnimation('add')
      }
      Animated.timing(fade, { toValue: 1, duration: 260, easing: Easing.out(Easing.cubic), useNativeDriver: false }).start(() => {
        busyRef.current = false
      })
    })
  }, [pan, fade, lift, heartScale, trashScale, showResultTip, t, setModeBoth, triggerDockAnimation])

  /** 取消收藏：同样交给 Dock 动画反向播放（从心形里抽出封面） */
  const animateThrowToTrash = useCallback(() => {
    const musicInfo = getPlayMusicInfo()
    busyRef.current = true
    Animated.parallel([
      Animated.timing(fade, { toValue: 0, duration: 220, easing: Easing.out(Easing.cubic), useNativeDriver: false }),
      Animated.timing(lift, { toValue: 0.2, duration: 220, useNativeDriver: false }),
    ]).start(() => {
      pan.setValue({ x: 0, y: 0 })
      lift.setValue(0)
      heartScale.setValue(0)
      trashScale.setValue(0)
      setModeBoth('idle')
      setFavHint(null)
      favHintRef.current = null
      if (musicInfo) {
        void removeFromFavorite(musicInfo).then(() => {
          showResultTip(t('favorite_removed'))
          triggerDockAnimation('remove')
        })
      } else {
        triggerDockAnimation('remove')
      }
      Animated.timing(fade, { toValue: 1, duration: 260, easing: Easing.out(Easing.cubic), useNativeDriver: false }).start(() => {
        busyRef.current = false
      })
    })
  }, [pan, fade, lift, heartScale, trashScale, showResultTip, t, setModeBoth, triggerDockAnimation])

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
      // 收藏模式：向下=加入，向上=取消；不切歌
      const dy = gs.dy
      if (Math.abs(dy) < FAVORITE_DRAG_THRESHOLD) {
        dragHandledRef.current = true
        exitFavoriteMode()
        return
      }
      setFavHint(null); favHintRef.current = null
      dragHandledRef.current = true
      if (dy > 0) animateAddToHeart()
      else animateThrowToTrash()
      return
    }

    // 普通模式
    setModeBoth('idle')
    const action = classifySwipe(gs.dx, gs.dy)
    if (!action || busyRef.current) { snapBack(); return }
    runSwipe(action)
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [exitFavoriteMode, animateAddToHeart, animateThrowToTrash, runSwipe, snapBack, setModeBoth])

  const panResponder = useMemo(() => PanResponder.create({
    // 不在按下瞬间抢占，横向滑动仍交给 PagerView 翻页
    onStartShouldSetPanResponder: () => false,
    onMoveShouldSetPanResponder: (_e, gs) => {
      if (busyRef.current) return false
      const ax = Math.abs(gs.dx)
      const ay = Math.abs(gs.dy)
      // 收藏模式任意方向都可拖；普通模式仅纵向抢占
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
          const label = gs.dy > FAVORITE_DRAG_THRESHOLD * 0.5
            ? `↓  ${t('favorite_added')}`
            : gs.dy < -FAVORITE_DRAG_THRESHOLD * 0.5
              ? `↑  ${t('favorite_removed')}`
              : t('player_cover_favorite_mode_hint')
          if (label != favHintRef.current) { favHintRef.current = label; setFavHint(label) }
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

  // 长按检测用 touch 事件，避免与 PagerView 的横向翻页抢占 responder
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
    if (modeRef.current == 'favorite' && !dragHandledRef.current) {
      // 长按后直接抬手、没有拖动：退出收藏模式
      exitFavoriteMode()
    }
  }, [cancelLongPress, exitFavoriteMode])

  // 3D 悬浮变换：抬升 + 轻微透视
  const coverTransform = [
    ...pan.getTranslateTransform(),
    {
      scale: lift.interpolate({ inputRange: [0, 1], outputRange: [1, 1.06] }),
    },
    {
      rotateX: lift.interpolate({ inputRange: [0, 1], outputRange: ['0deg', '8deg'] }),
    },
  ]
  const coverShadow = lift.interpolate({
    inputRange: [0, 1],
    outputRange: [0, 0.42],
  })

  return (
    <View style={styles.container} collapsable={false}>
      {/* 悬浮阴影层 */}
      <Animated.View
        pointerEvents="none"
        style={[styles.shadow, {
          width: width * 0.9,
          height: height * 0.16,
          bottom: -height * 0.02,
          opacity: coverShadow,
        }]}
      />
      <Animated.View
        {...panResponder.panHandlers}
        onTouchStart={onTouchStart}
        onTouchMove={onTouchMove}
        onTouchEnd={onTouchEnd}
        onTouchCancel={onTouchEnd}
        style={[
          styles.gesture,
          {
            opacity: fade,
            transform: coverTransform,
          },
        ]}
      >
        {children}
      </Animated.View>

      {/* 收藏模式浮层：下方心形=加入目标（收进心形），上方=取消目标（从心形抽出） */}
      {
        mode == 'favorite'
          ? <>
              <Animated.View
                pointerEvents="none"
                style={[styles.trash, {
                  opacity: trashScale,
                  transform: [
                    { scale: trashScale.interpolate({ inputRange: [0, 1], outputRange: [0.4, 1] }) },
                  ],
                }]}
              >
                <View style={styles.iconCircle}>
                  <Text style={styles.glyph}>♡</Text>
                </View>
                <Text style={styles.optionLabel}>{t('favorite_option_remove')}</Text>
              </Animated.View>
              <Animated.View
                pointerEvents="none"
                style={[styles.heart, {
                  opacity: heartScale,
                  transform: [
                    { scale: heartScale.interpolate({ inputRange: [0, 1], outputRange: [0.4, 1] }) },
                  ],
                }]}
              >
                <Text style={[styles.heartGlyph, { fontSize: scaleSizeW(46), color: FAVORITE_COLOR }]}>♥</Text>
                <Text style={styles.optionLabel}>{t('favorite_option_add')}</Text>
              </Animated.View>
            </>
          : null
      }
      {
        favHint
          ? <View style={styles.hint} pointerEvents="none"><Text size={13} color="#ffffff">{favHint}</Text></View>
          : null
      }
      {
        resultTip
          ? <View style={styles.hint} pointerEvents="none"><Text size={13} color={FAVORITE_COLOR}>{resultTip}</Text></View>
          : null
      }
    </View>
  )
}

const styles = StyleSheet.create({
  container: { justifyContent: 'center', alignItems: 'center' },
  gesture: { justifyContent: 'center', alignItems: 'center' },
  shadow: {
    position: 'absolute',
    borderRadius: 100,
    backgroundColor: 'rgba(0, 0, 0, 0.55)',
  },
  iconCircle: {
    width: scaleSizeW(52),
    height: scaleSizeW(52),
    borderRadius: scaleSizeW(26),
    backgroundColor: 'rgba(255, 255, 255, 0.16)',
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: 'rgba(255, 255, 255, 0.5)',
    justifyContent: 'center',
    alignItems: 'center',
  },
  glyph: { fontSize: scaleSizeW(24) },
  trash: { position: 'absolute', top: -scaleSizeW(18), right: -scaleSizeW(8), alignItems: 'center' },
  heart: { position: 'absolute', bottom: -scaleSizeW(70), alignItems: 'center' },
  heartGlyph: { fontWeight: 'bold', textAlign: 'center' },
  optionLabel: { marginTop: 3, color: 'rgba(255,255,255,0.92)', fontSize: scaleSizeW(11) },
  hint: {
    position: 'absolute',
    top: 8,
    paddingHorizontal: 12,
    paddingVertical: 5,
    borderRadius: 14,
    backgroundColor: 'rgba(0, 0, 0, 0.62)',
  },
})
