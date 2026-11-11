import { memo, useCallback, useRef } from 'react'
import { View, TouchableOpacity, Animated, StyleSheet } from 'react-native'
import { useTheme } from '@/store/theme/hook'
import { useNavActiveId } from '@/store/common/hook'
import { useI18n } from '@/lang'
import { createStyle } from '@/utils/tools'
import { Icon } from '@/components/common/Icon'
import Text from '@/components/common/Text'
import { scaleSizeW } from '@/utils/pixelRatio'
import { haptic } from '@/utils/haptics'
import { setNavActiveId } from '@/core/common'

/** 单个悬浮导航图标（主页 / 我的），带按压回弹与 3D 液态质感 */
const SideButton = memo(({ icon, active, label, onPress }: {
  icon: string
  active: boolean
  label: string
  onPress: () => void
}) => {
  const theme = useTheme()
  const scale = useRef(new Animated.Value(1)).current

  const animateTo = (to: number) => {
    Animated.spring(scale, { toValue: to, friction: 6, tension: 160, useNativeDriver: true }).start()
  }

  return (
    <TouchableOpacity
      activeOpacity={1}
      onPress={onPress}
      onPressIn={() => { animateTo(0.9) }}
      onPressOut={() => { animateTo(1) }}
      accessibilityRole="button"
      accessibilityLabel={label}
    >
      <Animated.View style={[styles.sideCircle, { transform: [{ scale }] }]}>
        <View pointerEvents="none" style={styles.sideSheen} />
        <Icon name={icon} size={20} color={active ? theme['c-primary-font'] : theme['c-font-label']} />
        <Text
          style={styles.sideLabel}
          size={9}
          color={active ? theme['c-primary-font'] : theme['c-font-label']}
          numberOfLines={1}
        >{label}</Text>
      </Animated.View>
    </TouchableOpacity>
  )
})

/**
 * 底部导航：左「主页」图标 + 中间插槽（迷你条胶囊）+ 右「我的」图标。
 *
 * - 左右两个图标无背景、无横框，悬浮 + 3D 液态质感
 * - 中间插槽由父组件传入 PlayerBar（原迷你条改造的胶囊）
 * - 播放页时中间插槽为 null，只留左右图标
 */
export default memo(({ children }: { children?: React.ReactNode }) => {
  const t = useI18n()
  const activeId = useNavActiveId()

  const handlePress = useCallback((id: 'nav_home' | 'nav_mine') => {
    if (id == activeId) return
    haptic.select()
    setNavActiveId(id)
  }, [activeId])

  return (
    <View style={styles.wrap}>
      <SideButton
        icon="home"
        active={activeId == 'nav_home'}
        label={t('nav_home')}
        onPress={() => { handlePress('nav_home') }}
      />
      {/* 中间插槽：迷你条胶囊 */}
      <View style={styles.centerSlot}>{children}</View>
      <SideButton
        icon="love"
        active={activeId == 'nav_mine'}
        label={t('nav_mine')}
        onPress={() => { handlePress('nav_mine') }}
      />
    </View>
  )
})

const styles = createStyle({
  wrap: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: scaleSizeW(12),
    paddingBottom: scaleSizeW(4),
  },
  centerSlot: {
    flex: 1,
    marginHorizontal: scaleSizeW(8),
  },
  sideCircle: {
    width: scaleSizeW(52),
    height: scaleSizeW(52),
    borderRadius: scaleSizeW(26),
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: 'rgba(255,255,255,0.10)',
    borderWidth: StyleSheet.hairlineWidth,
    borderTopColor: 'rgba(255,255,255,0.40)',
    borderLeftColor: 'rgba(255,255,255,0.22)',
    borderRightColor: 'rgba(255,255,255,0.14)',
    borderBottomColor: 'rgba(0,0,0,0.25)',
    shadowColor: 'rgba(0,0,0,0.45)',
    shadowOffset: { width: 0, height: 6 },
    shadowOpacity: 0.4,
    shadowRadius: 12,
    elevation: 8,
    overflow: 'hidden',
  },
  sideSheen: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    height: '52%',
    backgroundColor: 'rgba(255,255,255,0.14)',
  },
  sideLabel: {
    marginTop: scaleSizeW(1),
  },
})
