import { forwardRef, useImperativeHandle, useMemo, useRef } from 'react'
import { View, TouchableOpacity, StyleSheet } from 'react-native'

import Modal, { type ModalType } from './Modal'
import { Icon } from '@/components/common/Icon'
import { useKeyboard } from '@/utils/hooks'
import { createStyle } from '@/utils/tools'
import { useTheme } from '@/store/theme/hook'
import Text from './Text'
import { useStatusbarHeight } from '@/store/common/hook'
import { useGlass } from '@/theme/glass'
import GlassView from './GlassView'

const styles = createStyle({
  centeredView: {
    flex: 1,
    // justifyContent: 'flex-end',
    // alignItems: 'center',
  },
  modalView: {
    elevation: 6,
    flexGrow: 0,
    flexShrink: 1,
  },
  header: {
    flex: 0,
    flexDirection: 'row',
    borderTopLeftRadius: 8,
    borderTopRightRadius: 8,
  },
  title: {
    paddingLeft: 10,
    paddingRight: 25,
    paddingTop: 10,
    paddingBottom: 10,
    // lineHeight: 20,
  },
  closeBtn: {
    position: 'absolute',
    // 原本 right:0 会让关闭按钮贴在圆角容器的直角外沿，
    // 在大圆角（24）下看起来「超出框体」。这里向内收 8，落在圆角轮廓内。
    right: 8,
    flexGrow: 0,
    flexShrink: 0,
    height: 30,
    width: 30,
    justifyContent: 'center',
    alignItems: 'center',
  },
  // 纯色面板：Beans 冷黑玻璃底 + 大圆角，无任何叠加层
  plainPanel: {
    backgroundColor: 'rgba(28, 28, 30, 0.98)',
    borderRadius: 24,
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: 'rgba(255,255,255,0.10)',
    overflow: 'hidden',
  },
})

export interface PopupProps {
  onHide?: () => void
  keyHide?: boolean
  bgHide?: boolean
  closeBtn?: boolean
  position?: 'top' | 'left' | 'right' | 'bottom'
  title?: string
  /**
   * 纯色面板模式：不叠毛玻璃/描边/高光层。
   * 适合内容多的列表弹层（层级更干净、滚动性能更好）。
   */
  plain?: boolean
  children: React.ReactNode
}

export interface PopupType {
  setVisible: (visible: boolean) => void
}

export default forwardRef<PopupType, PopupProps>(({
  onHide = () => {},
  keyHide = true,
  bgHide = true,
  closeBtn = true,
  position = 'bottom',
  title = '',
  plain = false,
  children,
}: PopupProps, ref) => {
  const theme = useTheme()
  const glass = useGlass()
  const { keyboardShown, keyboardHeight } = useKeyboard()
  const statusBarHeight = useStatusbarHeight()

  const modalRef = useRef<ModalType>(null)

  useImperativeHandle(ref, () => ({
    setVisible(visible: boolean) {
      modalRef.current?.setVisible(visible)
    },
  }))

  const closeBtnComponent = useMemo(() => closeBtn
    ? <TouchableOpacity style={styles.closeBtn} onPress={() => modalRef.current?.setVisible(false)}>
        <Icon name="close" style={{ color: glass.textColor() ?? theme['c-font-label'] }} size={12} />
      </TouchableOpacity>
    : null, [closeBtn, theme, glass])

  const [centeredViewStyle, modalViewStyle] = useMemo(() => {
    switch (position) {
      case 'top':
        return [
          {
            position: 'absolute',
            left: 0,
            right: 0,
            bottom: 0,
            top: 0,
            justifyContent: 'flex-start',
          },
          {
            width: '100%',
            maxHeight: '78%',
            minHeight: '20%',
            // backgroundColor: 'white',
          },
        ] as const
      case 'left':
        return [
          {
            position: 'absolute',
            left: 0,
            right: 0,
            bottom: 0,
            top: 0,
            flexDirection: 'row',
            justifyContent: 'flex-start',
          },
          {
            minWidth: '45%',
            maxWidth: '78%',
            height: '100%',
            paddingTop: statusBarHeight,
            // backgroundColor: 'white',
          },
        ] as const
      case 'right':
        return [
          {
            position: 'absolute',
            left: 0,
            right: 0,
            bottom: 0,
            top: 0,
            flexDirection: 'row',
            justifyContent: 'flex-end',
          },
          {
            minWidth: '45%',
            maxWidth: '78%',
            height: '100%',
            paddingTop: statusBarHeight,
            // backgroundColor: 'white',
          },
        ] as const
      case 'bottom':
      default:
        return [
          {
            position: 'absolute',
            left: 0,
            right: 0,
            bottom: 0,
            top: 0,
            justifyContent: 'flex-end',
          },
          {
            width: '100%',
            maxHeight: '78%',
            minHeight: '20%',
            // backgroundColor: 'white',
            borderTopLeftRadius: 8,
            borderTopRightRadius: 8,
          },
        ] as const
    }
  }, [position, statusBarHeight])

  const panelStyle = useMemo(() => StyleSheet.compose(
    {
      ...styles.modalView,
      ...modalViewStyle,
      backgroundColor: glass.isGlass ? undefined : theme['c-content-background'],
      // 玻璃主题：四角全圆角
      borderRadius: glass.isGlass ? 24 : undefined,
      borderTopLeftRadius: glass.isGlass ? 24 : undefined,
      borderTopRightRadius: glass.isGlass ? 24 : undefined,
      borderBottomLeftRadius: glass.isGlass ? 24 : undefined,
      borderBottomRightRadius: glass.isGlass ? 24 : undefined,
      // 关键：不要在这里设 left/right。
      // modalViewStyle 里 bottom 分支已带 width:'100%'，再叠加 left/right 会
      // 变成「全屏宽 + 右移偏移」，直接把弹层推出屏幕右侧。
      // 左右留白统一交给外层容器的 paddingHorizontal。
    },
    glass.panel(),
  // eslint-disable-next-line react-hooks/exhaustive-deps
  ), [modalViewStyle, theme, glass.isGlass])

  return (
    <Modal onHide={onHide} keyHide={keyHide} bgHide={bgHide} bgColor={glass.scrim() ?? 'rgba(50,50,50,.2)'} ref={modalRef}>
      <View style={{
        ...styles.centeredView,
        ...centeredViewStyle,
        // 玻璃主题：左右留白加在容器上（而不是弹层面板），
        // 这样 width:'100%' 的弹层会自动收缩到 屏幕宽 - 24，不会溢出屏幕。
        ...(plain
          ? { paddingHorizontal: 10, paddingBottom: Math.max(keyboardShown ? keyboardHeight : 0, 10) }
          : {
              paddingBottom: keyboardShown ? keyboardHeight : 0,
              ...(glass.isGlass ? { paddingHorizontal: 12 } : {}),
            }),
      }}>
        {plain
          // plain 模式：纯色面板，不叠 BlurView / 描边 / 高光，避免出现多余的层级背景框
          ? (
              <View style={[panelStyle, styles.plainPanel]} onStartShouldSetResponder={() => true}>
                <View style={styles.header}>
                  <Text size={16} color={theme['c-font']} style={styles.title} numberOfLines={1}>{title}</Text>
                  {closeBtnComponent}
                </View>
                {children}
              </View>
            )
          : (
              <GlassView material="regular" radius={glass.isGlass ? 24 : 2} style={panelStyle} onStartShouldSetResponder={() => true}>
                <View style={styles.header}>
                  <Text size={glass.isGlass ? 15 : 13} color={glass.textColor()} style={styles.title} numberOfLines={1}>{title}</Text>
                  {closeBtnComponent}
                </View>
                {children}
              </GlassView>
            )}
      </View>
    </Modal>
  )
})
