import { memo } from 'react'
import { View, StyleSheet } from 'react-native'

// import Title from './components/Title'
import MoreBtn from './components/MoreBtn'
import PlayInfo from './components/PlayInfo'
import ControlBtn from './components/ControlBtn'
import SourceBtn from './components/SourceBtn'
import { createStyle } from '@/utils/tools'
import { NAV_SHEAR_NATIVE_IDS } from '@/config/constant'
import { useIsGlass } from '@/theme/glass'
import GlassView from '@/components/common/GlassView'


export default memo(() => {
  const isGlass = useIsGlass()

  // 液态玻璃主题：按设计稿，控制区直接浮在环境背景之上，
  // 不套任何圆角矩形玻璃容器（否则会出现一圈方框，与设计不符）。
  if (isGlass) {
    return (
      <View
        style={StyleSheet.compose(styles.container, styles.glassContainer)}
        nativeID={NAV_SHEAR_NATIVE_IDS.playDetail_player}
      >
        <PlayInfo />
        <SourceBtn />
        <ControlBtn />
        <MoreBtn />
      </View>
    )
  }

  return (
    <GlassView
      material="thin"
      radius={26}
      style={styles.container}
      nativeID={NAV_SHEAR_NATIVE_IDS.playDetail_player}
    >
      <PlayInfo />
      <SourceBtn />
      <ControlBtn />
      <MoreBtn />
    </GlassView>
  )
})

const styles = createStyle({
  container: {
    flex: 0,
    width: '100%',
    paddingHorizontal: 15,
    paddingBottom: 15,
    paddingTop: 5,
    flexDirection: 'column',
  },
  // 设计稿：底部控制组贴近安全区，不需要额外外边距/底色
  glassContainer: {
    paddingHorizontal: 20,
    paddingBottom: 6,
    paddingTop: 0,
    backgroundColor: 'transparent',
  },
  status: {
    marginTop: 10,
    flexDirection: 'column',
    flex: 0,
    paddingLeft: 5,
    justifyContent: 'space-evenly',
  },
})
