import { memo } from 'react'
import { View, TouchableOpacity, StyleSheet } from 'react-native'
import SubTitle from '../../components/SubTitle'
import Text from '@/components/common/Text'
import CheckBox from '@/components/common/CheckBox'
import { useSettingValue } from '@/store/setting/hook'
import { updateSetting } from '@/core/common'
import { useI18n } from '@/lang'
import { useTheme } from '@/store/theme/hook'
import { scaleSizeW } from '@/utils/pixelRatio'

const COLOR_OPTIONS = [
  { key: 'white', color: '#ffffff', labelKey: 'player_lyric_color_white' },
  { key: 'blue', color: '#7fc4ff', labelKey: 'player_lyric_color_blue' },
  { key: 'pink', color: '#ff8fb1', labelKey: 'player_lyric_color_pink' },
  { key: 'green', color: '#7ee8a2', labelKey: 'player_lyric_color_green' },
] as const

const FONT_SIZE_OPTIONS = [13, 15, 17, 19, 21]

/** 播放页封面下方三行歌词预览的外观设置 */
export default memo(() => {
  const t = useI18n()
  const theme = useTheme()
  const color = useSettingValue('theme.lyricPreviewColor')
  const fontSize = useSettingValue('theme.lyricPreviewFontSize')

  return (
    <SubTitle title={t('player_lyric_color')}>
      <View style={styles.colorRow}>
        {
          COLOR_OPTIONS.map(opt => (
            <TouchableOpacity
              key={opt.key}
              style={[styles.colorDotWrap, { borderColor: color == opt.key ? opt.color : 'transparent' }]}
              onPress={() => { updateSetting({ 'theme.lyricPreviewColor': opt.key }) }}
              activeOpacity={0.6}
            >
              <View style={[styles.colorDot, { backgroundColor: opt.color }]} />
            </TouchableOpacity>
          ))
        }
      </View>
      <Text style={styles.subTitle} size={13} color={theme['c-font']}>{t('player_lyric_font_size')}</Text>
      <View style={styles.sizeRow}>
        {
          FONT_SIZE_OPTIONS.map(size => (
            <CheckBox
              key={size}
              marginRight={8}
              check={fontSize == size}
              label={String(size)}
              onChange={() => { updateSetting({ 'theme.lyricPreviewFontSize': size }) }}
              need
            />
          ))
        }
      </View>
    </SubTitle>
  )
})

const styles = StyleSheet.create({
  colorRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: scaleSizeW(10),
    marginBottom: scaleSizeW(12),
  },
  colorDotWrap: {
    width: scaleSizeW(32),
    height: scaleSizeW(32),
    borderRadius: scaleSizeW(16),
    borderWidth: 2,
    alignItems: 'center',
    justifyContent: 'center',
  },
  colorDot: {
    width: scaleSizeW(22),
    height: scaleSizeW(22),
    borderRadius: scaleSizeW(11),
  },
  subTitle: {
    marginBottom: scaleSizeW(6),
  },
  sizeRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
  },
})
