import { memo, useMemo, useRef } from 'react'
import { TouchableOpacity, View, StyleSheet } from 'react-native'
import Text from '@/components/common/Text'
import Menu, { type MenuType, type Menus, type Position } from '@/components/common/Menu'
import { useTheme } from '@/store/theme/hook'
import { useSettingValue } from '@/store/setting/hook'
import { useUserApiList } from '@/store/userApi'
import { setApiSource } from '@/core/apiSource'
import { getSourceDisplayName } from '@/core/customSource'
import { scaleSizeW } from '@/utils/pixelRatio'
import { haptic } from '@/utils/haptics'

/**
 * 播放按钮上方的「当前音源」小字标签，点击可手动切换自定义音源。
 * 只列出自定义源（user_api_*），第一个为默认音源。
 */
export default memo(() => {
  const theme = useTheme()
  const currentSourceId = useSettingValue('common.apiSource')
  const userApiList = useUserApiList()
  const menuRef = useRef<MenuType>(null)
  const btnRef = useRef<TouchableOpacity>(null)

  const menus = useMemo<Menus>(() => userApiList.map(item => ({
    action: item.id,
    label: item.name,
  })), [userApiList])

  const currentName = userApiList.length
    ? getSourceDisplayName(currentSourceId)
    : '--'

  const showMenu = () => {
    if (!userApiList.length) return
    haptic.tap()
    btnRef.current?.measure((_x, _y, w, h, px, py) => {
      const position: Position = { x: Math.ceil(px), y: Math.ceil(py), w: Math.ceil(w), h: Math.ceil(h) }
      menuRef.current?.show(position, { width: Math.max(Math.ceil(w), 120), height: 40 })
    })
  }

  const handleSelect = (menu: Menus[number]) => {
    if (menu.action == currentSourceId) return
    haptic.select()
    setApiSource(menu.action)
  }

  return (
    <View style={styles.wrap}>
      <TouchableOpacity ref={btnRef} style={styles.btn} activeOpacity={0.6} onPress={showMenu}>
        <Text size={11} color={theme['c-font-label']} numberOfLines={1}>
          {currentName}
        </Text>
      </TouchableOpacity>
      <Menu
        ref={menuRef}
        menus={menus}
        activeId={currentSourceId}
        center
        onPress={handleSelect}
      />
    </View>
  )
})

const styles = StyleSheet.create({
  wrap: {
    width: '100%',
    alignItems: 'center',
    justifyContent: 'center',
    paddingTop: scaleSizeW(2),
  },
  btn: {
    paddingHorizontal: scaleSizeW(10),
    paddingVertical: scaleSizeW(2),
    maxWidth: '70%',
  },
})
