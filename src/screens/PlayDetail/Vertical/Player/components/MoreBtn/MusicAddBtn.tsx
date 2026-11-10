import { StyleSheet, View, TouchableOpacity } from 'react-native'
import FavoriteBtn from '@/screens/PlayDetail/components/FavoriteBtn'
import FavoriteIcon from '@/screens/PlayDetail/components/FavoriteIcon'
import { createStyle } from '@/utils/tools'
import { useTheme } from '@/store/theme/hook'
import { useIsGlass } from '@/theme/glass'
import { scaleSizeW } from '@/utils/pixelRatio'
import { BTN_WIDTH, BTN_ICON_SIZE } from './Btn'

/** 玻璃主题下的圆形底直径，与 MoreBtn 中其它辅助按钮保持一致 */
const GLASS_CIRCLE_SIZE = Math.max(44, scaleSizeW(46))


export default () => {
  const theme = useTheme()
  const isGlass = useIsGlass()
  const boxSize = isGlass ? GLASS_CIRCLE_SIZE : BTN_WIDTH
  return (
    <FavoriteBtn>
      {({ favorited, onPress, onLongPress, setAnchorRef }) => (
        // 外层 View 作为测量锚点：尺寸恒等于按钮，避免不同父容器下 measure 偏差
        <View ref={setAnchorRef} style={{ width: boxSize, height: boxSize }}>
          <TouchableOpacity
            style={StyleSheet.compose(
              { ...styles.cotrolBtn, width: boxSize, height: boxSize },
              isGlass ? {
                backgroundColor: 'rgba(255, 255, 255, 0.09)',
                borderWidth: StyleSheet.hairlineWidth,
                borderTopColor: 'rgba(255, 255, 255, 0.30)',
                borderLeftColor: 'rgba(255, 255, 255, 0.20)',
                borderRightColor: 'rgba(255, 255, 255, 0.16)',
                borderBottomColor: 'rgba(255, 255, 255, 0.10)',
                borderRadius: boxSize / 2,
                shadowColor: 'rgba(6, 4, 4, 0.55)',
                shadowOffset: { width: 0, height: 8 },
                shadowOpacity: 0.4,
                shadowRadius: 18,
              } : {},
            )}
            activeOpacity={0.55}
            onPress={onPress}
            onLongPress={onLongPress}
          >
            <FavoriteIcon favorited={favorited} iconSize={BTN_ICON_SIZE - 2} emptyColor={isGlass ? '#F5F2F1' : theme['c-font-label']} />
          </TouchableOpacity>
        </View>
      )}
    </FavoriteBtn>
  )
}

const styles = createStyle({
  cotrolBtn: {
    justifyContent: 'center',
    alignItems: 'center',
  },
})
