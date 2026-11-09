import { createStyle } from '@/utils/tools'
import { View } from 'react-native'
import PlayModeBtn from './PlayModeBtn'
import MusicAddBtn from './MusicAddBtn'
import DesktopLyricBtn from './DesktopLyricBtn'
import CommentBtn from './CommentBtn'
import QualityBtn from './QualityBtn'
import { isDesktopLyricSupported } from '@/utils/nativeModules/lyricDesktop'

export default () => {
  return (
    <View style={styles.container}>
      {/*
        只在支持的平台渲染桌面歌词按钮（仅 Android）。
        之前无论是否支持都占一个 flex:1 的格子，iOS 上这格是空的，
        导致整排按钮整体偏右、左侧留白过多。
      */}
      {isDesktopLyricSupported ? <View style={styles.cell}><DesktopLyricBtn /></View> : null}
      <View style={styles.cell}><MusicAddBtn /></View>
      <View style={styles.cell}><PlayModeBtn /></View>
      <View style={styles.cell}><CommentBtn /></View>
      <View style={styles.cell}><QualityBtn /></View>
    </View>
  )
}


const styles = createStyle({
  container: {
    width: '100%',
    flexDirection: 'row',
    alignItems: 'center',
    // 整体居中：剩余按钮等分并铺满，左右留白对称
    justifyContent: 'center',
    paddingHorizontal: '4%',
  },
  // 每格等分，保证按钮水平对齐、间隔一致
  cell: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
})
