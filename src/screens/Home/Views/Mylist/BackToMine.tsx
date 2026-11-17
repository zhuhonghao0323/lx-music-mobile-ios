import { memo, useCallback } from 'react'
import { View, TouchableOpacity } from 'react-native'
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

  // 顶部功能：搜索当前列表 / 打开列表管理抽屉（内含排序、新建、导入导出）
  const handleSearch = useCallback(() => {
    haptic.tap()
    global.app_event.showListSearchBar()
  }, [])
  const handleSort = useCallback(() => {
    haptic.tap()
    global.app_event.changeLoveListVisible(true)
  }, [])

  return (
    <View style={styles.wrap}>
      <View style={[styles.bar, { paddingTop: statusBarHeight + scaleSizeW(4) }]}>
        <TouchableOpacity style={styles.backBtn} hitSlop={{ top: 8, bottom: 8, left: 8, right: 8 }} onPress={goBack}>
          <Icon name="chevron-left" size={18} color={theme['c-font']} />
        </TouchableOpacity>
        <Text size={15} color={theme['c-font']} numberOfLines={1} style={styles.title}>{t('nav_mine')}</Text>
        <TouchableOpacity style={styles.actionBtn} hitSlop={{ top: 8, bottom: 8, left: 8, right: 8 }} onPress={handleSort}>
          <Icon name="slider" size={19} color={theme['c-font']} />
        </TouchableOpacity>
        <TouchableOpacity style={styles.actionBtn} hitSlop={{ top: 8, bottom: 8, left: 8, right: 8 }} onPress={handleSearch}>
          <Icon name="search-2" size={19} color={theme['c-font']} />
        </TouchableOpacity>
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
  actionBtn: {
    width: scaleSizeW(34),
    height: scaleSizeW(34),
    alignItems: 'center',
    justifyContent: 'center',
  },
  title: {
    flex: 1,
    marginLeft: scaleSizeW(4),
    fontWeight: '600',
  },
})
