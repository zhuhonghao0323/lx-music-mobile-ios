import { View, StyleSheet } from 'react-native'

import { createStyle } from '@/utils/tools'
import { useTheme } from '@/store/theme/hook'
import Text from '@/components/common/Text'
import { useGlass } from '@/theme/glass'
import GlassView from '@/components/common/GlassView'


interface Props {
  title: string
  children: React.ReactNode | React.ReactNode[]
}

export default ({ title, children }: Props) => {
  const theme = useTheme()
  const glass = useGlass()

  return (
    <GlassView
      material="thin"
      radius={20}
      style={StyleSheet.compose(styles.container, glass.isGlass ? {
        paddingTop: 14,
        paddingBottom: 12,
        marginBottom: 14,
        marginHorizontal: 6,
      } : {})}
    >
      <Text style={{ ...styles.title, borderLeftColor: glass.isGlass ? 'rgba(120, 190, 255, 0.95)' : theme['c-primary'], ...(glass.isGlass ? { marginLeft: 12 } : {}) }} size={16} color={glass.textColor()}>{title}</Text>
      <View>
        {children}
      </View>
    </GlassView>
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
