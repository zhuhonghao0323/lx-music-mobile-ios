import { memo, useCallback, useMemo, useRef } from 'react'
import { View, TouchableOpacity, Animated, Image } from 'react-native'
import { useNavActiveId } from '@/store/common/hook'
import { useI18n } from '@/lang'
import { createStyle } from '@/utils/tools'
import Text from '@/components/common/Text'
import GlassView from '@/components/common/GlassView'
import { scaleSizeW } from '@/utils/pixelRatio'
import { useWindowSize } from '@/utils/hooks'
import { useBrandColor, useTokenColor } from '@/theme/glassMaterial'
import { haptic } from '@/utils/haptics'
import { setNavActiveId } from '@/core/common'
import { popToRoot } from '@/navigation/utils'
import commonState from '@/store/common/state'

// 图片资源：项目未声明 png 模块类型，沿用 require + eslint-disable 的既有写法
// eslint-disable-next-line @typescript-eslint/no-var-requires
const homeIcon = require('@/resources/images/nav_home.png')
// eslint-disable-next-line @typescript-eslint/no-var-requires
const mineIcon = require('@/resources/images/nav_mine.png')

/**
 * 单个导航图标（主页 / 我的）。
 * 设计：无独立背景圆片，图标+文字直接落在统一玻璃托盘内；
 * 选中态用品牌色的淡底圆标出，未选中为次级灰，形成克制的层级。
 */
const SideButton = memo(({ source, active, label, onPress }: {
  source: number
  active: boolean
  label: string
  onPress: () => void
}) => {
  const colors = useTokenColor()
  const brand = useBrandColor()
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
      style={styles.sideWrap}
    >
      <Animated.View
        style={[styles.sideCircle, {
          transform: [{ scale }],
          backgroundColor: active ? 'rgba(245, 179, 89, 0.16)' : 'transparent',
        }]}
      >
        <Image
          source={source}
          style={[styles.icon, { tintColor: active ? brand : colors.textSecondary }]}
          resizeMode="contain"
        />
        <Text
          style={styles.sideLabel}
          size={10}
          color={active ? brand : colors.textSecondary}
          numberOfLines={1}
        >{label}</Text>
      </Animated.View>
    </TouchableOpacity>
  )
})

/**
 * 统一底部导航（主页 / 中间插槽 / 我的）。
 *
 * 产品级重构：整个底部栏 = 一个 floating Liquid Glass 悬浮托盘，
 * 主页圆钮、迷你条胶囊、我的圆钮都落在同一材质内，不再各自独立成块。
 * - 悬浮在内容上方，四周留 12pt 边距，底部留安全区
 * - 中间插槽：Home 非播放 Tab 传胶囊；播放 Tab 传大播放键
 * - 独立页点图标先 popToRoot 再切 Tab
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
      const homeId = commonState.componentIds.home
      if (homeId) void popToRoot(homeId)
      setTimeout(() => { setNavActiveId(id) }, 60)
    } else {
      setNavActiveId(id)
    }
  }, [isOverlay])

  const isHomeActive = !isOverlay && activeId == 'nav_home'
  const isMineActive = !isOverlay && activeId == 'nav_mine'

  return (
    <View style={styles.wrap}>
      <GlassView material="floating" style={styles.tray}>
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
      </GlassView>
    </View>
  )
})

const styles = createStyle({
  wrap: {
    // 悬浮：四周留边距，不贴边
    marginHorizontal: scaleSizeW(12),
    marginBottom: scaleSizeW(8),
  },
  tray: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: scaleSizeW(8),
    paddingVertical: scaleSizeW(6),
  },
  centerSlot: {
    flexShrink: 0,
    flexGrow: 0,
    marginHorizontal: scaleSizeW(6),
  },
  sideWrap: {
    alignItems: 'center',
    justifyContent: 'center',
  },
  sideCircle: {
    width: scaleSizeW(56),
    height: scaleSizeW(52),
    borderRadius: scaleSizeW(20),
    alignItems: 'center',
    justifyContent: 'center',
  },
  icon: {
    width: scaleSizeW(24),
    height: scaleSizeW(24),
  },
  sideLabel: {
    marginTop: scaleSizeW(1),
  },
})
