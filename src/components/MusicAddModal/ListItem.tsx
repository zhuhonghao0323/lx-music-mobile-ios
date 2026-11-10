import { View, TouchableOpacity } from 'react-native'
import Button from '@/components/common/Button'
import Text from '@/components/common/Text'
import { BorderWidths } from '@/theme'
import { createStyle, toast } from '@/utils/tools'
import { useTheme } from '@/store/theme/hook'
import { useMusicExistsList } from '@/store/list/hook'
import { Icon } from '@/components/common/Icon'
import { FAVORITE_COLOR } from '@/screens/PlayDetail/components/FavoriteIcon'

export default ({ listInfo, onPress, musicInfo, width, isFavorited, onRemove }: {
  listInfo: LX.List.MyListInfo
  onPress: (listInfo: LX.List.MyListInfo) => void
  musicInfo: LX.Music.MusicInfo
  width: number
  /** 这首歌曲当前是否已经在这个列表里（由收藏逻辑按 歌名+演唱者 判定后传入） */
  isFavorited?: boolean
  /** 从这个列表里取消收藏 */
  onRemove?: (listId: string) => void
}) => {
  const theme = useTheme()
  const isExistsInList = useMusicExistsList(listInfo, musicInfo)
  const isExists = !!isFavorited || isExistsInList

  const handlePress = () => {
    if (isExists) {
      toast(global.i18n.t('list_add_tip_exists'))
      return
    }
    onPress(listInfo)
  }

  return (
    <View style={{ ...styles.listItem, width }}>
      <Button
        style={{
          ...styles.button,
          backgroundColor: theme['c-button-background'],
          borderColor: isExists ? FAVORITE_COLOR : theme['c-primary-light-400-alpha-300'],
          borderWidth: isExists ? 1 : BorderWidths.normal1,
        }}
        onPress={handlePress}
      >
        <View style={styles.inner}>
          {isExists ? <Icon name="love" size={11} color={FAVORITE_COLOR} style={styles.icon} /> : null}
          <Text numberOfLines={1} size={14} color={theme['c-button-font']} style={styles.label}>{listInfo.name}</Text>
          {isExists && onRemove
            ? (
                <TouchableOpacity
                  style={styles.removeBtn}
                  hitSlop={{ top: 10, bottom: 10, left: 6, right: 10 }}
                  onPress={() => { onRemove(listInfo.id) }}
                >
                  <Icon name="close" size={10} color={FAVORITE_COLOR} />
                </TouchableOpacity>
              )
            : null}
        </View>
      </Button>
    </View>
  )
}

export const styles = createStyle({
  listItem: {
    // width: '50%',
    paddingRight: 13,
    // backgroundColor: 'rgba(0,0,0,0.2)',
  },
  button: {
    height: 36,
    paddingLeft: 10,
    paddingRight: 10,
    marginRight: 10,
    marginBottom: 10,
    borderRadius: 4,
    width: '100%',
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: BorderWidths.normal1,
  },
  inner: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    width: '100%',
  },
  icon: {
    marginRight: 4,
  },
  label: {
    flexShrink: 1,
  },
  removeBtn: {
    marginLeft: 4,
    paddingLeft: 2,
  },
})
