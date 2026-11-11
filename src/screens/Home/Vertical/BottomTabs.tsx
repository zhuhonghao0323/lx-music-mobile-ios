import { memo, useCallback, useEffect, useMemo, useRef } from 'react'
import { View, TouchableOpacity, Animated, StyleSheet } from 'react-native'
import { useTheme } from '@/store/theme/hook'
import { useNavActiveId } from '@/store/common/hook'
import { useI18n } from '@/lang'
import { createStyle } from '@/utils/tools'
import { Icon } from '@/components/common/Icon'
import Text from '@/components/common/Text'
import Image from '@/components/common/Image'
import { scaleSizeW } from '@/utils/pixelRatio'
import { useIsGlass } from '@/theme/glass'
import { haptic } from '@/utils/haptics'
import { setNavActiveId } from '@/core/common'
import { useIsPlay, usePlayerMusicInfo } from '@/store/player/hook'

/**
 * 底部主导航（对标波点音乐的悬浮胶囊导航）。
 *
 * 视觉与交互要点：
 * - 整条导航悬浮在屏幕底部上方一段距离，圆角胶囊，不贴边
 * - 停在「主页 / 我的」时：三个圆形按钮
 * - 停在「正在播放」时：中间按钮展开成椭圆胶囊，显示迷你封面 + 歌名歌手
 * - 展开/收起用 spring 过渡，避免生硬跳变
 */
export default memo(() => {
  const theme = useTheme()
  const t = useI18n()
  const isGlass = useIsGlass()
  const activeId = useNavActiveId()
  const isPlay = useIsPlay()
  const musicInfo = usePlayerMusicInfo()

  // 中间胶囊的展开进度：0 = 圆形按钮，1 = 椭圆胶囊
  const expand = useRef(new Animated.Value(activeId == 'nav_player' ? 1 : 0)).current
  useEffect(() => {
    Animated.spring(expand, {
      toValue: activeId == 'nav_player' ? 1 : 0,
      friction: 9,
      tension: 90,
      useNativeDriver: false,
    }).start()
  }, [activeId, expand])

  const handlePress = useCallback((id: 'nav_home' | 'nav_player' | 'nav_mine') => {
    if (id == activeId) return
    haptic.select()
    setNavActiveId(id)
  }, [activeId])

  const barBg = isGlass ? 'rgba(28,24,24,0.72)' : theme['c-content-background']
  const pillBg = isGlass ? 'rgba(255,255,255,0.10)' : theme['c-primary-light-500-alpha-800']

  // 中间按钮宽度：从圆形 46 展开到胶囊 168
  const centerWidth = expand.interpolate({ inputRange: [0, 1], outputRange: [scaleSizeW(46), scaleSizeW(168)] })
  const centerRadius = expand.interpolate({ inputRange: [0, 1], outputRange: [scaleSizeW(23), scaleSizeW(23)] })
  const labelOpacity = expand.interpolate({ inputRange: [0, 0.4, 1], outputRange: [1, 0, 0] })
  const infoOpacity = expand.interpolate({ inputRange: [0.35, 1], outputRange: [0, 1] })

  const sideButton = useMemo(() => (id: 'nav_home' | 'nav_mine', icon: string) => {
    const active = activeId == id
    return (
      <TouchableOpacity
        key={id}
        style={styles.sideBtn}
        activeOpacity={0.7}
        onPress={() => { handlePress(id) }}
      >
        <Icon name={icon} size={19} color={active ? theme['c-primary-font'] : theme['c-font-label']} />
        <Text
          style={styles.sideLabel}
          size={9}
          color={active ? theme['c-primary-font'] : theme['c-font-label']}
          numberOfLines={1}
        >{t(id)}</Text>
      </TouchableOpacity>
    )
  }, [activeId, handlePress, t, theme])

  return (
    <View style={styles.wrap} pointerEvents="box-none">
      <View
        style={StyleSheet.compose(styles.bar, {
          backgroundColor: barBg,
          borderColor: isGlass ? 'rgba(255,255,255,0.14)' : theme['c-list-header-border-bottom'],
        })}
      >
        {sideButton('nav_home', 'home')}

        {/* 中间：圆形 ↔ 椭圆胶囊 */}
        <Animated.View style={[styles.centerWrap, { width: centerWidth }]}>
          <TouchableOpacity
            style={[styles.centerBtn, { width: centerWidth, borderRadius: centerRadius, backgroundColor: pillBg }]}
            activeOpacity={0.8}
            onPress={() => { handlePress('nav_player') }}
          >
            {/* 收起态：播放图标 + 文字 */}
            <Animated.View style={[styles.centerCollapsed, { opacity: labelOpacity }]} pointerEvents="none">
              <Icon name="play" size={18} color={activeId == 'nav_player' ? theme['c-primary-font'] : theme['c-font-label']} />
              <Text style={styles.centerLabel} size={9} color={activeId == 'nav_player' ? theme['c-primary-font'] : theme['c-font-label']}>正在播放</Text>
            </Animated.View>
            {/* 展开态：迷你封面 + 歌名歌手 */}
            <Animated.View style={[styles.centerExpanded, { opacity: infoOpacity }]} pointerEvents="none">
              <Image
                url={musicInfo.pic}
                style={[styles.miniCover, { backgroundColor: isGlass ? 'rgba(255,255,255,0.10)' : theme['c-primary-light-400-alpha-700'] }]}
              />
              <View style={styles.miniInfo}>
                <Text size={12} color={theme['c-font']} numberOfLines={1} style={styles.miniName}>{musicInfo.name || t('nav_player')}</Text>
                <Text size={10} color={theme['c-font-label']} numberOfLines={1}>{musicInfo.singer}</Text>
              </View>
              {isPlay
                ? <View style={[styles.playingDot, { backgroundColor: theme['c-primary-font'] }]} />
                : null}
            </Animated.View>
          </TouchableOpacity>
        </Animated.View>

        {sideButton('nav_mine', 'love')}
      </View>
    </View>
  )
})

const styles = createStyle({
  wrap: {
    // 悬浮：贴着屏幕下边缘但留一段距离（波点的观感）
    paddingHorizontal: scaleSizeW(14),
    paddingBottom: scaleSizeW(6),
    paddingTop: scaleSizeW(4),
  },
  bar: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    height: scaleSizeW(54),
    borderRadius: scaleSizeW(27),
    borderWidth: StyleSheet.hairlineWidth,
    paddingHorizontal: scaleSizeW(10),
  },
  sideBtn: {
    width: scaleSizeW(48),
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: scaleSizeW(4),
  },
  sideLabel: {
    marginTop: scaleSizeW(1),
  },
  centerWrap: {
    alignItems: 'center',
    justifyContent: 'center',
  },
  centerBtn: {
    height: scaleSizeW(46),
    alignItems: 'center',
    justifyContent: 'center',
    overflow: 'hidden',
  },
  centerCollapsed: {
    alignItems: 'center',
    justifyContent: 'center',
  },
  centerLabel: {
    marginTop: scaleSizeW(1),
  },
  centerExpanded: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: scaleSizeW(8),
    width: '100%',
  },
  miniCover: {
    width: scaleSizeW(32),
    height: scaleSizeW(32),
    borderRadius: scaleSizeW(8),
  },
  miniInfo: {
    flex: 1,
    marginLeft: scaleSizeW(8),
  },
  miniName: {
    fontWeight: '600',
  },
  playingDot: {
    width: scaleSizeW(6),
    height: scaleSizeW(6),
    borderRadius: scaleSizeW(3),
    marginLeft: scaleSizeW(4),
  },
})
