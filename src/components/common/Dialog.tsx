import { useImperativeHandle, forwardRef, useMemo, useRef } from 'react'
import { View, TouchableHighlight, StyleSheet } from 'react-native'

import Modal, { type ModalType } from './Modal'
import { Icon } from '@/components/common/Icon'
import { useKeyboard } from '@/utils/hooks'
import { createStyle } from '@/utils/tools'
import { useTheme } from '@/store/theme/hook'
import Text from './Text'
import { scaleSizeH } from '@/utils/pixelRatio'
import { useGlass } from '@/theme/glass'

const HEADER_HEIGHT = 20
const styles = createStyle({
  centeredView: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  modalView: {
    maxWidth: '90%',
    minWidth: '60%',
    maxHeight: '78%',
    borderRadius: 4,
    elevation: 3,
  },
  header: {
    flexGrow: 0,
    flexShrink: 0,
    flexDirection: 'row',
    borderTopLeftRadius: 4,
    borderTopRightRadius: 4,
    height: HEADER_HEIGHT,
  },
  title: {
    paddingLeft: 5,
    paddingRight: 25,
    lineHeight: HEADER_HEIGHT,
  },
  closeBtn: {
    position: 'absolute',
    right: 0,
    borderTopRightRadius: 4,
    flexGrow: 0,
    flexShrink: 0,
    height: HEADER_HEIGHT,
    justifyContent: 'center',
    alignItems: 'center',
  },
})

export interface DialogProps {
  onHide?: () => void
  keyHide?: boolean
  bgHide?: boolean
  closeBtn?: boolean
  title?: string
  children: React.ReactNode | React.ReactNode[]
  height?: number | `${number}%`
}

export interface DialogType {
  setVisible: (visible: boolean) => void
}

export default forwardRef<DialogType, DialogProps>(({
  onHide,
  keyHide = true,
  bgHide = true,
  closeBtn = true,
  title = '',
  children,
  height,
}: DialogProps, ref) => {
  const theme = useTheme()
  const glass = useGlass()
  const { keyboardShown, keyboardHeight } = useKeyboard()
  const modalRef = useRef<ModalType>(null)

  useImperativeHandle(ref, () => ({
    setVisible(visible: boolean) {
      modalRef.current?.setVisible(visible)
    },
  }))

  const closeBtnComponent = useMemo(() => {
    return closeBtn
      ? <TouchableHighlight style={{ ...styles.closeBtn, width: scaleSizeH(HEADER_HEIGHT) }} underlayColor={glass.isGlass ? 'rgba(255,255,255,0.22)' : theme['c-primary-dark-200-alpha-600']} onPress={() => modalRef.current?.setVisible(false)}>
          <Icon name="close" color={glass.isGlass ? '#f4f8ff' : theme['c-primary-dark-500-alpha-500']} size={10} />
        </TouchableHighlight>
      : null
  }, [closeBtn, theme, glass.isGlass])

  const panelStyle = useMemo(() => StyleSheet.compose(
    {
      ...styles.modalView,
      height,
      backgroundColor: glass.isGlass ? undefined : theme['c-content-background'],
      borderRadius: glass.isGlass ? 24 : 4,
    },
    glass.panel(true),
  // eslint-disable-next-line react-hooks/exhaustive-deps
  ), [height, theme, glass.isGlass])

  const headerStyle = useMemo(() => StyleSheet.compose(
    {
      ...styles.header,
      backgroundColor: glass.isGlass ? 'rgba(255,255,255,0.10)' : theme['c-primary-light-100-alpha-100'],
      borderTopLeftRadius: glass.isGlass ? 24 : 4,
      borderTopRightRadius: glass.isGlass ? 24 : 4,
      height: glass.isGlass ? scaleSizeH(38) : HEADER_HEIGHT,
    },
    glass.isGlass ? { borderBottomWidth: StyleSheet.hairlineWidth, borderBottomColor: 'rgba(255,255,255,0.16)' } : {},
  // eslint-disable-next-line react-hooks/exhaustive-deps
  ), [theme, glass.isGlass])

  return (
    <Modal onHide={onHide} keyHide={keyHide} bgHide={bgHide} bgColor={glass.scrim() ?? 'rgba(50,50,50,.3)'} ref={modalRef}>
      <View style={{ ...styles.centeredView, paddingBottom: keyboardShown ? keyboardHeight : 0 }}>
        <View style={panelStyle} onStartShouldSetResponder={() => true}>
          {glass.isGlass ? <View pointerEvents="none" style={glass.highlight()} /> : null}
          <View style={headerStyle}>
            <Text style={styles.title} size={glass.isGlass ? 15 : 13} color={glass.textColor() ?? theme['c-primary-light-1000']} numberOfLines={1}>{title}</Text>
            {closeBtnComponent}
          </View>
          {children}
        </View>
      </View>
    </Modal>
  )
})
