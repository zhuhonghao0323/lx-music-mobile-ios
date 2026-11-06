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

  // 液态玻璃：把全局语义色统一改成半透明玻璃色，
  // 这样所有引用 c-button-background / c-content-background / c-primary-background …
  // 的组件都会自动获得一致的玻璃质感，无需逐个改造。
  if (theme.id == 'liquid_glass') {
    const surface = 'rgba(255, 255, 255, 0.14)'
    const surfaceStrong = 'rgba(255, 255, 255, 0.22)'
    const control = 'rgba(255, 255, 255, 0.16)'
    const controlActive = 'rgba(255, 255, 255, 0.30)'
    const border = 'rgba(255, 255, 255, 0.38)'
    const borderSoft = 'rgba(255, 255, 255, 0.16)'
    const text = '#f4f8ff'
    const textDim = 'rgba(226, 236, 255, 0.62)'
    const tint = 'rgba(120, 190, 255, 0.95)'
    const glassOverrides: Partial<LX.ActiveTheme> = {
      'c-app-background': 'rgba(11, 16, 36, 0.55)',
      'c-main-background': 'rgba(11, 16, 36, 0.42)',
      'c-content-background': surfaceStrong,
      'c-border-background': border,
      'c-font': text,
      'c-font-label': textDim,
      'c-primary-font': tint,
      'c-primary-font-hover': 'rgba(120, 190, 255, 0.75)',
      'c-primary-font-active': 'rgba(120, 190, 255, 0.6)',
      'c-primary-background': surface,
      'c-primary-background-hover': surfaceStrong,
      'c-primary-background-active': controlActive,
      'c-primary-input-background': control,
      'c-button-font': text,
      'c-button-font-selected': '#ffffff',
      'c-button-background': control,
      'c-button-background-selected': 'rgba(120, 190, 255, 0.35)',
      'c-button-background-hover': surfaceStrong,
      'c-button-background-active': controlActive,
      'c-list-header-border-bottom': borderSoft,
      'c-badge-primary': tint,
      'c-badge-secondary': 'rgba(198, 130, 255, 1)',
      'c-badge-tertiary': 'rgba(80, 224, 200, 1)',
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
