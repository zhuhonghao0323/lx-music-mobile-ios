import { memo, useMemo } from 'react'
import { View, StyleSheet } from 'react-native'
import { useKeyboard } from '@/utils/hooks'

import Pic from './components/Pic'
import Title from './components/Title'
import PlayInfo from './components/PlayInfo'
import ControlBtn from './components/ControlBtn'
import { createStyle } from '@/utils/tools'
// import { useSettingValue } from '@/store/setting/hook'
import { useSettingValue } from '@/store/setting/hook'
import { useIsGlass } from '@/theme/glass'


export default memo(({ isHome = false }: { isHome?: boolean }) => {
  // const { onLayout, ...layout } = useLayout()
  const { keyboardShown } = useKeyboard()
  const isGlass = useIsGlass()
  const autoHidePlayBar = useSettingValue('common.autoHidePlayBar')

  const playerComponent = useMemo(() => (
    <View
      style={StyleSheet.compose(
        styles.container,
        // 悬浮胶囊：无横框背景，靠半透明底 + 圆角 + 3D 立体阴影形成「浮起」质感
        {
          backgroundColor: isGlass ? 'rgba(28,24,24,0.70)' : 'rgba(24,22,22,0.92)',
          borderRadius: 24,
          borderWidth: StyleSheet.hairlineWidth,
          borderTopColor: 'rgba(255,255,255,0.30)',
          borderLeftColor: 'rgba(255,255,255,0.18)',
          borderRightColor: 'rgba(255,255,255,0.12)',
          borderBottomColor: 'rgba(0,0,0,0.30)',
          overflow: 'hidden',
          shadowColor: 'rgba(0,0,0,0.55)',
          shadowOffset: { width: 0, height: 10 },
          shadowOpacity: 0.5,
          shadowRadius: 18,
          elevation: 10,
        },
      )}
    >
      {/* 顶部高光条：模拟玻璃受光，增强立体感 */}
      <View pointerEvents="none" style={styles.glassSheen} />
      <Pic isHome={isHome} />
      <View style={styles.center}>
        <Title isHome={isHome} />
        <PlayInfo isHome={isHome} />
      </View>
      <View style={styles.right}>
        <ControlBtn />
      </View>
    </View>
  ), [isHome, isGlass])

  return autoHidePlayBar && keyboardShown ? null : playerComponent
})


const styles = createStyle({
  container: {
    width: '100%',
    paddingVertical: 5,
    paddingLeft: 5,
    flexDirection: 'row',
    alignItems: 'center',
    elevation: 10,
  },
  // 顶部高光条：玻璃受光，3D 立体感
  glassSheen: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    height: '50%',
    backgroundColor: 'rgba(255,255,255,0.08)',
    borderTopLeftRadius: 24,
    borderTopRightRadius: 24,
  },
  left: {
    // borderRadius: 3,
    flexGrow: 0,
    flexShrink: 0,
  },
  center: {
    flexDirection: 'column',
    flexGrow: 1,
    flexShrink: 1,
    paddingLeft: 5,
    height: '100%',
    // justifyContent: 'space-evenly',
    // height: 48,
    // backgroundColor: 'rgba(0, 0, 0, .1)',
  },
  right: {
    flexDirection: 'row',
    alignItems: 'center',
    flexGrow: 0,
    flexShrink: 0,
    paddingLeft: 5,
    paddingRight: 5,
  },
  // row: {
  //   flexDirection: 'row',
  //   flexGrow: 0,
  //   flexShrink: 0,
  // },
})
