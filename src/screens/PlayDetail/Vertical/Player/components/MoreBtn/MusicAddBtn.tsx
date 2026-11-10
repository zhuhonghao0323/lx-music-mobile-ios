import { StyleSheet, View, TouchableOpacity } from 'react-native'
import FavoriteBtn from '@/screens/PlayDetail/components/FavoriteBtn'
import FavoriteIcon from '@/screens/PlayDetail/components/FavoriteIcon'
import { createStyle } from '@/utils/tools'
import { useTheme } from '@/store/theme/hook'
import { useIsGlass } from '@/theme/glass'
import { BTN_WIDTH, BTN_ICON_SIZE } from './Btn'
import { GLASS_CIRCLE_SIZE, glassCircleStyle } from './glassButton'


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
              styles.cotrolBtn,
              isGlass ? glassCircleStyle(boxSize) : { width: boxSize, height: boxSize },
            )}
            activeOpacity={0.55}
            onPress={onPress}
            onLongPress={onLongPress}
          >
            <FavoriteIcon favorited={favorited} iconSize={BTN_ICON_SIZE - 5} emptyColor={isGlass ? '#F5F2F1' : theme['c-font-label']} />
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
