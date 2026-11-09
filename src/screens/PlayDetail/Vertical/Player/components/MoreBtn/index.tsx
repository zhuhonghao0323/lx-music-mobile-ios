import { createStyle } from '@/utils/tools'
import { View } from 'react-native'
import PlayModeBtn from './PlayModeBtn'
import MusicAddBtn from './MusicAddBtn'
import DesktopLyricBtn from './DesktopLyricBtn'
import CommentBtn from './CommentBtn'
import QualityBtn from './QualityBtn'

export default () => {
  return (
    <View style={styles.container}>
      <View style={styles.cell}><DesktopLyricBtn /></View>
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
    justifyContent: 'space-between',
  },
  // 每格等分，保证按钮水平对齐、间隔一致
  cell: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
})
