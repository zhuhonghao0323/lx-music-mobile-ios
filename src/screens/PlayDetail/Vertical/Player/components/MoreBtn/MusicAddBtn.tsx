import { TouchableOpacity } from 'react-native'
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
        <TouchableOpacity
          ref={setAnchorRef as unknown as React.LegacyRef<TouchableOpacity>}
          style={{ ...styles.cotrolBtn, width: BTN_WIDTH, height: BTN_WIDTH }}
          activeOpacity={0.5}
          onPress={onPress}
          onLongPress={onLongPress}
        >
          <FavoriteIcon favorited={favorited} iconSize={BTN_ICON_SIZE} emptyColor={theme['c-font-label']} />
        </TouchableOpacity>
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
