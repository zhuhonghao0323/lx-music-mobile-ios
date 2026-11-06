import { View, StyleSheet } from 'react-native'

import { createStyle } from '@/utils/tools'
import { useTheme } from '@/store/theme/hook'
import Text from '@/components/common/Text'
import { useGlass } from '@/theme/glass'


interface Props {
  title: string
  children: React.ReactNode | React.ReactNode[]
}

export default ({ title, children }: Props) => {
  const theme = useTheme()
  const glass = useGlass()

  return (
    <View style={StyleSheet.compose(styles.container, glass.isGlass ? {
      backgroundColor: 'rgba(255, 255, 255, 0.10)',
      borderWidth: StyleSheet.hairlineWidth,
      borderColor: 'rgba(255, 255, 255, 0.28)',
      borderRadius: 20,
      paddingTop: 14,
      paddingBottom: 12,
      marginBottom: 14,
      shadowColor: 'rgba(6, 10, 30, 0.5)',
      shadowOffset: { width: 0, height: 8 },
      shadowOpacity: 0.35,
      shadowRadius: 20,
      elevation: 6,
    } : {})}>
      <Text style={{ ...styles.title, borderLeftColor: glass.isGlass ? 'rgba(120, 190, 255, 0.95)' : theme['c-primary'], ...(glass.isGlass ? { marginLeft: 12 } : {}) }} size={16} color={glass.textColor()}>{title}</Text>
      <View>
        {children}
      </View>
      {glass.isGlass ? <View pointerEvents="none" style={glass.highlight()} /> : null}
    </View>
  )
}


const styles = createStyle({
  container: {
    // paddingLeft: 10,
    // backgroundColor: 'rgba(0,0,0,0.2)',
  },
  title: {
    borderLeftWidth: 5,
    paddingLeft: 12,
    marginBottom: 10,
    // lineHeight: 16,
  },
})
