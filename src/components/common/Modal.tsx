// import { createStyle } from '@/utils/tools'
import { useImperativeHandle, forwardRef, useState, useMemo, useRef, useEffect } from 'react'
import { Animated, Modal, Platform, TouchableWithoutFeedback, View, type ModalProps as _ModalProps } from 'react-native'
import { useStatusbarHeight } from '@/store/common/hook'

export interface ModalProps extends Omit<_ModalProps, 'visible'> {
  onHide?: () => void
  keyHide?: boolean
  bgHide?: boolean
  bgColor?: string
  statusBarPadding?: boolean
}

export interface ModalType {
  setVisible: (visible: boolean) => void
}

/**
 * 弹层内容入场动画：缩放 + 上移 + 淡入，用 spring 收尾制造「弹一下」的丝滑感。
 * 所有基于 Modal 的弹窗（Dialog / Popup / Menu / MusicAddModal）统一获得该效果。
 */
const AnimatedContent = ({ visible, children }: { visible: boolean, children: React.ReactNode }) => {
  const anim = useRef(new Animated.Value(0)).current
  useEffect(() => {
    Animated.spring(anim, {
      toValue: visible ? 1 : 0,
      friction: 9,
      tension: 110,
      useNativeDriver: true,
    }).start()
  }, [visible, anim])

  const translateY = anim.interpolate({
    inputRange: [0, 1],
    outputRange: [24, 0],
  })
  const scale = anim.interpolate({
    inputRange: [0, 1],
    outputRange: [0.94, 1],
  })

  return (
    <Animated.View
      style={{
        flex: 1,
        opacity: anim,
        transform: [{ translateY }, { scale }],
      }}
    >
      {children}
    </Animated.View>
  )
}

export default forwardRef<ModalType, ModalProps>(({
  onHide = () => {},
  keyHide = true,
  bgHide = true,
  bgColor = 'rgba(0,0,0,0)',
  statusBarPadding = true,
  children,
  ...props
}: ModalProps, ref) => {
  const [visible, setVisible] = useState(false)
  const statusBarHeight = useStatusbarHeight()
  const handleRequestClose = () => {
    if (keyHide) {
      setVisible(false)
      onHide()
    }
  }
  const handleBgClose = () => {
    if (bgHide) {
      setVisible(false)
      onHide()
    }
  }

  useImperativeHandle(ref, () => ({
    setVisible(_visible) {
      if (visible == _visible) return
      setVisible(_visible)
      if (!_visible) onHide()
    },
  }))

  const memoChildren = useMemo(() => children, [children])
  const supportedOrientations = useMemo<_ModalProps['supportedOrientations']>(() => Platform.OS == 'ios'
    ? ['portrait', 'portrait-upside-down', 'landscape', 'landscape-left', 'landscape-right']
    : undefined, [])
  const content = (
    <View style={{ flex: 1, backgroundColor: bgColor, paddingTop: statusBarPadding ? statusBarHeight : 0 }}>
      <AnimatedContent visible={visible}>
        {memoChildren}
      </AnimatedContent>
    </View>
  )

  return (
    <Modal
      // 用 'none' 关闭系统生硬的 fade，由 AnimatedContent 提供统一柔和动画
      animationType="none"
      transparent={true}
      hardwareAccelerated={true}
      statusBarTranslucent={true}
      visible={visible}
      onRequestClose={handleRequestClose}
      supportedOrientations={supportedOrientations}
      {...props}
    >
      {
        bgHide
          ? (
              <TouchableWithoutFeedback onPress={handleBgClose}>
                {content}
              </TouchableWithoutFeedback>
            )
          : content
      }
    </Modal>
  )
})
