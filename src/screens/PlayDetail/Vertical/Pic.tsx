import { useEffect, useMemo, useRef, useState } from 'react'
import { View, type View as ViewType } from 'react-native'
// import { useLayout } from '@/utils/hooks'
import { createStyle } from '@/utils/tools'
import { usePlayerMusicInfo } from '@/store/player/hook'
import { useWindowSize } from '@/utils/hooks'
import { NAV_SHEAR_NATIVE_IDS } from '@/config/constant'
import { useNavigationComponentDidAppear } from '@/navigation'
import { HEADER_HEIGHT } from './components/Header'
import Image from '@/components/common/Image'
import CoverGesture from '@/screens/PlayDetail/components/CoverGesture'
import { registerCoverSource, clearCoverSource } from '@/screens/PlayDetail/components/FavoriteBtn'
import { useStatusbarHeight } from '@/store/common/hook'
import commonState from '@/store/common/state'
import { useIsGlass } from '@/theme/glass'


export default ({ componentId }: { componentId: string }) => {
  const musicInfo = usePlayerMusicInfo()
  const { width: winWidth, height: winHeight } = useWindowSize()
  const statusBarHeight = useStatusbarHeight()
  const isGlass = useIsGlass()
  const containerRef = useRef<ViewType>(null)
  const picRef = useRef<string | null>(musicInfo.pic ?? null)

  const [animated, setAnimated] = useState(!!commonState.componentIds.playDetail)
  const [pic, setPic] = useState(musicInfo.pic)
  useEffect(() => {
    if (animated) setPic(musicInfo.pic)
    picRef.current = musicInfo.pic ?? null
  }, [musicInfo.pic, animated])

  // 把封面位置与图片注册给收藏动画，用运行时测量避免机型差异
  useEffect(() => {
    registerCoverSource(
      (cb) => {
        const node = containerRef.current
        if (!node) { cb(null); return }
        node.measureInWindow((x, y, width, height) => { cb({ x, y, width, height }) })
      },
      () => picRef.current,
    )
    return () => { clearCoverSource() }
  }, [])

  useNavigationComponentDidAppear(componentId, () => {
    setAnimated(true)
  })
  // console.log('render pic')

  const style = useMemo(() => {
    const imgWidth = Math.min(winWidth * 0.8, (winHeight - statusBarHeight - HEADER_HEIGHT) * 0.5)
    return {
      width: imgWidth,
      height: imgWidth,
      borderRadius: isGlass ? 24 : 2,
      ...(isGlass ? {
        borderWidth: 1,
        borderColor: 'rgba(255,255,255,0.45)',
        shadowColor: 'rgba(6, 10, 30, 0.7)',
        shadowOffset: { width: 0, height: 18 },
        shadowOpacity: 0.55,
        shadowRadius: 30,
        elevation: 12,
      } : {}),
    }
  }, [statusBarHeight, winHeight, winWidth, isGlass])

  return (
    <View style={styles.container}>
      <View ref={containerRef} collapsable={false} style={{ ...styles.content, elevation: animated ? 3 : 0 }}>
        <CoverGesture width={style.width} height={style.height}>
          <Image url={pic} nativeID={NAV_SHEAR_NATIVE_IDS.playDetail_pic} style={style} />
        </CoverGesture>
      </View>
    </View>
  )
}

const styles = createStyle({
  container: {
    flexGrow: 1,
    flexShrink: 1,
    justifyContent: 'center',
    alignItems: 'center',
    // backgroundColor: 'rgba(0,0,0,0.1)',
  },
  content: {
    // elevation: 3,
    backgroundColor: 'rgba(0,0,0,0)',
    borderRadius: 4,
  },
})
