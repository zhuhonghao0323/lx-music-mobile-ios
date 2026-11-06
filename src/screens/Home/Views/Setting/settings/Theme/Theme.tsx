import { memo, useCallback, useEffect, useMemo, useState } from 'react'
import { View, TouchableOpacity, type ImageSourcePropType } from 'react-native'
import { setTheme } from '@/core/theme'
import { useI18n } from '@/lang'
import { useSettingValue } from '@/store/setting/hook'
import { useTheme } from '@/store/theme/hook'

import SubTitle from '../../components/SubTitle'
import { BG_IMAGES, getAllThemes, type LocalTheme } from '@/theme/themes'
import Text from '@/components/common/Text'
import { createStyle } from '@/utils/tools'
import { scaleSizeH } from '@/utils/pixelRatio'
import { Icon } from '@/components/common/Icon'
import ImageBackground from '@/components/common/ImageBackground'
import { LIQUID_GLASS_ID, useIsGlass } from '@/theme/glass'

const useActive = (id: string) => {
  const activeThemeId = useSettingValue('theme.id')
  const isActive = useMemo(() => activeThemeId == id, [activeThemeId, id])
  return isActive
}

const ThemeItem = ({ id, name, color, image, setTheme, showAll }: {
  id: string
  name: string
  color: string
  showAll: boolean
  image?: ImageSourcePropType
  setTheme: (id: string) => void
}) => {
  const theme = useTheme()
  const isActive = useActive(id)
  const isGlassItem = id == LIQUID_GLASS_ID

  return (
    showAll || isActive ? (
      <TouchableOpacity style={{ ...styles.item, width: scaleSizeH(ITEM_HEIGHT) }} activeOpacity={0.5} onPress={() => { setTheme(id) }}>
        <View style={{ ...styles.colorContent, width: scaleSizeH(COLOR_ITEM_HEIGHT), borderColor: isActive ? (isGlassItem ? 'rgba(255,255,255,0.9)' : color) : 'transparent' }}>
          {
            isGlassItem
              ? <View style={{ ...styles.imageContent, width: scaleSizeH(IMAGE_HEIGHT), backgroundColor: 'rgba(255,255,255,0.16)', borderWidth: 1, borderColor: 'rgba(255,255,255,0.55)' }}>
                  <View style={styles.glassBlobA} />
                  <View style={styles.glassBlobB} />
                  <View style={styles.glassBlobC} />
                </View>
              : image
                ? <ImageBackground style={{ ...styles.imageContent, width: scaleSizeH(IMAGE_HEIGHT), backgroundColor: color }}
                    imageStyle={{ borderRadius: 4 }}
                    source={image} />
                : <View style={{ ...styles.imageContent, width: scaleSizeH(IMAGE_HEIGHT), backgroundColor: color }}></View>
          }
        </View>
        <Text style={styles.name} size={12} color={isActive ? (isGlassItem ? '#ffffff' : color) : theme['c-font']} numberOfLines={1}>{name}</Text>
      </TouchableOpacity>
    ) : null
  )
}

const MoreBtn = ({ showAll, setShowAll }: {
  showAll: boolean
  setShowAll: (showAll: boolean) => void
}) => {
  const theme = useTheme()
  const t = useI18n()

  return (
    showAll ? null
      : (
          <TouchableOpacity style={styles.moreBtn} activeOpacity={0.5} onPress={() => { setShowAll(!showAll) }}>
            <Text size={14} color={theme['c-primary-font']} numberOfLines={1}>{t('setting_basic_theme_more_btn_show')}</Text>
            <Icon name="chevron-right" size={12} color={theme['c-primary-font']} />
          </TouchableOpacity>
        )

  )
}

interface ThemeInfo {
  themes: Readonly<LocalTheme[]>
  userThemes: LX.Theme[]
  dataPath: string
}
const initInfo: ThemeInfo = { themes: [], userThemes: [], dataPath: '' }
export default memo(() => {
  const [showAll, setShowAll] = useState(false)
  const t = useI18n()
  const isGlass = useIsGlass()
  const [themeInfo, setThemeInfo] = useState(initInfo)
  const setThemeId = useCallback((id: string) => {
    requestAnimationFrame(() => {
      setTheme(id)
    })
  }, [])

  useEffect(() => {
    void getAllThemes().then(setThemeInfo)
  }, [])

  return (
    <SubTitle title={t('setting_basic_theme')}>
      {isGlass ? <Text style={styles.glassDesc} size={11} color="rgba(226, 236, 255, 0.72)">{t('setting_liquid_glass_desc')}</Text> : null}
      <View style={styles.list}>
        {
          themeInfo.themes.map(({ id, config }) => {
            return <ThemeItem
              key={id}
              color={config.themeColors['c-theme']}
              image={config.extInfo['bg-image'] ? BG_IMAGES[config.extInfo['bg-image']] : undefined}
              showAll={showAll}
              id={id}
              name={t(`theme_${id}`)}
              setTheme={setThemeId} />
          })
        }
        {
          themeInfo.userThemes.map(({ id, name, config }) => {
            return <ThemeItem
              key={id}
              color={config.themeColors['c-theme']}
              // image={undefined}
              showAll={showAll}
              id={id}
              name={name}
              setTheme={setThemeId} />
          })
        }
        <MoreBtn showAll={showAll} setShowAll={setShowAll} />
      </View>
    </SubTitle>
  )
})

const ITEM_HEIGHT = 62
const COLOR_ITEM_HEIGHT = 36
const IMAGE_HEIGHT = 29
const styles = createStyle({
  list: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 10,
    marginTop: 5,
  },
  item: {
    // marginRight: 15,
    alignItems: 'center',
    // marginTop: 5,
    // backgroundColor: 'rgba(0,0,0,0.2)',
  },
  colorContent: {
    height: COLOR_ITEM_HEIGHT,
    borderRadius: 4,
    borderWidth: 1.6,
    alignItems: 'center',
    justifyContent: 'center',
    // backgroundColor: 'rgba(0,0,0,0.2)',
  },
  imageContent: {
    height: IMAGE_HEIGHT,
    borderRadius: 4,
    overflow: 'hidden',
    flexDirection: 'row',
    // elevation: 1,
  },
  glassBlobA: { position: 'absolute', width: 18, height: 18, borderRadius: 9, backgroundColor: 'rgba(120, 180, 255, 0.9)', top: -4, left: 2 },
  glassBlobB: { position: 'absolute', width: 14, height: 14, borderRadius: 7, backgroundColor: 'rgba(198, 130, 255, 0.9)', bottom: -3, left: 10 },
  glassBlobC: { position: 'absolute', width: 12, height: 12, borderRadius: 6, backgroundColor: 'rgba(80, 224, 200, 0.9)', top: 4, right: 3 },
  glassDesc: { marginTop: -4, marginBottom: 8, marginLeft: -10 },
  name: {
    marginTop: 2,
  },
  moreBtn: {
    marginLeft: 10,
    flexDirection: 'row',
    alignItems: 'center',
    // justifyContent: 'center',
    gap: 8,
  },
})
