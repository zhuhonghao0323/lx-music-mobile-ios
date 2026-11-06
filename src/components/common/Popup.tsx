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
    right: 0,
    // borderTopRightRadius: 8,
    flexGrow: 0,
    flexShrink: 0,
    height: 30,
    width: 30,
    justifyContent: 'center',
    alignItems: 'center',
    // backgroundColor: '#eee',
  },
})

export interface PopupProps {
  onHide?: () => void
  keyHide?: boolean
  bgHide?: boolean
  closeBtn?: boolean
  position?: 'top' | 'left' | 'right' | 'bottom'
  title?: string
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
    StyleSheet.compose(
      { ...styles.modalView, ...modalViewStyle, backgroundColor: glass.isGlass ? undefined : theme['c-content-background'] },
      glass.isGlass
        ? {
            borderRadius: 24,
            borderTopLeftRadius: 24,
            borderTopRightRadius: 24,
            borderBottomLeftRadius: position == 'top' ? 24 : 0,
            borderBottomRightRadius: position == 'top' ? 24 : 0,
            margin: position == 'bottom' ? 8 : 0,
          }
        : {},
    ),
    glass.panel(true),
  // eslint-disable-next-line react-hooks/exhaustive-deps
  ), [modalViewStyle, theme, position, glass.isGlass])

  return (
    <Modal onHide={onHide} keyHide={keyHide} bgHide={bgHide} bgColor={glass.scrim() ?? 'rgba(50,50,50,.2)'} ref={modalRef}>
      <View style={{ ...styles.centeredView, ...centeredViewStyle, paddingBottom: keyboardShown ? keyboardHeight : 0 }}>
        <View style={panelStyle} onStartShouldSetResponder={() => true}>
          {glass.isGlass ? <View pointerEvents="none" style={glass.highlight()} /> : null}
          <View style={StyleSheet.compose(styles.header, glass.isGlass ? { borderBottomWidth: StyleSheet.hairlineWidth, borderBottomColor: 'rgba(255,255,255,0.14)' } : {})}>
            <Text size={glass.isGlass ? 15 : 13} color={glass.textColor()} style={styles.title} numberOfLines={1}>{title}</Text>
            {closeBtnComponent}
          </View>
          {children}
        </View>
      </View>
    </Modal>
  )
})
