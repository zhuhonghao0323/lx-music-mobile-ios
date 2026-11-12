import { memo } from 'react'
import { View, StyleSheet } from 'react-native'
/**
 * 胶囊边缘进度条（无圆点、发光细线）。
 *
 * 实现：把「完整的胶囊描边」放在一个宽度按进度裁剪的裁剪层里，
 * 裁剪层从左侧增长。视觉上就是描边沿胶囊边缘逐步点亮。
 *
 * 说明：项目未引入 react-native-svg，用 border 拼弧段在圆角处会失真，
 * 因此采用「整圈描边 + 宽度裁剪」的方式，圆角处过渡自然、性能也好。
 */
export default memo(({ progress, height, width, color = 'rgba(242,120,104,0.95)', trackColor = 'rgba(255,255,255,0.10)' }: {
  progress: number
  height: number
  width: number
  color?: string
  trackColor?: string
}) => {
  const radius = height / 2
  const p = Math.max(0, Math.min(1, progress))

  return (
    <View pointerEvents="none" style={[StyleSheet.absoluteFill, { borderRadius: radius, overflow: 'hidden' }]}>
      {/* 底层轨道：整圈淡淡的一条，代表未播放部分 */}
      <View
        style={{
          ...StyleSheet.absoluteFillObject,
          borderRadius: radius,
          borderWidth: 1,
          borderColor: trackColor,
        }}
      />
      {/* 进度层：按比例从左侧裁剪出整圈描边的一部分 */}
      <View
        style={{
          position: 'absolute',
          left: 0,
          top: 0,
          bottom: 0,
          width: width * p,
          overflow: 'hidden',
        }}
      >
        <View
          style={{
            width,
            height,
            borderRadius: radius,
            borderWidth: 1.5,
            borderColor: color,
            // 发光：细亮线 + 阴影（无圆点）
            shadowColor: color,
            shadowOffset: { width: 0, height: 0 },
            shadowOpacity: 0.9,
            shadowRadius: 3,
          }}
        />
      </View>
    </View>
  )
})

