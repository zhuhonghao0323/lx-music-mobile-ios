import { memo, useCallback, useEffect, useRef, useState } from 'react'
import { View, PanResponder } from 'react-native'
import { useDrag } from '@/utils/hooks'
import { createStyle } from '@/utils/tools'
import { useTheme } from '@/store/theme/hook'
import { markTimeoutExitInteraction } from '@/core/player/timeoutExit'
// import { scaleSizeW } from '@/utils/pixelRatio'
// import { AppColors } from '@/theme'


const DefaultBar = memo(() => {
  // const theme = useTheme()

  return <View style={{
    ...styles.progressBar,
    // backgroundColor: theme['c-primary-light-200-alpha-900'],
    position: 'absolute',
    width: '100%',
    left: 0,
    top: 0,
  }}></View>
})

const BufferedBar = memo(({ progress }: { progress: number }) => {
  // console.log(bufferedProgress)
  const theme = useTheme()
  return <View style={{ ...styles.progressBar, backgroundColor: theme['c-primary-light-600-alpha-900'], position: 'absolute', width: `${progress * 100}%`, left: 0, top: 0 }}></View>
})

const PreassBar = memo(({ onDragState, setDragProgress, onSetProgress }: {
  onDragState: (drag: boolean) => void
  setDragProgress: (progress: number) => void
  onSetProgress: (progress: number) => void
}) => {
  // 拖动过程中节流地实时 seek，让「进度条」和「实际播放位置」始终一致、跟手
  const lastSeekRef = useRef(0)
  const liveSeek = useCallback((progress: number) => {
    const now = Date.now()
    if (now - lastSeekRef.current < 120) return
    lastSeekRef.current = now
    onSetProgress(progress)
  }, [onSetProgress])

  const {
    onLayout,
    onDragStart,
    onDragEnd,
    onDrag,
  } = useDrag(onSetProgress, onDragState, (progress) => {
    setDragProgress(progress)
    liveSeek(progress)
  })
  // const handlePress = useCallback((event: GestureResponderEvent) => {
  //   onPress(event.nativeEvent.locationX)
  // }, [onPress])

  const panResponder = useRef(
    PanResponder.create({
      // 进度条在按下时就接管并一直持有，父容器（播放页右滑歌词）抢不走。
      // 注意：
      // - 不要在 Move 阶段再设 Capture=true，那会让每次移动都重新请求捕获，
      //   与已 grant 的 responder 冲突，表现为「拖动卡滞 / 拖不动」。
      // - onPanResponderTerminationRequest 返回 false 已足够阻止被抢。
      onStartShouldSetPanResponder: () => true,
      onStartShouldSetPanResponderCapture: () => true,
      onMoveShouldSetPanResponder: () => true,
      onPanResponderTerminationRequest: () => false,

      onPanResponderMove: (evt, gestureState) => {
        onDrag(gestureState.dx)
      },
      onPanResponderGrant: (evt, gestureState) => {
        onDragStart(gestureState.dx, evt.nativeEvent.locationX)
      },
      onPanResponderRelease: () => {
        onDragEnd()
      },
      onPanResponderTerminate: () => {
        onDragEnd()
      },
    }),
  ).current

  return <View onLayout={onLayout} style={styles.pressBar} {...panResponder.panHandlers} />
})


export const ProgressPlain = ({ progress, duration, buffered, paddingTop }: {
  progress: number
  duration: number
  buffered: number
  paddingTop?: number
}) => {
  // const { progress } = usePlayTimeBuffer()
  const theme = useTheme()
  // console.log(progress)
  const progressStr: `${number}%` = `${progress * 100}%`

  const durationRef = useRef(duration)
  useEffect(() => {
    durationRef.current = duration
  }, [duration])

  return (
    <View style={{ ...styles.progress, paddingTop }}>
      <View style={{ flex: 1 }}>
        <DefaultBar />
        <BufferedBar progress={buffered} />
        <View style={{ ...styles.progressBar, backgroundColor: theme['c-primary-alpha-900'], width: progressStr, position: 'absolute', left: 0, top: 0 }} />
      </View>
      <View style={styles.pressBar} />
    </View>
  )
}

const Progress = ({ progress, duration, buffered, paddingTop }: {
  progress: number
  duration: number
  buffered: number
  paddingTop?: number
}) => {
  // const { progress } = usePlayTimeBuffer()
  const theme = useTheme()
  const [draging, setDraging] = useState(false)
  const [dragProgress, setDragProgress] = useState(0)
  // console.log(progress)
  const progressStr: `${number}%` = `${progress * 100}%`

  const durationRef = useRef(duration)
  useEffect(() => {
    durationRef.current = duration
  }, [duration])
  const onSetProgress = useCallback((progress: number) => {
    markTimeoutExitInteraction()
    global.app_event.setProgress(progress * durationRef.current)
  }, [])

  return (
    <View style={{ ...styles.progress, paddingTop }}>
      <View style={{ flex: 1 }}>
        <DefaultBar />
        <BufferedBar progress={buffered} />
        {
          draging
            ? (
                <>
                  <View style={{ ...styles.progressBar, backgroundColor: theme['c-primary-light-200-alpha-900'], width: progressStr, position: 'absolute', left: 0, top: 0 }} />
                  <View style={{ ...styles.progressBar, backgroundColor: theme['c-primary-light-100-alpha-800'], width: `${dragProgress * 100}%`, position: 'absolute', left: 0, top: 0 }} />
                </>
              ) : (
                <View style={{ ...styles.progressBar, backgroundColor: theme['c-primary-alpha-900'], width: progressStr, position: 'absolute', left: 0, top: 0 }} />
              )
        }
      </View>
      <PreassBar onDragState={setDraging} setDragProgress={setDragProgress} onSetProgress={onSetProgress} />
      {/* <View style={{ ...styles.progressBar, height: '100%', width: progressStr }}><Pressable style={styles.progressDot}></Pressable></View> */}
    </View>
  )
}


// const progressContentPadding = 9
// const progressHeight = 3
const styles = createStyle({
  progress: {
    flex: 1,
    // backgroundColor: 'rgba(0,0,0,0.2)',
    zIndex: 1,
  },
  progressBar: {
    height: '100%',
    borderRadius: 3,
  },
  pressBar: {
    position: 'absolute',
    // backgroundColor: 'rgba(0,0,0,0.5)',
    left: 0,
    top: 0,
    // height: progressContentPadding * 2 + progressHeight,
    height: '100%',
    width: '100%',
  },
})

export default Progress
