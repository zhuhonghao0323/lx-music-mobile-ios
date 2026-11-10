import { View } from 'react-native'

import { createStyle } from '@/utils/tools'
import { useTheme } from '@/store/theme/hook'
import Text from '@/components/common/Text'
import { useGlass, useMd3 } from '@/theme/glass'


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
    // 液态玻璃主题：设置分组不再铺玻璃底。
    // 之前每个 Section 都套 GlassView，而 GlassView 内含 BlurView + 色调层 + 高光层，
    // 叠加后每组之间会浮出一条明显的浅色横带（视觉上就是「浅色框」）。
    // 设计上设置项应直接贴在页面背景上，只靠标题的分隔感来分组。
    glass.isGlass
      ? (
          <View style={[styles.container, { paddingTop: 12, paddingBottom: 8, marginBottom: 6, marginHorizontal: 12 }]}>
            <Text style={{ ...styles.title, borderLeftColor: 'rgba(242, 120, 104, 0.95)', marginLeft: 4 }} size={16} color={glass.textColor()}>{title}</Text>
            <View>
              {children}
            </View>
          </View>
        )
      : (
          <View style={styles.container}>
            <Text style={{ ...styles.title, borderLeftColor: theme['c-primary'] }} size={16} color={theme['c-font']}>{title}</Text>
            <View>
              {children}
            </View>
          </View>
        )
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
