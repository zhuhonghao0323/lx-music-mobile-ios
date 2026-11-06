import { memo } from 'react'
import { StyleSheet } from 'react-native'

// import Title from './components/Title'
import MoreBtn from './components/MoreBtn'
import PlayInfo from './components/PlayInfo'
import ControlBtn from './components/ControlBtn'
import { createStyle } from '@/utils/tools'
import { NAV_SHEAR_NATIVE_IDS } from '@/config/constant'
import { useIsGlass } from '@/theme/glass'
import GlassView from '@/components/common/GlassView'


export default memo(() => {
  const isGlass = useIsGlass()
  return (
    <GlassView
      material="thin"
      radius={26}
      style={StyleSheet.compose(styles.container, isGlass ? {
        marginHorizontal: 10,
        marginBottom: 10,
        paddingTop: 14,
        paddingBottom: 18,
      } : {})}
      nativeID={NAV_SHEAR_NATIVE_IDS.playDetail_player}
    >
      <PlayInfo />
      <ControlBtn />
      <MoreBtn />
    </GlassView>
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
