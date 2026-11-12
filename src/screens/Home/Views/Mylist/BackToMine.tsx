import { memo, useCallback } from 'react'
import { View, TouchableOpacity, PanResponder } from 'react-native'
import { useTheme } from '@/store/theme/hook'
import { Icon } from '@/components/common/Icon'
import Text from '@/components/common/Text'
import { createStyle } from '@/utils/tools'
import { scaleSizeW } from '@/utils/pixelRatio'
import { haptic } from '@/utils/haptics'
import { setNavActiveId } from '@/core/common'
import { useStatusbarHeight } from '@/store/common/hook'
import { useI18n } from '@/lang'

/**
 * 「我的列表」页的返回栏。
 *
 * 从「我的」进入本页后，顶部显示返回按钮；同时在整页覆盖一层
 * 左滑手势：从屏幕左缘向右滑返回「我的」。
 */
export default memo(() => {
  const theme = useTheme()
  const t = useI18n()
  const statusBarHeight = useStatusbarHeight()

  const goBack = useCallback(() => {
    haptic.tap()
    setNavActiveId('nav_mine')
  }, [])

  // 左缘右滑返回：仅响应从屏幕左侧 40px 内起始的右滑，避免与列表横向手势冲突
  const backResponder = PanResponder.create({
    onStartShouldSetPanResponder: (evt) => evt.nativeEvent.pageX < 40,
    onMoveShouldSetPanResponder: (evt, gs) => evt.nativeEvent.pageX < 40 && gs.dx > 24 && Math.abs(gs.dx) > Math.abs(gs.dy) * 1.2,
    onPanResponderRelease: (_evt, gs) => {
      if (gs.dx > 70) goBack()
    },
  })

  return (
    <View style={styles.wrap}>
      {/* 整页左缘手势层（透明，只捕获屏幕左缘的右滑） */}
      <View style={styles.gestureLayer} {...backResponder.panHandlers} pointerEvents="box-none" />
      <View style={[styles.bar, { paddingTop: statusBarHeight + scaleSizeW(4) }]}>
        <TouchableOpacity style={styles.backBtn} hitSlop={{ top: 8, bottom: 8, left: 8, right: 8 }} onPress={goBack}>
          <Icon name="chevron-left" size={18} color={theme['c-font']} />
        </TouchableOpacity>
        <Text size={15} color={theme['c-font']} numberOfLines={1} style={styles.title}>{t('nav_mine')}</Text>
      </View>
    </View>
  )
})

const styles = createStyle({
  wrap: {
    width: '100%',
  },
  bar: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: scaleSizeW(8),
    paddingBottom: scaleSizeW(6),
  },
  backBtn: {
    width: scaleSizeW(36),
    height: scaleSizeW(36),
    alignItems: 'center',
    justifyContent: 'center',
  },
  title: {
    flex: 1,
    marginLeft: scaleSizeW(4),
    fontWeight: '600',
  },
  gestureLayer: {
    position: 'absolute',
    top: 0,
    bottom: 0,
    left: 0,
    width: 40,
    zIndex: 10,
  },
})
