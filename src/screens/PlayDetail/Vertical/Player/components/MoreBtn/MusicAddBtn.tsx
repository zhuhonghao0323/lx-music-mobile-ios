import { View, TouchableOpacity } from 'react-native'
import FavoriteBtn from '@/screens/PlayDetail/components/FavoriteBtn'
import FavoriteIcon from '@/screens/PlayDetail/components/FavoriteIcon'
import { createStyle } from '@/utils/tools'
import { useTheme } from '@/store/theme/hook'
import { BTN_WIDTH, BTN_ICON_SIZE } from './Btn'


export default () => {
  const theme = useTheme()
  return (
    <FavoriteBtn>
      {({ favorited, onPress, onLongPress, setAnchorRef }) => (
        // 外层 View 作为测量锚点：尺寸恒等于按钮，避免不同父容器下 measure 偏差
        <View ref={setAnchorRef} style={{ width: BTN_WIDTH, height: BTN_WIDTH }}>
          <TouchableOpacity
            style={{ ...styles.cotrolBtn, width: BTN_WIDTH, height: BTN_WIDTH }}
            activeOpacity={0.5}
            onPress={onPress}
            onLongPress={onLongPress}
          >
            <FavoriteIcon favorited={favorited} iconSize={BTN_ICON_SIZE} emptyColor={theme['c-font-label']} />
          </TouchableOpacity>
        </View>
      )}
    </FavoriteBtn>
  )
}

const styles = createStyle({
  cotrolBtn: {
    marginLeft: 5,
    justifyContent: 'center',
    alignItems: 'center',
  },
})
