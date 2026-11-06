import { memo } from 'react'
import { View, StyleSheet } from 'react-native'

// import Title from './components/Title'
import MoreBtn from './components/MoreBtn'
import PlayInfo from './components/PlayInfo'
import ControlBtn from './components/ControlBtn'
import { createStyle } from '@/utils/tools'
import { NAV_SHEAR_NATIVE_IDS } from '@/config/constant'
import { useIsGlass } from '@/theme/glass'


export default memo(() => {
  const isGlass = useIsGlass()
  return (
    <View style={StyleSheet.compose(styles.container, isGlass ? {
      marginHorizontal: 10,
      marginBottom: 10,
      paddingTop: 14,
      paddingBottom: 18,
      borderRadius: 26,
      backgroundColor: 'rgba(255, 255, 255, 0.12)',
      borderWidth: StyleSheet.hairlineWidth,
      borderColor: 'rgba(255, 255, 255, 0.32)',
      shadowColor: 'rgba(6, 10, 30, 0.55)',
      shadowOffset: { width: 0, height: 10 },
      shadowOpacity: 0.45,
      shadowRadius: 26,
      elevation: 8,
    } : {})} nativeID={NAV_SHEAR_NATIVE_IDS.playDetail_player}>
      {isGlass ? <View pointerEvents="none" style={{ position: 'absolute', top: 0, left: 20, right: 20, height: 1, backgroundColor: 'rgba(255,255,255,0.5)', opacity: 0.6 }} /> : null}
      <PlayInfo />
      <ControlBtn />
      <MoreBtn />
    </View>
  )
})

const styles = createStyle({
  container: {
    flex: 0,
    width: '100%',
    // paddingTop: progressContentPadding,
    // marginTop: -progressContentPadding,
    // backgroundColor: 'rgba(0, 0, 0, .1)',
    paddingHorizontal: 15,
    paddingBottom: 15,
    paddingTop: 5,
    // backgroundColor: AppColors.primary,
    // backgroundColor: 'red',
    flexDirection: 'column',
  },
  status: {
    marginTop: 10,
    flexDirection: 'column',
    flex: 0,
    paddingLeft: 5,
    justifyContent: 'space-evenly',
    // backgroundColor: 'rgba(0, 0, 0, .1)',
  },
})
