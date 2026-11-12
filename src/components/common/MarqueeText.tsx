import { memo, useEffect, useRef, useState } from 'react'
import { Animated, Easing, StyleSheet, View, type StyleProp, type TextStyle } from 'react-native'
import Text from '@/components/common/Text'

/**
 * 长文本横向慢速滚动（跑马灯）。
 *
 * 只在文字实际宽度超出容器时才滚动，否则静态显示（避免短文本无谓动画）。
 * 滚动到一个循环结束会停顿片刻再重新开始，观感更自然。
 */
const MarqueeText = memo(({
  text,
  size,
  color,
  style,
  speed = 28,
  pauseDuration = 1200,
}: {
  text: string
  size: number
  color: string
  style?: StyleProp<TextStyle>
  /** 每秒滚动的像素 */
  speed?: number
  /** 滚完一轮后停顿的毫秒数 */
  pauseDuration?: number
}) => {
  const [containerWidth, setContainerWidth] = useState(0)
  const [textWidth, setTextWidth] = useState(0)
  const translateX = useRef(new Animated.Value(0)).current
  const loopRef = useRef<Animated.CompositeAnimation | null>(null)

  const shouldScroll = containerWidth > 0 && textWidth > containerWidth + 2

  useEffect(() => {
    loopRef.current?.stop()
    translateX.setValue(0)
    if (!shouldScroll) return

    const distance = textWidth + 24 // 末尾留一点间隔，视觉上更连贯
    const duration = Math.max(2000, (distance / speed) * 1000)

    const loop = Animated.loop(
      Animated.sequence([
        Animated.delay(pauseDuration),
        Animated.timing(translateX, {
          toValue: -distance,
          duration,
          easing: Easing.linear,
          useNativeDriver: true,
        }),
        // 回到起点（无动画）
        Animated.timing(translateX, {
          toValue: 0,
          duration: 0,
          useNativeDriver: true,
        }),
      ]),
    )
    loopRef.current = loop
    loop.start()

    return () => {
      loop.stop()
      loopRef.current = null
    }
  }, [shouldScroll, textWidth, containerWidth, speed, pauseDuration, translateX, text])

  return (
    <View
      style={styles.container}
      onLayout={e => { setContainerWidth(e.nativeEvent.layout.width) }}
    >
      <Animated.View style={{ transform: [{ translateX }] }}>
        <Text
          size={size}
          color={color}
          style={style}
          numberOfLines={1}
          // 不裁剪：让文字完整渲染，测量才能拿到真实宽度
          onLayout={e => { setTextWidth(e.nativeEvent.layout.width) }}
        >{text}</Text>
      </Animated.View>
    </View>
  )
})

const styles = StyleSheet.create({
  container: {
    width: '100%',
    overflow: 'hidden',
  },
})

export default MarqueeText
