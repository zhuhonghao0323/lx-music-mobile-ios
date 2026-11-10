import { useTheme } from '@/store/theme/hook'
import { useMemo, useRef, useImperativeHandle, forwardRef } from 'react'
import { Pressable, StyleSheet, type PressableProps, type View, type ViewProps } from 'react-native'
import { useGlass } from '@/theme/glass'
// import { AppColors } from '@/theme'


export interface BtnProps extends PressableProps {
  ripple?: PressableProps['android_ripple']
  style?: ViewProps['style']
  onChangeText?: (value: string) => void
  onClearText?: () => void
  children: React.ReactNode
}


export interface BtnType {
  measure: (callback: (x: number, y: number, width: number, height: number, pageX: number, pageY: number) => void) => void
}

export default forwardRef<BtnType, BtnProps>(({ ripple: propsRipple = {}, disabled, children, style, ...props }, ref) => {
  const theme = useTheme()
  const glass = useGlass()
  const btnRef = useRef<View>(null)
  const ripple = useMemo(() => ({
    color: glass.isGlass ? 'rgba(255,255,255,0.35)' : theme['c-primary-light-200-alpha-700'],
    ...propsRipple,
  }), [theme, propsRipple, glass.isGlass])

  useImperativeHandle(ref, () => ({
    measure(callback) {
      btnRef.current?.measure(callback)
    },
  }))

  const glassStyle = useMemo(() => StyleSheet.compose(
    glass.isGlass ? {
      // 底色由调用方（多取自 theme['c-button-background']，液态玻璃主题下已是半透明色）提供，
      // 这里只补玻璃描边、圆角与阴影，避免覆盖调用方指定的颜色
      borderWidth: StyleSheet.hairlineWidth,
      borderColor: 'rgba(255, 255, 255, 0.38)',
      borderRadius: 14,
      shadowColor: 'rgba(6, 4, 4, 0.55)',
      shadowOffset: { width: 0, height: 6 },
      shadowOpacity: 0.35,
      shadowRadius: 14,
      elevation: 4,
    } : {},
    style,
  // eslint-disable-next-line react-hooks/exhaustive-deps
  ), [glass.isGlass, style])

  return (
    <Pressable
      android_ripple={ripple}
      disabled={disabled}
      style={StyleSheet.compose({ opacity: disabled ? 0.3 : 1 }, glassStyle)}
      {...props}
      ref={btnRef}
    >
      {children}
    </Pressable>
  )
})
