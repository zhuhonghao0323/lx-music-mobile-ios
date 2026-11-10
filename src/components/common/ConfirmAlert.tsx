import { forwardRef, useImperativeHandle, useRef } from 'react'
import { View, ScrollView, StyleSheet } from 'react-native'
import Dialog, { type DialogType } from './Dialog'
import Button from './Button'
import { createStyle } from '@/utils/tools'
import { useI18n } from '@/lang/index'
import { useTheme } from '@/store/theme/hook'
import Text from './Text'
import { useIsGlass } from '@/theme/glass'

const styles = createStyle({
  main: {
    // flexGrow: 0,
    flexShrink: 1,
    marginTop: 15,
    marginLeft: 5,
    marginRight: 5,
    marginBottom: 25,
  },
  content: {
    flexGrow: 0,
    paddingLeft: 10,
    paddingRight: 10,
  },
  btns: {
    flexDirection: 'row',
    justifyContent: 'center',
    paddingBottom: 15,
    // paddingRight: 15,
  },
  btnsDirection: {
    paddingLeft: 15,
  },
  btnsReversedDirection: {
    paddingLeft: 15,
    flexDirection: 'row-reverse',
  },
  btn: {
    flex: 1,
    paddingTop: 9,
    paddingBottom: 9,
    paddingLeft: 10,
    paddingRight: 10,
    alignItems: 'center',
    borderRadius: 4,
  },
  btnDirection: {
    marginRight: 15,
  },
  btnReversedDirection: {
    marginLeft: 15,
  },
})

export interface ConfirmAlertProps {
  onCancel?: () => void
  onHide?: () => void
  onConfirm?: () => void
  keyHide?: boolean
  bgHide?: boolean
  closeBtn?: boolean
  title?: string
  text?: string
  cancelText?: string
  confirmText?: string
  showConfirm?: boolean
  disabledConfirm?: boolean
  reverseBtn?: boolean
  children?: React.ReactNode | React.ReactNode[]
}

export interface ConfirmAlertType {
  setVisible: (visible: boolean) => void
}

export default forwardRef<ConfirmAlertType, ConfirmAlertProps>(({
  onHide,
  onCancel,
  onConfirm = () => {},
  keyHide,
  bgHide,
  closeBtn,
  title = '',
  text = '',
  cancelText = '',
  confirmText = '',
  showConfirm = true,
  disabledConfirm = false,
  children,
  reverseBtn = false,
}: ConfirmAlertProps, ref) => {
  const theme = useTheme()
  const t = useI18n()
  const isGlass = useIsGlass()

  const dialogRef = useRef<DialogType>(null)

  useImperativeHandle(ref, () => ({
    setVisible(visible: boolean) {
      dialogRef.current?.setVisible(visible)
    },
  }))

  const handleCancel = () => {
    onCancel?.()
    dialogRef.current?.setVisible(false)
  }

  return (
    <Dialog onHide={onHide} keyHide={keyHide} bgHide={bgHide} closeBtn={closeBtn} title={title} ref={dialogRef}>
      <View style={StyleSheet.compose(styles.main, isGlass ? { marginLeft: 14, marginRight: 14 } : {})}>
        <ScrollView style={styles.content} keyboardShouldPersistTaps={'always'}>
          {children ?? <Text color={isGlass ? '#F5F2F1' : undefined}>{text}</Text>}
        </ScrollView>
      </View>
      <View style={{ ...styles.btns, ...(reverseBtn ? styles.btnsReversedDirection : styles.btnsDirection), ...(isGlass ? { paddingLeft: 14, paddingRight: 14, paddingBottom: 18 } : {}) }}>
        <Button style={StyleSheet.compose({ ...styles.btn, ...(reverseBtn ? styles.btnReversedDirection : styles.btnDirection), backgroundColor: theme['c-button-background'] }, isGlass ? { borderRadius: 14, borderWidth: StyleSheet.hairlineWidth, borderColor: 'rgba(255,255,255,0.38)' } : {})} onPress={handleCancel}>
          <Text color={isGlass ? '#F5F2F1' : theme['c-button-font']}>{cancelText || t('cancel')}</Text>
        </Button>
        {showConfirm
          ? <Button style={StyleSheet.compose({ ...styles.btn, ...(reverseBtn ? styles.btnReversedDirection : styles.btnDirection), backgroundColor: isGlass ? 'rgba(242, 120, 104, 0.42)' : theme['c-button-background'] }, isGlass ? { borderRadius: 14, borderWidth: StyleSheet.hairlineWidth, borderColor: 'rgba(255,255,255,0.22)' } : {})} onPress={onConfirm} disabled={disabledConfirm}>
              <Text color={isGlass ? '#ffffff' : theme['c-button-font']}>{confirmText || t('confirm')}</Text>
            </Button>
          : null}
      </View>
    </Dialog>
  )
})
