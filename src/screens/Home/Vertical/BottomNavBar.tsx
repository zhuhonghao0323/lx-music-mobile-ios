import { memo, useCallback, useMemo, useRef } from 'react'
import { View, TouchableOpacity, Animated, Image, StyleSheet } from 'react-native'
import { useTheme } from '@/store/theme/hook'
import { useNavActiveId } from '@/store/common/hook'
import { useI18n } from '@/lang'
import { createStyle } from '@/utils/tools'
import Text from '@/components/common/Text'
import { scaleSizeW } from '@/utils/pixelRatio'
import { useWindowSize } from '@/utils/hooks'
import { haptic } from '@/utils/haptics'
import { setNavActiveId } from '@/core/common'
import { popToRoot } from '@/navigation/utils'
import commonState from '@/store/common/state'

// 图片资源：项目未声明 png 模块类型，沿用 require + eslint-disable 的既有写法
// eslint-disable-next-line @typescript-eslint/no-var-requires
const homeIcon = require('@/resources/images/nav_home.png')
// eslint-disable-next-line @typescript-eslint/no-var-requires
const mineIcon = require('@/resources/images/nav_mine.png')

/** 单个悬浮导航图标（首页 / 我的），带按压回弹与 3D 液态质感 */
const SideButton = memo(({ source, active, label, onPress }: {
  source: number
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
        <Image
          source={source}
          style={[styles.icon, { tintColor: active ? theme['c-primary-font'] : theme['c-font-label'] }]}
          resizeMode="contain"
        />
        <Text
          style={styles.sideLabel}
          size={10}
          color={active ? theme['c-primary-font'] : theme['c-font-label']}
          numberOfLines={1}
        >{label}</Text>
      </Animated.View>
    </TouchableOpacity>
  )
})

/**
 * 统一底部导航栏（主页 / 中间插槽 / 我的）。
 *
 * - 除播放页外，所有界面（Home 三个 Tab、歌单详情等独立页）都用这一套三图标结构
 * - 中间插槽由调用方传入：Home 非播放 Tab 传迷你条胶囊，播放 Tab 传 null（播放按钮在页面内部）
 * - 独立页（歌单详情等）点「首页/我的」时，先 pop 回根页面再切 Tab
 */
export default memo(({ children, isOverlay = false }: {
  children?: React.ReactNode
  /** 是否为独立页（需要 pop 回根页再切 Tab） */
  isOverlay?: boolean
}) => {
  const t = useI18n()
  const activeId = useNavActiveId()
  const windowSize = useWindowSize()

  // 中间胶囊固定为屏幕宽度的 1/3，不随内容长度变化
  const centerWidth = useMemo(() => Math.round(windowSize.width / 3), [windowSize.width])

  const handlePress = useCallback((id: 'nav_home' | 'nav_mine') => {
    haptic.select()
    if (isOverlay) {
      // 独立页：先退回根页，再切到目标 Tab
      const homeId = commonState.componentIds.home
      if (homeId) void popToRoot(homeId)
      // 稍作延迟确保 pop 完成后切 Tab
      setTimeout(() => { setNavActiveId(id) }, 60)
    } else {
      setNavActiveId(id)
    }
  }, [isOverlay])

  const isHomeActive = !isOverlay && activeId == 'nav_home'
  const isMineActive = !isOverlay && activeId == 'nav_mine'

  return (
    <View style={styles.wrap}>
      <SideButton
        source={homeIcon}
        active={isHomeActive}
        label={t('nav_home')}
        onPress={() => { handlePress('nav_home') }}
      />
      {/* 中间插槽：固定宽度（屏幕 1/3），不随内容变化 */}
      <View style={[styles.centerSlot, { width: centerWidth }]}>{children}</View>
      <SideButton
        source={mineIcon}
        active={isMineActive}
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
    justifyContent: 'center',
    // 左右按钮不再贴边，靠「主页/我的 与胶囊的间隙」撑开布局
    paddingHorizontal: scaleSizeW(10),
    paddingBottom: scaleSizeW(4),
  },
  centerSlot: {
    // 宽度由内联样式固定为屏幕 1/3
    flexShrink: 0,
    flexGrow: 0,
    // 与左右按钮的横向间隙扩大一倍（12 → 24），主页左移、我的右移
    marginHorizontal: scaleSizeW(24),
  },
  sideCircle: {
    width: scaleSizeW(54),
    height: scaleSizeW(54),
    // 圆形（灵动岛级别的圆角弧度）
    borderRadius: scaleSizeW(27),
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
  icon: {
    width: scaleSizeW(24),
    height: scaleSizeW(24),
  },
  sideLabel: {
    marginTop: scaleSizeW(1),
  },
})
