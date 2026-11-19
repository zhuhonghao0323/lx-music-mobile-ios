//! 更新默认主题配置后，需要执行 npm run build:theme 重新构建index.json

const fs = require('fs')
const path = require('path')
const { createThemeColors } = require('./utils')

const defaultThemes = [
  {
    // 浅色版 Liquid Glass：纯白底 + 黑字 + 琥珀金强调 + 微灰液态按钮。
    // 参考 Beans Music 浅色态；与深色版共用同一套「玻璃光学层」逻辑，
    // 只是底色与描边方向取反。
    id: 'liquid_glass_light',
    name: '液态玻璃·浅色（白底黑字）',
    isDark: false,
    config: {
      primary: 'rgb(184, 112, 8)',
      // 浅色主题需要深字
      font: 'rgb(17, 17, 17)',
      'c-app-background': '#FFFFFF',
      'c-main-background': '#F7F7FA',
      'bg-image': '',
      'bg-image-position': 'center',
      'bg-image-size': 'cover',

      'c-badge-primary': '#B87008',
      'c-badge-secondary': '#C07A0A',
      'c-badge-tertiary': '#8E8E93',
    },
  },
  {
    // iOS 27 Liquid Glass 视觉语言（按设计交付说明还原）
    // 暖黑环境底 + 珊瑚粉橙强调色；iOS 17 用原生 UIVisualEffectView 毛玻璃近似。
    id: 'liquid_glass',
    name: '液态玻璃',
    isDark: true,
    config: {
      // 珊瑚粉橙强调色 #F27868
      primary: 'rgb(245, 179, 89)',
      // 主文字 #F5F2F1
      font: 'rgb(245, 242, 241)',
      'c-app-background': '#0B090A',
      'c-main-background': '#0B090A',
      'bg-image': '',
      'bg-image-position': 'center',
      'bg-image-size': 'cover',

      'c-badge-primary': '#F5B359',
      'c-badge-secondary': '#C07A0A',
      'c-badge-tertiary': '#9BB0C4',
    },
  },
]

const themes = defaultThemes.map(({ config: { primary, font, ...extInfo }, ...themeInfo }) => {
  return {
    ...themeInfo,
    isCustom: false,
    config: {
      themeColors: createThemeColors(primary, font, themeInfo.isDark),
      extInfo,
    },
  }
})

fs.writeFileSync(path.join(__dirname, 'themes.ts'), `/* eslint-disable */\n//! 此文件由 createThemes.js 生成\n\nexport default ${JSON.stringify(themes, null, 2)} as const`)

