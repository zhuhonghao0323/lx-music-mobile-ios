/* eslint-disable @typescript-eslint/no-var-requires */
import { getUserTheme, saveUserTheme } from '@/utils/data'
import themes from '@/theme/themes/themes'
import settingState from '@/store/setting/state'
import themeState from '@/store/theme/state'
import { isUrl } from '@/utils'
import { privateStorageDirectoryPath } from '@/utils/fs'
import { type ImageSourcePropType } from 'react-native'

export const BG_IMAGES = {
  'china_ink.jpg': require('./images/china_ink.jpg') as ImageSourcePropType,
  'jqbg.jpg': require('./images/jqbg.jpg') as ImageSourcePropType,
  'landingMoon.png': require('./images/landingMoon2.png') as ImageSourcePropType,
  'myzcbg.jpg': require('./images/myzcbg.jpg') as ImageSourcePropType,
  'xnkl.png': require('./images/xnkl.png') as ImageSourcePropType,
} as const


let userThemes: LX.Theme[]
export const getAllThemes = async() => {
  // eslint-disable-next-line require-atomic-updates
  userThemes ??= await getUserTheme()
  return {
    themes,
    userThemes,
    dataPath: privateStorageDirectoryPath + '/theme_images',
  }
}

export const saveTheme = async(theme: LX.Theme) => {
  const targetTheme = userThemes.find(t => t.id === theme.id)
  if (targetTheme) Object.assign(targetTheme, theme)
  else userThemes.push(theme)
  await saveUserTheme(userThemes)
}

export const removeTheme = async(id: string) => {
  const index = userThemes.findIndex(t => t.id === id)
  if (index < 0) return
  userThemes.splice(index, 1)
  await saveUserTheme(userThemes)
}

export type LocalTheme = typeof themes[number]
type ColorsKey = keyof LX.Theme['config']['themeColors']
type ExtInfoKey = keyof LX.Theme['config']['extInfo']
const varColorRxp = /^var\((.+)\)$/
export const buildActiveThemeColors = (theme: LX.Theme): LX.ActiveTheme => {
  let bgImg: ImageSourcePropType | undefined
  if (theme.isCustom) {
    if (theme.config.extInfo['bg-image']) {
      theme.config.extInfo['bg-image'] =
        isUrl(theme.config.extInfo['bg-image'])
          ? theme.config.extInfo['bg-image']
          : `${privateStorageDirectoryPath}/theme_images/${theme.config.extInfo['bg-image']}`
    }
  } else {
    const extInfo = (theme as LocalTheme).config.extInfo
    if (extInfo['bg-image']) {
      if (!theme.isDark || !settingState.setting['theme.hideBgDark']) bgImg = BG_IMAGES[extInfo['bg-image']]
    }
  }

  theme.config.extInfo = { ...theme.config.extInfo }

  for (const [k, v] of Object.entries(theme.config.extInfo) as Array<[ExtInfoKey, LX.Theme['config']['extInfo'][ExtInfoKey]]>) {
    if (!v.startsWith('var(')) continue
    theme.config.extInfo[k] = theme.config.themeColors[v.replace(varColorRxp, '$1') as ColorsKey]
  }

  const activeTheme: LX.ActiveTheme = {
    id: theme.id,
    name: theme.name,
    isDark: theme.isDark,
    ...theme.config.themeColors,
    ...theme.config.extInfo,
    'c-font': theme.config.themeColors['c-850'],
    'c-font-label': theme.config.themeColors['c-450'],
    'c-primary-font': theme.config.themeColors['c-primary'],
    'c-primary-font-hover': theme.config.themeColors['c-primary-alpha-300'],
    'c-primary-font-active': theme.config.themeColors['c-primary-dark-100-alpha-200'],
    'c-primary-background': theme.config.themeColors['c-primary-light-400-alpha-700'],
    'c-primary-background-hover': theme.config.themeColors['c-primary-light-300-alpha-800'],
    'c-primary-background-active': theme.config.themeColors['c-primary-light-100-alpha-800'],
    'c-primary-input-background': theme.config.themeColors['c-primary-light-400-alpha-700'],
    'c-button-font': theme.config.themeColors['c-primary-alpha-100'],
    'c-button-font-selected': theme.config.themeColors['c-primary-dark-100-alpha-100'],
    'c-button-background': theme.config.themeColors['c-primary-light-400-alpha-700'],
    'c-button-background-selected': theme.config.themeColors['c-primary-alpha-600'],
    'c-button-background-hover': theme.config.themeColors['c-primary-light-300-alpha-600'],
    'c-button-background-active': theme.config.themeColors['c-primary-light-100-alpha-600'],
    'c-list-header-border-bottom': theme.config.themeColors['c-primary-alpha-900'],
    'c-content-background': theme.config.themeColors['c-primary-light-1000'],
    'c-border-background': theme.config.themeColors['c-primary-light-100-alpha-700'],
    'bg-image': bgImg,
  }

  // 浅色液态玻璃：白霜底 + 深字 + 珊瑚强调。
  // 描边在这里要「反色」——浅底上用深色描边才有玻璃边缘感。
  if (theme.id == 'liquid_glass_light') {
    const text = '#1C1A1A'
    const textDim = 'rgba(60, 55, 55, 0.62)'
    const tint = 'rgba(226, 96, 80, 0.95)'
    const surface = 'rgba(255, 255, 255, 0.62)'
    const surfaceStrong = 'rgba(255, 255, 255, 0.82)'
    const control = 'rgba(255, 255, 255, 0.58)'
    const controlActive = 'rgba(255, 255, 255, 0.86)'
    const border = 'rgba(120, 110, 105, 0.20)'
    const borderSoft = 'rgba(120, 110, 105, 0.12)'
    const glassLightOverrides: Partial<LX.ActiveTheme> = {
      'c-app-background': '#F2EFED',
      'c-main-background': '#F7F5F3',
      'c-content-background': surfaceStrong,
      'c-border-background': border,
      'c-font': text,
      'c-font-label': textDim,
      'c-primary-font': tint,
      'c-primary-font-hover': 'rgba(226, 96, 80, 0.82)',
      'c-primary-font-active': 'rgba(226, 96, 80, 0.68)',
      'c-primary-background': surface,
      'c-primary-background-hover': surfaceStrong,
      'c-primary-background-active': controlActive,
      'c-primary-input-background': control,
      'c-button-font': text,
      'c-button-font-selected': '#FFFFFF',
      'c-button-background': control,
      'c-button-background-selected': 'rgba(226, 96, 80, 0.88)',
      'c-button-background-hover': surfaceStrong,
      'c-button-background-active': controlActive,
      'c-list-header-border-bottom': borderSoft,
      'c-badge-primary': tint,
      'c-badge-secondary': '#C89150',
      'c-badge-tertiary': '#5F7E99',
    }
    Object.assign(activeTheme, glassLightOverrides)
  }

  // 液态玻璃（iOS 27 Liquid Glass 视觉语言，按设计交付说明还原）：
  // 把全局语义色统一改成半透明玻璃色，这样所有引用
  // c-button-background / c-content-background / c-primary-background …
  // 的组件都会自动获得一致的玻璃质感，无需逐个改造。
  // 基调：暖黑 #0B090A 环境底 + 珊瑚粉橙 #F27868 强调色。
  if (theme.id == 'liquid_glass') {
    const surface = 'rgba(255, 255, 255, 0.10)'
    const surfaceStrong = 'rgba(255, 255, 255, 0.16)'
    const control = 'rgba(255, 255, 255, 0.12)'
    const controlActive = 'rgba(255, 255, 255, 0.22)'
    // 玻璃描边 rgba(255,255,255,0.22)（设计规范）
    const border = 'rgba(255, 255, 255, 0.22)'
    const borderSoft = 'rgba(255, 255, 255, 0.12)'
    // 主文字 #F5F2F1 / 次级文字 #B8B0B0（设计规范）
    const text = '#F5F2F1'
    const textDim = '#B8B0B0'
    // 强调色 #F27868
    const tint = 'rgba(242, 120, 104, 0.95)'
    const glassOverrides: Partial<LX.ActiveTheme> = {
      // 暖黑环境底，避免纯黑造成层次断裂
      'c-app-background': '#0B090A',
      'c-main-background': '#0B090A',
      'c-content-background': surfaceStrong,
      'c-border-background': border,
      'c-font': text,
      'c-font-label': textDim,
      'c-primary-font': tint,
      'c-primary-font-hover': 'rgba(242, 120, 104, 0.82)',
      'c-primary-font-active': 'rgba(242, 120, 104, 0.68)',
      'c-primary-background': surface,
      'c-primary-background-hover': surfaceStrong,
      'c-primary-background-active': controlActive,
      'c-primary-input-background': control,
      'c-button-font': text,
      'c-button-font-selected': '#FFFFFF',
      'c-button-background': control,
      'c-button-background-selected': 'rgba(242, 120, 104, 0.42)',
      'c-button-background-hover': surfaceStrong,
      'c-button-background-active': controlActive,
      'c-list-header-border-bottom': borderSoft,
      'c-badge-primary': tint,
      'c-badge-secondary': '#E8B27D',
      'c-badge-tertiary': '#9BB0C4',
    }
    Object.assign(activeTheme, glassOverrides)
  }

  // MD3（移植自 md3Music）：Material Design 3 深色 surface 层级 + primary/secondary 容器色。
  // 语义色全部按 M3 ColorScheme(dark) 的 token 命名映射，保证卡片/按钮/弹层的层次与官方一致。
  if (theme.id == 'md3') {
    const md3Overrides: Partial<LX.ActiveTheme> = {
      // --- M3 surface 层级（dark scheme） ---
      'c-app-background': '#121318',
      'c-main-background': '#1A1B21',
      'c-content-background': '#1E1F25',
      'c-border-background': '#44474F',
      'c-list-header-border-bottom': '#2A2C33',

      // --- M3 onSurface / onSurfaceVariant ---
      'c-font': '#E3E3E8',
      'c-font-label': '#C4C6CF',

      // --- M3 primary / onPrimaryContainer ---
      'c-primary-font': '#A1C9FF',
      'c-primary-font-hover': '#BCD5FF',
      'c-primary-font-active': '#D4E3FF',

      // --- M3 primaryContainer / secondaryContainer ---
      'c-primary-background': '#2C3A4E',
      'c-primary-background-hover': '#374A63',
      'c-primary-background-active': '#44587A',
      'c-primary-input-background': '#26272E',

      // --- M3 按钮：filled 用 primary，tonal 用 secondaryContainer ---
      'c-button-font': '#DDEEFF',
      'c-button-font-selected': '#0B1B2B',
      'c-button-background': '#2C3A4E',
      'c-button-background-selected': '#A1C9FF',
      'c-button-background-hover': '#374A63',
      'c-button-background-active': '#44587A',

      // --- M3 徽章：primary / secondary / tertiary ---
      'c-badge-primary': '#A1C9FF',
      'c-badge-secondary': '#C6C6DC',
      'c-badge-tertiary': '#ECB2D5',
    }
    Object.assign(activeTheme, md3Overrides)
  }

  // 网易云音乐：还原 flutter_cloud_music 的配色
  // （lib/common/res/colors.dart：app_main #C93D2D、app_main_light #EB4D44、
  //  dark_bg_color #0D0D0C、dark_card_color #121111、back1 #1D1F22、back2 #121314）
  if (theme.id == 'netease') {
    const neteaseOverrides: Partial<LX.ActiveTheme> = {
      // --- 深色背景层级 ---
      'c-app-background': '#0D0D0C',
      'c-main-background': '#121111',
      'c-content-background': '#1D1F22',
      'c-border-background': '#2A2A2A',
      'c-list-header-border-bottom': '#1A1A19',

      // --- 文字：深色模式下白色 0.85 透明度的层级 ---
      'c-font': '#FEFEFE',
      'c-font-label': 'rgba(255, 255, 255, 0.65)',

      // --- 标志性红色 ---
      'c-primary-font': '#EB4D44',
      'c-primary-font-hover': '#F2675F',
      'c-primary-font-active': '#FF8A84',

      // --- 红色容器（卡片/选中态） ---
      'c-primary-background': '#3A1B18',
      'c-primary-background-hover': '#4A211D',
      'c-primary-background-active': '#611A1A',
      'c-primary-input-background': '#232323',

      // --- 按钮：选中红 #E13534，未选中暗红 #611A1A ---
      'c-button-font': '#FEFEFE',
      'c-button-font-selected': '#FFFFFF',
      'c-button-background': '#3A1B18',
      'c-button-background-selected': '#E13534',
      'c-button-background-hover': '#4A211D',
      'c-button-background-active': '#611A1A',

      // --- 徽章：网易云红 / 黄色 / 蓝色 ---
      'c-badge-primary': '#EB4D44',
      'c-badge-secondary': '#FFCD29',
      'c-badge-tertiary': '#5A7CAA',
    }
    Object.assign(activeTheme, neteaseOverrides)
  }

  return activeTheme
}


// const copyTheme = (theme: LX.Theme): LX.Theme => {
//   return {
//     ...theme,
//     config: {
//       ...theme.config,
//       extInfo: { ...theme.config.extInfo },
//       themeColors: { ...theme.config.themeColors },
//     },
//   }
// }
// type IDS = LocalTheme['id']
export const getTheme = async() => {
  // fs.promises.readdir()
  const shouldUseDarkColors = themeState.shouldUseDarkColors
  // let themeId = settingState.setting['theme.id'] == 'auto'
  //   ? shouldUseDarkColors
  //     ? settingState.setting['theme.darkId']
  //     : settingState.setting['theme.lightId']
  //   // : 'china_ink'
  //   : settingState.setting['theme.id']
  const selectedThemeId = settingState.setting['theme.id']
  // 液态玻璃本身就是深色玻璃，跟随系统深色时不应被强制替换为纯黑主题
  const isLiquidGlass = selectedThemeId == 'liquid_glass'
  let themeId = settingState.setting['common.isAutoTheme'] && shouldUseDarkColors && !isLiquidGlass
    ? 'black'
    : selectedThemeId
  // themeId = 'naruto'
  // themeId = 'pink'
  // themeId = 'black'
  let theme: LocalTheme | LX.Theme | undefined = themes.find(theme => theme.id == themeId)
  if (!theme) {
    userThemes = await getUserTheme()
    theme = userThemes.find(theme => theme.id == themeId)
    if (!theme) {
      themeId = settingState.setting['theme.id'] == 'auto' && shouldUseDarkColors ? 'black' : 'green'
      theme = themes.find(theme => theme.id == themeId) as LX.Theme
    }
  }

  return theme
}
