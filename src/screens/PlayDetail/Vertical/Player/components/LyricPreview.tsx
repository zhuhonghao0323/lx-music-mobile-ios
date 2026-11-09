import { memo, useEffect, useMemo, useRef } from 'react'
import { Animated, Easing, StyleSheet, View } from 'react-native'
import { useLrcPlay, useLrcSet } from '@/plugins/lyric'
import { useSettingValue } from '@/store/setting/hook'
import { useTheme } from '@/store/theme/hook'
import { scaleSizeW, setSpText } from '@/utils/pixelRatio'

/**
 * 封面与进度条之间的三行歌词预览：上一句 / 当前句（高亮）/ 下一句（调暗）。
 * - 容器 flex:1 并居中：歌词块始终位于封面下方与进度条上方的中间位置
 * - 换行时整体上移一小段并淡入淡出，模拟歌词滚动
 */
const LYRIC_COLORS: Record<string, string> = {
  white: '#ffffff',
  blue: '#7fc4ff',
  pink: '#ff8fb1',
  green: '#7ee8a2',
}

const ROW_GAP = scaleSizeW(12)
const FADE_DURATION = 260

export default memo(() => {
  const theme = useTheme()
  const lines = useLrcSet()
  const { line: currentIndex } = useLrcPlay()
  const colorKey = useSettingValue('theme.lyricPreviewColor')
  const fontSize = useSettingValue('theme.lyricPreviewFontSize')

  const highlightColor = LYRIC_COLORS[colorKey] ?? theme['c-primary']
  const dimColor = 'rgba(255,255,255,0.45)'

  const { prev, current, next } = useMemo(() => {
    const getText = (index: number) => lines[index]?.text?.trim() ?? ''
    return {
      prev: currentIndex > 0 ? getText(currentIndex - 1) : '',
      current: getText(currentIndex),
      next: getText(currentIndex + 1),
    }
  }, [lines, currentIndex])

  // 换行动画：整体轻微上移 + 淡入，制造「滚动」感
  const anim = useRef(new Animated.Value(1)).current
  const translateY = useRef(new Animated.Value(0)).current
  const firstRef = useRef(true)

  useEffect(() => {
    // 首帧不做动画，避免进入播放页时闪一下
    if (firstRef.current) {
      firstRef.current = false
      return
    }
    anim.setValue(0)
    translateY.setValue(scaleSizeW(10))
    Animated.parallel([
      Animated.timing(anim, {
        toValue: 1,
        duration: FADE_DURATION,
        easing: Easing.out(Easing.cubic),
        useNativeDriver: true,
      }),
      Animated.timing(translateY, {
        toValue: 0,
        duration: FADE_DURATION,
        easing: Easing.out(Easing.cubic),
        useNativeDriver: true,
      }),
    ]).start()
  }, [currentIndex, anim, translateY])

  const rowSize = setSpText(fontSize - 1)
  const currentSize = setSpText(fontSize + 1)

  return (
    <View style={styles.container} pointerEvents="none">
      <Animated.View style={[styles.block, { opacity: anim, transform: [{ translateY }] }]}>
        <Animated.Text
          numberOfLines={1}
          style={[styles.line, { fontSize: rowSize, color: dimColor, marginBottom: ROW_GAP }]}
        >{prev || ' '}</Animated.Text>
        <Animated.Text
          numberOfLines={1}
          style={[styles.currentLine, { fontSize: currentSize, color: highlightColor, marginBottom: ROW_GAP }]}
        >{current || ' '}</Animated.Text>
        <Animated.Text
          numberOfLines={1}
          style={[styles.line, { fontSize: rowSize, color: dimColor }]}
        >{next || ' '}</Animated.Text>
      </Animated.View>
    </View>
  )
})

const styles = StyleSheet.create({
  container: {
    // flex:1 让三行歌词在「封面下沿 → 进度条上沿」之间垂直居中
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: scaleSizeW(24),
  },
  block: {
    alignItems: 'center',
    justifyContent: 'center',
  },
  line: {
    textAlign: 'center',
  },
  currentLine: {
    textAlign: 'center',
    fontWeight: '600',
  },
})
