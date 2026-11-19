import { useIsGlass, useIsGlassLight } from './glass'

/**
 * ============================================================
 * Liquid Glass 材质系统（Glass Material System）
 * ============================================================
 *
 * 产品级玻璃材质的统一管理层。业务页面只通过这些 token/样式函数取材质，
 * 不直接写版本判断，也不直接写半透明底色。
 *
 * 材质四级：
 *   thin     轻薄 —— 顶部栏、列表分区条
 *   regular  标准 —— 卡片、迷你播放器、按钮组
 *   thick    厚重 —— Bottom Sheet、弹窗（高不透明、强层次）
 *   floating 悬浮 —— 底部导航托盘（Regular + 上浮阴影 + 亮上缘高光）
 *
 * 深浅色自适应：本文件内部根据主题深浅返回不同参数，页面无需分支。
 * iOS 17/18 通过 UIVisualEffectView（BlurView）模拟；材质本体在
 * components/common/GlassView.tsx 渲染，这里只负责参数（blur 量、
 * 透明度、色彩倾向、边缘高光、描边、阴影、圆角）。
 */

/** 设计 Token —— 色彩（深色基准） */
export const TOKEN_COLOR = {
  brand: '#F5B359', // 品牌主色（琥珀暖金）
  brandSoft: 'rgba(245, 179, 89, 0.16)',
  bg: '#0A0A0C', // 主背景（冷黑，避免纯黑）
  surface: '#161618', // 次级背景（列表、分区）
  card: '#1C1C1E', // 卡片底（不透明兜底）
  text: '#FFFFFF', // 主文字
  textSecondary: '#98989F', // 次级文字
  textTertiary: '#6C6C70', // 辅助文字
  divider: 'rgba(255, 255, 255, 0.08)',
  icon: '#98989F',
  accent: '#E8402A', // 强调色（平台切换/错误，克制使用）
  danger: '#E8402A',
} as const

/** 设计 Token —— 色彩（浅色基准） */
export const TOKEN_COLOR_LIGHT = {
  brand: '#B87008',
  brandSoft: 'rgba(184, 112, 8, 0.12)',
  bg: '#F2F2F7',
  surface: '#FFFFFF',
  card: '#FFFFFF',
  text: '#111111',
  textSecondary: '#6C6C70',
  textTertiary: '#8E8E93',
  divider: 'rgba(0, 0, 0, 0.08)',
  icon: '#6C6C70',
  accent: '#E8402A',
  danger: '#E8402A',
} as const

/** 设计 Token —— 圆角 */
export const TOKEN_RADIUS = {
  xs: 10, // 小元素（缩略图、徽标）
  sm: 14, // 控件（按钮、输入框）
  md: 20, // 中等容器
  lg: 24, // 大卡片、Sheet
  xl: 28, // 底部导航托盘
  full: 999, // 胶囊
} as const

/** 设计 Token —— 间距（4pt 基准） */
export const TOKEN_SPACE = {
  xxs: 4,
  xs: 8,
  sm: 12,
  md: 16,
  lg: 20,
  xl: 24,
  xxl: 32,
} as const

/** 按当前主题取色彩 token */
export const useTokenColor = () => (useIsGlassLight() ? TOKEN_COLOR_LIGHT : TOKEN_COLOR)

/** 按当前主题取品牌主色 */
export const useBrandColor = () => (useIsGlassLight() ? TOKEN_COLOR_LIGHT.brand : TOKEN_COLOR.brand)

export type GlassMaterialName = 'ultraThin' | 'thin' | 'regular' | 'thick' | 'floating'

interface GlassParams {
  blurAmount: number
  /** 材质之上的色彩倾向层（浅色=白、深色=白），alpha 越小越通透 */
  tintAlpha: number
  /** 上缘高光强度 */
  highlightAlpha: number
  /** 描边 */
  borderAlpha: number
  /** 阴影（floating 才有明显投影） */
  shadow: { radius: number, opacity: number, offsetY: number } | null
  /** 推荐圆角 */
  radius: number
}

const DARK_PARAMS: Record<GlassMaterialName, GlassParams> = {
  ultraThin: { blurAmount: 6, tintAlpha: 0.02, highlightAlpha: 0.05, borderAlpha: 0.06, shadow: null, radius: TOKEN_RADIUS.sm },
  thin: { blurAmount: 8, tintAlpha: 0.04, highlightAlpha: 0.08, borderAlpha: 0.10, shadow: null, radius: TOKEN_RADIUS.md },
  regular: { blurAmount: 14, tintAlpha: 0.06, highlightAlpha: 0.10, borderAlpha: 0.14, shadow: { radius: 16, opacity: 0.30, offsetY: 6 }, radius: TOKEN_RADIUS.lg },
  thick: { blurAmount: 22, tintAlpha: 0.10, highlightAlpha: 0.14, borderAlpha: 0.16, shadow: { radius: 28, opacity: 0.45, offsetY: 12 }, radius: TOKEN_RADIUS.lg },
  floating: { blurAmount: 14, tintAlpha: 0.08, highlightAlpha: 0.14, borderAlpha: 0.18, shadow: { radius: 22, opacity: 0.38, offsetY: 10 }, radius: TOKEN_RADIUS.xl },
}

const LIGHT_PARAMS: Record<GlassMaterialName, GlassParams> = {
  ultraThin: { blurAmount: 6, tintAlpha: 0.45, highlightAlpha: 0.45, borderAlpha: 0.05, shadow: null, radius: TOKEN_RADIUS.sm },
  thin: { blurAmount: 8, tintAlpha: 0.55, highlightAlpha: 0.55, borderAlpha: 0.08, shadow: null, radius: TOKEN_RADIUS.md },
  regular: { blurAmount: 12, tintAlpha: 0.60, highlightAlpha: 0.60, borderAlpha: 0.10, shadow: { radius: 14, opacity: 0.10, offsetY: 4 }, radius: TOKEN_RADIUS.lg },
  thick: { blurAmount: 18, tintAlpha: 0.72, highlightAlpha: 0.70, borderAlpha: 0.12, shadow: { radius: 22, opacity: 0.16, offsetY: 8 }, radius: TOKEN_RADIUS.lg },
  floating: { blurAmount: 12, tintAlpha: 0.64, highlightAlpha: 0.66, borderAlpha: 0.12, shadow: { radius: 18, opacity: 0.12, offsetY: 6 }, radius: TOKEN_RADIUS.xl },
}

/** 取指定材质的参数（按当前深浅主题） */
export const useGlassParams = (material: GlassMaterialName): GlassParams => {
  const isLight = useIsGlassLight()
  return (isLight ? LIGHT_PARAMS : DARK_PARAMS)[material]
}

/** 是否在液态玻璃主题 */
export { useIsGlass }
