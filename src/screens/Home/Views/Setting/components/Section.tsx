import { View, StyleSheet } from 'react-native'

import { createStyle } from '@/utils/tools'
import { useTheme } from '@/store/theme/hook'
import Text from '@/components/common/Text'
import { useGlass, useMd3 } from '@/theme/glass'
import GlassView from '@/components/common/GlassView'


interface Props {
  title: string
  children: React.ReactNode | React.ReactNode[]
}

export default ({ title, children }: Props) => {
  const theme = useTheme()
  const glass = useGlass()
  const md3 = useMd3()

  // MD3 主题：M3 Card 规格（surfaceContainer + 16dp 圆角 + elevation 1）
  if (md3.isMd3) {
    return (
      <View style={[styles.container, md3.card(), {
        paddingTop: md3.spacing.lg,
        paddingBottom: md3.spacing.md,
        marginBottom: md3.spacing.lg,
        marginHorizontal: md3.spacing.sm + md3.spacing.xs,
      }]}>
        <Text
          style={{ ...styles.title, borderLeftWidth: 0, marginLeft: md3.spacing.lg, marginBottom: md3.spacing.md }}
          size={16}
          color={md3.surface.primary}
        >{title}</Text>
        <View>{children}</View>
      </View>
    )
  }

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
