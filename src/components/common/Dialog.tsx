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
import GlassView from './GlassView'

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
          <Icon name="close" color={glass.textColor() ?? theme['c-primary-dark-500-alpha-500']} size={10} />
        </TouchableHighlight>
      : null
  }, [closeBtn, theme, glass])

  const panelStyle = useMemo(() => {
    const base = { ...styles.modalView, height, borderRadius: glass.isGlass ? 24 : 4 }
    if (glass.isGlass) return StyleSheet.compose(base, glass.panel())
    return StyleSheet.compose(base, { backgroundColor: theme['c-content-background'] })
  }, [height, theme, glass])

  const headerStyle = useMemo(() => ({
    ...styles.header,
    backgroundColor: glass.isGlass ? 'rgba(255,255,255,0.06)' : theme['c-primary-light-100-alpha-100'],
    borderTopLeftRadius: glass.isGlass ? 24 : 4,
    borderTopRightRadius: glass.isGlass ? 24 : 4,
    height: glass.isGlass ? scaleSizeH(38) : HEADER_HEIGHT,
    ...(glass.isGlass ? { borderBottomWidth: StyleSheet.hairlineWidth, borderBottomColor: 'rgba(255,255,255,0.14)' } : {}),
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }), [theme, glass.isGlass])

  return (
    <Modal onHide={onHide} keyHide={keyHide} bgHide={bgHide} bgColor={glass.scrim() ?? 'rgba(50,50,50,.3)'} ref={modalRef}>
      <View style={{ ...styles.centeredView, paddingBottom: keyboardShown ? keyboardHeight : 0 }}>
        <GlassView material="regular" radius={glass.isGlass ? 24 : 4} style={panelStyle} onStartShouldSetResponder={() => true}>
          <View style={headerStyle}>
            <Text style={styles.title} size={glass.isGlass ? 15 : 13} color={glass.textColor() ?? theme['c-primary-light-1000']} numberOfLines={1}>{title}</Text>
            {closeBtnComponent}
          </View>
          {children}
        </GlassView>
      </View>
    </Modal>
  )
})
