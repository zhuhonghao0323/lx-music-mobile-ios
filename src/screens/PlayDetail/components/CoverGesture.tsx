import { useCallback, useMemo, useRef, useState } from 'react'
import { Animated, Easing, PanResponder, StyleSheet, View, type GestureResponderEvent, type PanResponderGestureState } from 'react-native'
import Text from '@/components/common/Text'
import { FAVORITE_COLOR } from './FavoriteIcon'
import { addToFavorite, getPlayMusicInfo, removeFromFavorite } from '@/core/favorite'
import { playNext, playPrev } from '@/core/player/player'
import { markTimeoutExitInteraction } from '@/core/player/timeoutExit'
import { useI18n } from '@/lang'

/** 触发手势的最小滑动距离 */
const SWIPE_THRESHOLD = 55
/** 判定「竖直 / 水平 / 对角线」的轴比 */
const AXIS_RATIO = 1.4

type SwipeAction = 'next' | 'prev' | 'favorite' | 'unfavorite' | null

/**
 * 按滑动方向把手势分成四类：
 * - 上划 ↑      → 下一曲
 * - 下滑 ↓      → 上一曲
 * - 右上 ↗      → 加入我的收藏
 * - 左下 ↙      → 取消我的收藏
 * 其余方向（纯水平等）不处理，交还给 PagerView 翻页。
 */
const classify = (dx: number, dy: number): SwipeAction => {
  const ax = Math.abs(dx)
  const ay = Math.abs(dy)
  if (Math.max(ax, ay) < SWIPE_THRESHOLD) return null
  if (ay > ax * AXIS_RATIO) return dy < 0 ? 'next' : 'prev'
  if (ax > ay * AXIS_RATIO) return null
  if (dx > 0 && dy < 0) return 'favorite'
  if (dx < 0 && dy > 0) return 'unfavorite'
  return null
}

const actionLabel = (action: SwipeAction, t: (key: any) => string): string | null => {
  switch (action) {
    case 'next': return `↑  ${t('player_cover_swipe_next')}`
    case 'prev': return `↓  ${t('player_cover_swipe_prev')}`
    case 'favorite': return `♥  ${t('favorite_added')}`
    case 'unfavorite': return `♡  ${t('favorite_removed')}`
    default: return null
  }
}

/**
 * 封面拖动手势容器：
 * 跟手平移 + 松手飞出/回弹动画，附带方向提示与结果提示。
 */
export default ({ children, width, height }: {
  children: React.ReactNode
  width: number
  height: number
}) => {
  const t = useI18n()
  const pan = useRef(new Animated.ValueXY()).current
  const fade = useRef(new Animated.Value(1)).current
  const tipOpacity = useRef(new Animated.Value(0)).current
  const [hint, setHint] = useState<string | null>(null)
  const [tip, setTip] = useState<string | null>(null)
  const hintRef = useRef<string | null>(null)
  const busyRef = useRef(false)
  const tipAnimRef = useRef<Animated.CompositeAnimation | null>(null)
  const tipTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null)

  const showTip = useCallback((text: string) => {
    tipAnimRef.current?.stop()
    if (tipTimerRef.current) clearTimeout(tipTimerRef.current)
    setTip(text)
    tipOpacity.setValue(1)
    tipAnimRef.current = Animated.timing(tipOpacity, {
      toValue: 0,
      delay: 900,
      duration: 300,
      easing: Easing.out(Easing.cubic),
      useNativeDriver: false,
    })
    tipAnimRef.current.start(() => {
      setTip(null)
      tipAnimRef.current = null
    })
  }, [tipOpacity])

  const runAction = useCallback((action: Exclude<SwipeAction, null>) => {
    const musicInfo = getPlayMusicInfo()
    switch (action) {
      case 'next':
        void playNext()
        break
      case 'prev':
        void playPrev()
        break
      case 'favorite':
        if (musicInfo) void addToFavorite(musicInfo).then(() => { showTip(t('favorite_added')) })
        break
      case 'unfavorite':
        if (musicInfo) void removeFromFavorite(musicInfo).then(() => { showTip(t('favorite_removed')) })
        break
    }
  }, [showTip, t])

  const snapBack = useCallback(() => {
    Animated.parallel([
      Animated.spring(pan.x, { toValue: 0, friction: 7, tension: 90, useNativeDriver: false }),
      Animated.spring(pan.y, { toValue: 0, friction: 7, tension: 90, useNativeDriver: false }),
    ]).start()
  }, [pan])

  const onPanResponderRelease = useCallback((_e: GestureResponderEvent, gs: PanResponderGestureState) => {
    setHint(null)
    hintRef.current = null
    const action = classify(gs.dx, gs.dy)
    if (!action || busyRef.current) {
      snapBack()
      return
    }
    busyRef.current = true
    markTimeoutExitInteraction()

    // 朝滑动方向飞出并淡出
    const flyX = Math.abs(gs.dx) > Math.abs(gs.dy) * 0.4 ? Math.sign(gs.dx) * width * 0.9 : gs.dx * 2.5
    const flyY = Math.sign(gs.dy) * Math.max(height * 0.7, Math.abs(gs.dy) * 2.5)
    Animated.parallel([
      Animated.timing(pan, {
        toValue: { x: flyX, y: flyY },
        duration: 190,
        easing: Easing.out(Easing.cubic),
        useNativeDriver: false,
      }),
      Animated.timing(fade, { toValue: 0, duration: 190, easing: Easing.out(Easing.cubic), useNativeDriver: false }),
    ]).start(() => {
      runAction(action)
      pan.setValue({ x: 0, y: 0 })
      fade.setValue(0)
      // 新封面淡入
      Animated.timing(fade, {
        toValue: 1,
        duration: 240,
        easing: Easing.out(Easing.cubic),
        useNativeDriver: false,
      }).start(() => {
        busyRef.current = false
      })
    })
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [width, height, pan, fade, runAction, snapBack])

  const panResponder = useMemo(() => PanResponder.create({
    onStartShouldSetPanResponder: () => false,
    // 仅纵向分量足够明显时接管，纯横向滑动留给 PagerView 翻页
    onMoveShouldSetPanResponder: (_e, gs) => {
      if (busyRef.current) return false
      const ax = Math.abs(gs.dx)
      const ay = Math.abs(gs.dy)
      return ay > 6 && ay >= ax * 0.7
    },
    onPanResponderTerminationRequest: () => false,
    onPanResponderGrant: () => {
      markTimeoutExitInteraction()
      pan.stopAnimation()
      pan.setValue({ x: 0, y: 0 })
    },
    onPanResponderMove: Animated.event(
      [null, { dx: pan.x, dy: pan.y }],
      {
        useNativeDriver: false,
        listener: (...args: any[]) => {
          const gs = args[1] as PanResponderGestureState
          const label = actionLabel(classify(gs.dx, gs.dy), t)
          if (label != hintRef.current) {
            hintRef.current = label
            setHint(label)
          }
        },
      },
    ),
    onPanResponderRelease,
    onPanResponderTerminate: () => {
      setHint(null)
      hintRef.current = null
      snapBack()
    },
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }), [pan, onPanResponderRelease, snapBack, t])

  return (
    <View style={styles.container} collapsable={false}>
      <Animated.View
        {...panResponder.panHandlers}
        style={[
          styles.gesture,
          {
            opacity: fade,
            transform: pan.getTranslateTransform(),
          },
        ]}
      >
        {children}
      </Animated.View>
      {
        hint
          ? <View style={styles.hint} pointerEvents="none">
              <Text size={14} color="#ffffff">{hint}</Text>
            </View>
          : null
      }
      {
        tip
          ? <Animated.View style={[styles.tip, { opacity: tipOpacity }]} pointerEvents="none">
              <Text size={14} color={FAVORITE_COLOR}>{tip}</Text>
            </Animated.View>
          : null
      }
    </View>
  )
}

const styles = StyleSheet.create({
  container: {
    justifyContent: 'center',
    alignItems: 'center',
  },
  gesture: {
    justifyContent: 'center',
    alignItems: 'center',
  },
  hint: {
    position: 'absolute',
    top: 8,
    paddingHorizontal: 12,
    paddingVertical: 5,
    borderRadius: 14,
    backgroundColor: 'rgba(0, 0, 0, 0.62)',
  },
  tip: {
    position: 'absolute',
    bottom: 8,
    paddingHorizontal: 12,
    paddingVertical: 5,
    borderRadius: 14,
    backgroundColor: 'rgba(0, 0, 0, 0.62)',
  },
})
