import { forwardRef, useCallback, useEffect, useImperativeHandle, useMemo, useRef, useState } from 'react'
import { View, FlatList, TouchableOpacity, Animated, Easing, StyleSheet, type ListRenderItem } from 'react-native'
import Dialog, { type DialogType } from '@/components/common/Dialog'
import Text from '@/components/common/Text'
import { Icon } from '@/components/common/Icon'
import Image from '@/components/common/Image'
import { useTheme } from '@/store/theme/hook'
import { useI18n } from '@/lang'
import { createStyle } from '@/utils/tools'
import { scaleSizeW } from '@/utils/pixelRatio'
import { haptic } from '@/utils/haptics'
import { getListMusicSync } from '@/utils/listManage'
import playerState from '@/store/player/state'
import { playList } from '@/core/player/player'
import { useIsGlass } from '@/theme/glass'
import { FAVORITE_COLOR } from '@/screens/PlayDetail/components/FavoriteIcon'
import { isMusicFavorited, toggleFavorite } from '@/core/favorite'

export interface PlaylistSheetType {
  show: () => void
}

const ROW_HEIGHT = scaleSizeW(58)

/**
 * 当前播放列表（底部半屏 Sheet）—— 对标波点的「播放列表」弹层。
 *
 * 视觉要点：
 * - 每行带专辑缩略图（圆角）、歌名、歌手
 * - 右侧收藏心形，可直接切换收藏
 * - 播放中的条目高亮歌名
 * - 行进入时错峰淡入，避免一次性硬刷
 */
export default forwardRef<PlaylistSheetType, {
  onHide?: () => void
}>(({ onHide }, ref) => {
      const t = useI18n()
      const theme = useTheme()
      const dialogRef = useRef<DialogType>(null)
      const [token, setToken] = useState(0)

      // 当前播放队列：始终以播放器状态为唯一真源
      const { list, listId, currentMusicId } = useMemo(() => {
        const pid = playerState.playInfo.playerListId
        return {
          list: pid ? (getListMusicSync(pid) ?? []) : [],
          listId: pid,
          currentMusicId: playerState.playMusicInfo.musicInfo?.id,
        }
        // eslint-disable-next-line react-hooks/exhaustive-deps
      }, [token, playerState.playInfo.playerListId])

      useImperativeHandle(ref, () => ({
        show() {
          setToken(v => v + 1)
          dialogRef.current?.setVisible(true)
        },
      }))

      const handlePlay = useCallback((index: number) => {
        if (!listId) return
        haptic.tap()
        void playList(listId, index)
      }, [listId])

      const renderItem: ListRenderItem<LX.Music.MusicInfo> = ({ item, index }) => (
    <PlaylistRow
      item={item}
      index={index}
      active={item.id == currentMusicId}
      onPress={() => { handlePlay(index) }}
    />
      )

      return (
    <Dialog ref={dialogRef} onHide={onHide} title={`${t('play_list')}`} closeBtn height="68%">
      <View style={styles.countRow}>
        <Text size={11} color={theme['c-font-label']}>{t('play_list_count', { count: list.length })}</Text>
      </View>
      {list.length
        ? (
            <FlatList
              data={list}
              renderItem={renderItem}
              keyExtractor={(item, index) => `${item.id}_${index}`}
              initialNumToRender={14}
              getItemLayout={(_, index) => ({ length: ROW_HEIGHT, offset: ROW_HEIGHT * index, index })}
              style={styles.list}
            />
          )
        : (
            <View style={styles.empty}>
              <Icon name="album" size={34} color={theme['c-font-label']} />
              <Text size={12} color={theme['c-font-label']} style={styles.emptyText}>{t('play_list_empty')}</Text>
            </View>
          )}
    </Dialog>
      )
    })

/** 单行：缩略图 + 歌名歌手 + 收藏心形；进入时淡入上浮 */
const PlaylistRow = ({ item, index, active, onPress }: {
  item: LX.Music.MusicInfo
  index: number
  active: boolean
  onPress: () => void
}) => {
  const theme = useTheme()
  const isGlass = useIsGlass()
  const [favorited, setFavorited] = useState(false)
  const anim = useRef(new Animated.Value(0)).current

  useEffect(() => {
    const delay = Math.min(index * 18, 220)
    Animated.timing(anim, {
      toValue: 1,
      duration: 240,
      delay,
      easing: Easing.out(Easing.cubic),
      useNativeDriver: true,
    }).start()
  }, [anim, index])

  useEffect(() => {
    let cancelled = false
    void isMusicFavorited(item).then(v => { if (!cancelled) setFavorited(v) })
    return () => { cancelled = true }
  }, [item])

  const handleFavorite = useCallback(() => {
    haptic.tap()
    void toggleFavorite(item).then(v => {
      setFavorited(v)
      if (v) haptic.favorite()
    })
  }, [item])

  const translateY = anim.interpolate({ inputRange: [0, 1], outputRange: [10, 0] })

  return (
    <Animated.View style={{ opacity: anim, transform: [{ translateY }] }}>
      <TouchableOpacity style={styles.item} activeOpacity={0.65} onPress={onPress}>
        <Image
          url={(item as { pic?: string }).pic}
          style={StyleSheet.compose(styles.thumb, {
            backgroundColor: isGlass ? 'rgba(255,255,255,0.08)' : theme['c-primary-light-500-alpha-800'],
          })}
        />
        <View style={styles.itemInfo}>
          <Text
            size={14}
            color={active ? theme['c-primary-font'] : theme['c-font']}
            numberOfLines={1}
            style={active ? styles.activeText : undefined}
          >{item.name}</Text>
          <Text size={11} color={theme['c-font-label']} numberOfLines={1} style={styles.singer}>{item.singer}</Text>
        </View>
        <TouchableOpacity
          style={styles.favBtn}
          hitSlop={{ top: 10, bottom: 10, left: 10, right: 10 }}
          onPress={handleFavorite}
        >
          <Icon
            name="love"
            size={17}
            color={favorited ? FAVORITE_COLOR : theme['c-font-label']}
          />
        </TouchableOpacity>
      </TouchableOpacity>
    </Animated.View>
  )
}

const styles = createStyle({
  countRow: {
    paddingHorizontal: scaleSizeW(16),
    paddingBottom: scaleSizeW(6),
  },
  list: {
    width: '100%',
  },
  item: {
    flexDirection: 'row',
    alignItems: 'center',
    height: ROW_HEIGHT,
    paddingHorizontal: scaleSizeW(14),
  },
  thumb: {
    width: scaleSizeW(42),
    height: scaleSizeW(42),
    borderRadius: scaleSizeW(10),
  },
  itemInfo: {
    flex: 1,
    marginLeft: scaleSizeW(11),
    marginRight: scaleSizeW(8),
  },
  singer: {
    marginTop: scaleSizeW(2),
  },
  activeText: {
    fontWeight: '600',
  },
  favBtn: {
    width: scaleSizeW(32),
    height: scaleSizeW(32),
    alignItems: 'center',
    justifyContent: 'center',
  },
  empty: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    paddingBottom: scaleSizeW(40),
  },
  emptyText: {
    marginTop: scaleSizeW(10),
  },
})
