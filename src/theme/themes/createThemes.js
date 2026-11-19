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
      primary: 'rgb(242, 120, 104)',
      // 主文字 #F5F2F1
      font: 'rgb(245, 242, 241)',
      'c-app-background': '#0B090A',
      'c-main-background': '#0B090A',
      'bg-image': '',
      'bg-image-position': 'center',
      'bg-image-size': 'cover',

      'c-badge-primary': '#F27868',
      'c-badge-secondary': '#E8B27D',
      'c-badge-tertiary': '#9BB0C4',
    },
  },
  {
    // 移植自 md3Music 的 Material Design 3 设计语言：
    // 种子色 #0061A4（MD3 官方主题构建器的 key tone 40），
    // 深色面用 M3 dark scheme 的 surface / surfaceContainer 层级。
    id: 'md3',
    name: '暗黑Z',
    isDark: true,
    config: {
      primary: 'rgb(161, 201, 255)',
      font: 'rgb(227, 227, 232)',
      'c-app-background': '#121318',
      'c-main-background': '#1A1B21',
      'bg-image': '',
      'bg-image-position': 'center',
      'bg-image-size': 'cover',

      // M3 强调色组：primary / secondary / tertiary 容器色文本
      'c-badge-primary': 'rgb(161, 201, 255)',
      'c-badge-secondary': 'rgb(198, 198, 220)',
      'c-badge-tertiary': 'rgb(236, 178, 213)',
    },
  },
  {
    // 网易云音乐配色（还原自 AIYO77/flutter_cloud_music 的 lib/common/res/colors.dart）
    // 标志性红色 #C93D2D / 点亮红 #EB4D44，深色底 #0D0D0C，卡片 #121111
    id: 'netease',
    name: '网易云',
    isDark: true,
    config: {
      primary: 'rgb(201, 61, 45)',
      font: 'rgb(254, 254, 254)',
      'c-app-background': '#0D0D0C',
      'c-main-background': '#121111',
      'bg-image': '',
      'bg-image-position': 'center',
      'bg-image-size': 'cover',

      'c-badge-primary': 'rgb(235, 77, 68)',
      'c-badge-secondary': 'rgb(255, 205, 41)',
      'c-badge-tertiary': 'rgb(90, 124, 170)',
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

