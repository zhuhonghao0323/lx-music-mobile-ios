import { memo, useMemo } from 'react'
import { View, StyleSheet } from 'react-native'
import Text from '@/components/common/Text'
import { useLrcPlay, useLrcSet } from '@/plugins/lyric'
import { useSettingValue } from '@/store/setting/hook'
import { useTheme } from '@/store/theme/hook'
import { scaleSizeW } from '@/utils/pixelRatio'

/**
 * 封面下方的三行歌词预览：上一句 / 当前句（高亮）/ 下一句（调暗）。
 * 颜色与字号取自设置，与全屏歌词页互不干扰。
 */
const LYRIC_COLORS: Record<string, string> = {
  white: '#ffffff',
  blue: '#7fc4ff',
  pink: '#ff8fb1',
  green: '#7ee8a2',
}

export default memo(() => {
  const theme = useTheme()
  const lines = useLrcSet()
  const { line: currentIndex } = useLrcPlay()
  const colorKey = useSettingValue('theme.lyricPreviewColor')
  const fontSize = useSettingValue('theme.lyricPreviewFontSize')

  const highlightColor = LYRIC_COLORS[colorKey] ?? theme['c-primary']
  const dimColor = 'rgba(255,255,255,0.55)'

  const { prev, current, next } = useMemo(() => {
    const getText = (index: number) => {
      const item = lines[index]
      return item?.text?.trim() ?? ''
    }
    return {
      prev: currentIndex > 0 ? getText(currentIndex - 1) : '',
      current: getText(currentIndex),
      next: getText(currentIndex + 1),
    }
  }, [lines, currentIndex])

  const baseSize = fontSize

  return (
    <View style={styles.container} pointerEvents="none">
      <Text style={styles.line} size={baseSize - 1} color={dimColor} numberOfLines={1}>{prev || ' '}</Text>
      <Text style={styles.currentLine} size={baseSize + 1} color={highlightColor} numberOfLines={1}>{current || ' '}</Text>
      <Text style={styles.line} size={baseSize - 1} color={dimColor} numberOfLines={1}>{next || ' '}</Text>
    </View>
  )
})

const styles = StyleSheet.create({
  container: {
    width: '100%',
    paddingHorizontal: scaleSizeW(24),
    paddingVertical: scaleSizeW(6),
    alignItems: 'center',
    justifyContent: 'center',
    gap: 2,
  },
  line: {
    textAlign: 'center',
  },
  currentLine: {
    textAlign: 'center',
    fontWeight: '600',
  },
})
