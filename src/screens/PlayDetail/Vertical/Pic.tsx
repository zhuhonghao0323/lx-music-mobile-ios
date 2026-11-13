import { useEffect, useMemo, useRef, useState } from 'react'
import { Animated, Easing, StyleSheet, View, type View as ViewType } from 'react-native'
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
import { useIsGlass } from '@/theme/glass'
import { getMusicPicUrl } from '@/utils/musicCover'


export default ({ componentId }: { componentId: string }) => {
  const musicInfo = usePlayerMusicInfo()
  const { width: winWidth, height: winHeight } = useWindowSize()
  const statusBarHeight = useStatusbarHeight()
  const isGlass = useIsGlass()
  const containerRef = useRef<ViewType>(null)

  // 封面地址：歌曲封面在 meta.picUrl（顶层 pic 是播放器快照字段，切歌后不更新）
  const coverUrl = getMusicPicUrl(musicInfo)
  const picRef = useRef<string | null>(coverUrl)

  // 封面必须始终跟随当前歌曲。
  // 之前用 animated 开关控制 setPic，但新版播放页是 Home 的 Tab，
  // 永远不会触发 navigationComponentDidAppear，导致 animated 恒为 false、
  // 封面在切歌后完全不刷新。这里直接用 coverUrl。
  const pic = coverUrl
  useEffect(() => {
    picRef.current = coverUrl
  }, [coverUrl])

  // 仅用于封面 elevation 的过渡（与封面地址刷新解耦）
  const [animated, setAnimated] = useState(true)

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

  // 设计规范：页面进入时封面以 0.92 → 1.0 轻缩放进入，约 220–280ms
  const enterScale = useRef(new Animated.Value(0.92)).current
  const enterOpacity = useRef(new Animated.Value(0)).current
  useEffect(() => {
    Animated.parallel([
      Animated.timing(enterScale, {
        toValue: 1,
        duration: 260,
        easing: Easing.out(Easing.cubic),
        useNativeDriver: true,
      }),
      Animated.timing(enterOpacity, {
        toValue: 1,
        duration: 240,
        easing: Easing.out(Easing.quad),
        useNativeDriver: true,
      }),
    ]).start()
  }, [enterScale, enterOpacity])

  // console.log('render pic')

  const style = useMemo(() => {
    const imgWidth = Math.min(winWidth * 0.8, (winHeight - statusBarHeight - HEADER_HEIGHT) * 0.5)
    return {
      width: imgWidth,
      height: imgWidth,
      // 设计规范：封面圆角 18–22，保持清晰完整、不叠加玻璃蒙层
      borderRadius: isGlass ? 20 : 2,
      ...(isGlass ? {
        // 仅极细受光描边，避免厚重边框；封面本体保持清晰不加模糊
        borderWidth: StyleSheet.hairlineWidth,
        borderColor: 'rgba(255,255,255,0.24)',
        // 暖黑基调下的柔和投影，让封面从模糊背景中浮起
        shadowColor: 'rgba(6, 4, 4, 0.62)',
        shadowOffset: { width: 0, height: 18 },
        shadowOpacity: 0.55,
        shadowRadius: 30,
        elevation: 12,
      } : {}),
    }
  }, [statusBarHeight, winHeight, winWidth, isGlass])

  return (
    <View style={styles.container}>
      <Animated.View
        ref={containerRef}
        collapsable={false}
        style={{
          ...styles.content,
          elevation: animated ? 3 : 0,
          opacity: enterOpacity,
          transform: [{ scale: enterScale }],
        }}
      >
        <CoverGesture width={style.width} height={style.height}>
          <Image url={pic} nativeID={NAV_SHEAR_NATIVE_IDS.playDetail_pic} style={style} />
        </CoverGesture>
      </Animated.View>
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
