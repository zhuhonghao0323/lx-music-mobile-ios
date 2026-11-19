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

  // 浅色液态玻璃：白底 + 黑字 + 琥珀金强调（参考 Beans Music 浅色态）。
  // 关键点：浅色主题里「白色控件叠白色背景」几乎不可见，
  // 因此控件改用「极淡冷灰半透底 + 明确描边」，靠明度差营造液态玻璃质感。
  if (theme.id == 'liquid_glass_light') {
    const text = '#111111'
    const textDim = 'rgba(60, 60, 67, 0.60)'
    // 浅色背景下用深琥珀，保证对比度（Beans tintLight）
    const tint = '#B87008'
    const surfaceStrong = '#FFFFFF'
    // 控件底色：比白底略暗一档的冷灰，形成清晰的「可点击块」观感（液态玻璃微灰）
    const control = 'rgba(232, 232, 236, 0.92)'
    const controlActive = 'rgba(218, 218, 224, 1)'
    const border = 'rgba(60, 60, 67, 0.18)'
    const borderSoft = 'rgba(60, 60, 67, 0.10)'
    const glassLightOverrides: Partial<LX.ActiveTheme> = {
      // 页面纯白，控件用微灰，明度差足够
      'c-app-background': '#FFFFFF',
      'c-main-background': '#F7F7FA',
      'c-content-background': surfaceStrong,
      'c-border-background': border,
      'c-font': text,
      'c-font-label': textDim,
      'c-primary-font': tint,
      'c-primary-font-hover': 'rgba(184, 112, 8, 0.86)',
      'c-primary-font-active': 'rgba(184, 112, 8, 0.72)',
      'c-primary-background': 'rgba(242, 163, 60, 0.14)',
      'c-primary-background-hover': 'rgba(242, 163, 60, 0.20)',
      'c-primary-background-active': 'rgba(242, 163, 60, 0.26)',
      'c-primary-input-background': control,
      'c-button-font': text,
      'c-button-font-selected': '#FFFFFF',
      // 按钮：微灰半透底 + 深字，白底页面上清晰可见
      'c-button-background': control,
      'c-button-background-selected': 'rgba(242, 163, 60, 0.92)',
      'c-button-background-hover': controlActive,
      'c-button-background-active': controlActive,
      'c-list-header-border-bottom': borderSoft,
      'c-badge-primary': tint,
      'c-badge-secondary': '#C07A0A',
      'c-badge-tertiary': '#8E8E93',
    }
    Object.assign(activeTheme, glassLightOverrides)
  }

  // 液态玻璃（深色，全局主推主题）：
  // 冷黑 #0A0A0C 环境底 + 品牌琥珀暖金 #F5B359 强调色。
  // 与浅色液态玻璃共享同一套设计 token（见 glassMaterial.ts）。
  if (theme.id == 'liquid_glass') {
    const surface = 'rgba(255, 255, 255, 0.08)'
    const surfaceStrong = 'rgba(255, 255, 255, 0.13)'
    const control = 'rgba(255, 255, 255, 0.08)'
    const controlActive = 'rgba(255, 255, 255, 0.16)'
    const border = 'rgba(255, 255, 255, 0.14)'
    const borderSoft = 'rgba(255, 255, 255, 0.08)'
    const text = '#FFFFFF'
    const textDim = '#98989F'
    const tint = '#F5B359'
    const glassOverrides: Partial<LX.ActiveTheme> = {
      'c-app-background': '#0A0A0C',
      'c-main-background': '#0A0A0C',
      'c-content-background': '#1C1C1E',
      'c-border-background': border,
      'c-font': text,
      'c-font-label': textDim,
      'c-primary-font': tint,
      'c-primary-font-hover': 'rgba(245, 179, 89, 0.85)',
      'c-primary-font-active': 'rgba(245, 179, 89, 0.70)',
      'c-primary-background': surface,
      'c-primary-background-hover': surfaceStrong,
      'c-primary-background-active': controlActive,
      'c-primary-input-background': control,
      'c-button-font': text,
      'c-button-font-selected': '#FFFFFF',
      'c-button-background': control,
      'c-button-background-selected': 'rgba(245, 179, 89, 0.30)',
      'c-button-background-hover': surfaceStrong,
      'c-button-background-active': controlActive,
      'c-list-header-border-bottom': borderSoft,
      'c-badge-primary': tint,
      'c-badge-secondary': '#C07A0A',
      'c-badge-tertiary': '#8E8E93',
    }
    Object.assign(activeTheme, glassOverrides)
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
