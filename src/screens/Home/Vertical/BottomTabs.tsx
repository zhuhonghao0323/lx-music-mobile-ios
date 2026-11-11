import { memo, useCallback } from 'react'
import { View, TouchableOpacity, StyleSheet } from 'react-native'
import { useTheme } from '@/store/theme/hook'
import { useNavActiveId } from '@/store/common/hook'
import { useI18n } from '@/lang'
import { createStyle } from '@/utils/tools'
import { Icon } from '@/components/common/Icon'
import Text from '@/components/common/Text'
import { scaleSizeW } from '@/utils/pixelRatio'
import { useIsGlass } from '@/theme/glass'
import { haptic } from '@/utils/haptics'
import { setNavActiveId } from '@/core/common'
import { NAV_MENUS } from '@/config/constant'
import { useIsPlay } from '@/store/player/hook'

/**
 * 底部主导航（三 Tab）。
 *
 * 对标波点音乐：固定「主页 / 正在播放 / 我的」三项。
 * 「正在播放」在有歌曲播放时显示播放态标识（小圆点）。
 */
export default memo(() => {
  const theme = useTheme()
  const t = useI18n()
  const isGlass = useIsGlass()
  const activeId = useNavActiveId()
  const isPlay = useIsPlay()

  const handlePress = useCallback((id: typeof NAV_MENUS[number]['id']) => {
    if (id == activeId) return
    haptic.select()
    setNavActiveId(id)
  }, [activeId])

  return (
    <View
      style={StyleSheet.compose(styles.container, {
        borderTopColor: isGlass ? 'rgba(255,255,255,0.10)' : theme['c-list-header-border-bottom'],
      })}
    >
      {
        NAV_MENUS.map((menu) => {
          const active = menu.id == activeId
          return (
            <TouchableOpacity
              key={menu.id}
              style={styles.tab}
              activeOpacity={0.7}
              onPress={() => { handlePress(menu.id) }}
            >
              <View>
                <Icon
                  name={menu.icon}
                  size={19}
                  color={active ? theme['c-primary-font'] : theme['c-font-label']}
                />
                {/* 正在播放 Tab：播放中时右上角显示一个小圆点 */}
                {menu.id == 'nav_player' && isPlay
                  ? <View style={[styles.playingDot, { backgroundColor: theme['c-primary-font'] }]} />
                  : null}
              </View>
              <Text
                style={styles.label}
                size={10}
                color={active ? theme['c-primary-font'] : theme['c-font-label']}
                numberOfLines={1}
              >{t(menu.id)}</Text>
            </TouchableOpacity>
          )
        })
      }
    </View>
  )
})

const styles = createStyle({
  container: {
    flexDirection: 'row',
    borderTopWidth: StyleSheet.hairlineWidth,
    paddingTop: scaleSizeW(5),
    paddingBottom: scaleSizeW(2),
  },
  tab: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    minHeight: 44,
  },
  label: {
    marginTop: scaleSizeW(2),
  },
  playingDot: {
    position: 'absolute',
    top: -1,
    right: -3,
    width: scaleSizeW(5),
    height: scaleSizeW(5),
    borderRadius: scaleSizeW(2.5),
  },
})
