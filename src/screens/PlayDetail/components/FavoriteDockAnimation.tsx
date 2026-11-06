import { useEffect, useRef, useState } from 'react'
import { Animated, Easing, StyleSheet, View, type LayoutRectangle } from 'react-native'
import Image from '@/components/common/Image'

/**
 * 一份封面「飞入 / 抽出」心形按钮的动画描述。
 * 坐标全部使用 measureInWindow 得到的屏幕绝对坐标，因此天然适配任意机型、
 * 灵动岛 / 刘海 / 横竖屏切换，不依赖任何硬编码尺寸。
 */
export interface FavoriteDockAnimationPayload {
  /** 起始矩形（封面在屏幕上的位置与尺寸） */
  from: LayoutRectangle
  /** 目标矩形（心形按钮在屏幕上的位置与尺寸） */
  to: LayoutRectangle
  /** 封面图地址，用于克隆一份做飞行动画 */
  pic: string | null
  /** add = 收进心形；remove = 从心形抽出 */
  direction: 'add' | 'remove'
}

let runner: ((payload: FavoriteDockAnimationPayload) => void) | null = null

/** 触发一次「收进/抽出」动画；播放页未挂载时安全忽略 */
export const playFavoriteDockAnimation = (payload: FavoriteDockAnimationPayload) => {
  runner?.(payload)
}

const FLY_DURATION = 480
const BURST_DURATION = 320

/**
 * macOS Dock 收纳（genie）风格的封面飞行层。
 * 用二次贝塞尔弧线让封面朝心形「吸」过去，同时缩放 + 轻微挤压 + 旋转 + 淡出，
 * 取消收藏时反向播放。
 */
export default ({ onArrive }: { onArrive?: (direction: 'add' | 'remove') => void }) => {
  const [payload, setPayload] = useState<FavoriteDockAnimationPayload | null>(null)
  const progress = useRef(new Animated.Value(0)).current
  const burst = useRef(new Animated.Value(0)).current
  const animRef = useRef<Animated.CompositeAnimation | null>(null)

  useEffect(() => {
    runner = (next) => {
      animRef.current?.stop()
      setPayload(next)
      progress.setValue(0)
      burst.setValue(0)
    }
    return () => { runner = null }
  }, [progress, burst])

  useEffect(() => {
    if (!payload) return
    const anim = Animated.timing(progress, {
      toValue: 1,
      duration: FLY_DURATION,
      easing: Easing.bezier(0.4, 0, 0.2, 1),
      useNativeDriver: true,
    })
    animRef.current = anim
    anim.start(({ finished }) => {
      if (!finished) return
      // 到达目标：播放一下「吸附」脉冲，然后清理
      Animated.timing(burst, {
        toValue: 1,
        duration: BURST_DURATION,
        easing: Easing.out(Easing.cubic),
        useNativeDriver: true,
      }).start(() => {
        setPayload((current) => {
          if (current) onArrive?.(current.direction)
          return null
        })
      })
    })
  }, [payload, progress, burst, onArrive])

  if (!payload) return null

  const { from, to, pic, direction } = payload
  const startX = from.x + from.width / 2
  const startY = from.y + from.height / 2
  const endX = to.x + to.width / 2
  const endY = to.y + to.height / 2

  // 反向：取消收藏时从心形出发飞回封面位置
  const reversed = direction == 'remove'
  const origin = reversed ? { x: endX, y: endY } : { x: startX, y: startY }
  const target = reversed ? { x: startX, y: startY } : { x: endX, y: endY }

  // 弧线控制点：抬高一些形成「被吸走」的抛物线观感
  const ctrlX = (origin.x + target.x) / 2
  const ctrlY = Math.min(origin.y, target.y) - Math.abs(origin.y - target.y) * 0.55 - 40

  // 二次贝塞尔：B(t) = (1-t)²P0 + 2(1-t)t·P1 + t²P2
  // t=0.5 时相对起点的偏移 = 0.5(P1-P0) + 0.25(P2-P0)
  const midX = 0.5 * (ctrlX - origin.x) + 0.25 * (target.x - origin.x)
  const midY = 0.5 * (ctrlY - origin.y) + 0.25 * (target.y - origin.y)

  const translateX = progress.interpolate({
    inputRange: [0, 0.5, 1],
    outputRange: [0, midX, target.x - origin.x],
  })
  const translateY = progress.interpolate({
    inputRange: [0, 0.5, 1],
    outputRange: [0, midY, target.y - origin.y],
  })

  const targetScale = Math.max(0.08, to.width / from.width)
  const scale = progress.interpolate({ inputRange: [0, 1], outputRange: [1, targetScale] })
  const scaleX = progress.interpolate({ inputRange: [0, 0.55, 1], outputRange: [1, 0.86, 1] })
  const rotate = progress.interpolate({ inputRange: [0, 1], outputRange: reversed ? ['-12deg', '0deg'] : ['0deg', '12deg'] })
  const opacity = progress.interpolate({ inputRange: [0, 0.82, 1], outputRange: [1, 1, 0] })
  const burstScale = burst.interpolate({ inputRange: [0, 1], outputRange: [1, 1.6] })
  const burstOpacity = burst.interpolate({ inputRange: [0, 1], outputRange: [0.6, 0] })

  return (
    <View pointerEvents="none" style={StyleSheet.absoluteFill}>
      {/* 到达心形后的扩散光晕 */}
      <Animated.View
        style={{
          position: 'absolute',
          left: target.x - to.width / 2,
          top: target.y - to.height / 2,
          width: to.width,
          height: to.height,
          borderRadius: to.width / 2,
          backgroundColor: '#ff4d6d',
          opacity: burstOpacity,
          transform: [{ scale: burstScale }],
        }}
      />
      <Animated.View
        style={{
          position: 'absolute',
          left: origin.x - from.width / 2,
          top: origin.y - from.height / 2,
          width: from.width,
          height: from.height,
          borderRadius: 14,
          shadowColor: 'rgba(0,0,0,0.5)',
          shadowOffset: { width: 0, height: 12 },
          shadowOpacity: 0.5,
          shadowRadius: 22,
          opacity,
          transform: [
            { translateX },
            { translateY },
            { rotate },
            { scale },
            { scaleX },
          ],
        }}
      >
        <Image url={pic} style={{ width: '100%', height: '100%', borderRadius: 14 }} />
      </Animated.View>
    </View>
  )
}
