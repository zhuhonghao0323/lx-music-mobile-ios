import { TouchableOpacity, StyleSheet } from 'react-native'
import { Icon } from '@/components/common/Icon'
import { createStyle } from '@/utils/tools'
import { useTheme } from '@/store/theme/hook'
import { scaleSizeW } from '@/utils/pixelRatio'
import { useIsGlass } from '@/theme/glass'
import { haptic } from '@/utils/haptics'

export const BTN_WIDTH = scaleSizeW(36)
export const BTN_ICON_SIZE = 24

export default ({ icon, color, onPress, onLongPress }: {
  icon: string
  color?: string
  onPress: () => void
  onLongPress?: () => void
}) => {
  const theme = useTheme()
  const isGlass = useIsGlass()
  return (
    <TouchableOpacity
      style={StyleSheet.compose({ ...styles.cotrolBtn, width: BTN_WIDTH, height: BTN_WIDTH }, isGlass ? {
        backgroundColor: 'rgba(255, 255, 255, 0.14)',
        borderWidth: StyleSheet.hairlineWidth,
        borderColor: 'rgba(255, 255, 255, 0.35)',
        borderRadius: BTN_WIDTH / 2,
        shadowColor: 'rgba(6, 10, 30, 0.5)',
        shadowOffset: { width: 0, height: 4 },
        shadowOpacity: 0.3,
        shadowRadius: 10,
      } : {})}
      activeOpacity={0.5}
      onPress={() => { haptic.tap(); onPress() }}
      onLongPress={onLongPress ? () => { haptic.longPress(); onLongPress() } : undefined}
    >
      <Icon name={icon} color={color ?? (isGlass ? '#f4f8ff' : theme['c-font-label'])} size={BTN_ICON_SIZE} />
    </TouchableOpacity>
  )
}

const styles = createStyle({
  cotrolBtn: {
    justifyContent: 'center',
    alignItems: 'center',

    // backgroundColor: '#ccc',
  },
})
