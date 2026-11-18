import { forwardRef, useImperativeHandle, useRef } from 'react'
import { View } from 'react-native'

// import { useGetter, useDispatch } from '@/store'
// import Tag from './Tag'
// import OpenList from './OpenList'
import { createStyle } from '@/utils/tools'
// import { BorderWidths } from '@/theme'
import SourceSelector, {
  type SourceSelectorType,
} from './SourceSelector'
import { useTheme } from '@/store/theme/hook'
// import { BorderWidths } from '@/theme'
import ActiveListName, { type ActiveListNameType } from './ActiveListName'
import { BorderWidths } from '@/theme'

export interface HeaderBarProps {
  onShowBound: () => void
  onSourceChange: (source: LX.OnlineSource) => void
}

export interface HeaderBarType {
  setBound: (source: LX.OnlineSource, id: string, name: string) => void
}


export default forwardRef<HeaderBarType, HeaderBarProps>(({ onShowBound, onSourceChange }, ref) => {
  const activeListNameRef = useRef<ActiveListNameType>(null)
  const sourceSelectorRef = useRef<SourceSelectorType>(null)
  const theme = useTheme()

  useImperativeHandle(ref, () => ({
    setBound(source, id, name) {
      sourceSelectorRef.current?.setSource(source)
      activeListNameRef.current?.setBound(id, name)
    },
  }), [])


  return (
    <View style={{ ...styles.currentList, borderBottomColor: theme['c-border-background'] }}>
      {/* 音源筛选已统一到首页顶栏的音乐图标，此处不再显示「小蜗音乐」文字下拉 */}
      <SourceSelector ref={sourceSelectorRef} onSourceChange={onSourceChange} style={styles.hiddenSelector} />
      <ActiveListName ref={activeListNameRef} onShowBound={onShowBound} />
    </View>
  )
})

const styles = createStyle({
  currentList: {
    flexDirection: 'row',
    height: 38,
    zIndex: 2,
    // paddingRight: 10,
    borderBottomWidth: BorderWidths.normal,
  },
  selector: {
    width: 86,
  },
  // 音源筛选已统一到首页音乐图标，这里只保留组件实例供 setBound 同步状态
  hiddenSelector: {
    width: 0,
    opacity: 0,
  },
})
