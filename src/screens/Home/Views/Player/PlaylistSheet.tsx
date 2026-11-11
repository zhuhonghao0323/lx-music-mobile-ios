import { forwardRef, useCallback, useImperativeHandle, useMemo, useRef, useState } from 'react'
import { View, FlatList, TouchableOpacity, type ListRenderItem } from 'react-native'
import Dialog, { type DialogType } from '@/components/common/Dialog'
import Text from '@/components/common/Text'
import { Icon } from '@/components/common/Icon'
import { useTheme } from '@/store/theme/hook'
import { useI18n } from '@/lang'
import { createStyle } from '@/utils/tools'
import { scaleSizeW } from '@/utils/pixelRatio'
import { haptic } from '@/utils/haptics'
import { getListMusicSync } from '@/utils/listManage'
import playerState from '@/store/player/state'
import { playList } from '@/core/player/player'
import { usePlayerMusicInfo } from '@/store/player/hook'

export interface PlaylistSheetType {
  show: () => void
}

/**
 * 当前播放列表（底部半屏 Sheet）。
 *
 * 对标波点播放页右下角 ☰：
 * - 显示当前播放队列，播放中条目高亮
 * - 点击条目切歌
 * - 顶部显示列表名与曲目总数
 *
 * 队列来源与播放入口都复用现有实现（getListMusicSync + playList），
 * 保证与「播放器实际状态」永远一致，不另外维护一份队列。
 */
export default forwardRef<PlaylistSheetType, {
  visible: boolean
  onHide: () => void
}>(({ onHide }, ref) => {
      const t = useI18n()
      const theme = useTheme()
      const dialogRef = useRef<DialogType>(null)
      const [refreshKey, setRefreshKey] = useState(0)

      // 当前播放队列：跟随 playerListId 取对应的列表数据
      const { list, listId, currentMusicId } = useMemo(() => {
        const pid = playerState.playInfo.playerListId
        const musics = pid ? getListMusicSync(pid) : []
        return {
          list: musics ?? [],
          listId: pid,
          currentMusicId: playerState.playMusicInfo.musicInfo?.id,
        }
        // eslint-disable-next-line react-hooks/exhaustive-deps
      }, [refreshKey, playerState.playInfo.playerListId])

      useImperativeHandle(ref, () => ({
        show() {
          // 每次打开都重新取一次队列，避免显示过期数据
          setRefreshKey(k => k + 1)
          dialogRef.current?.setVisible(true)
        },
      }))

      const handlePlay = useCallback((index: number) => {
        if (!listId) return
        haptic.tap()
        void playList(listId, index)
        dialogRef.current?.setVisible(false)
      }, [listId])

      const renderItem: ListRenderItem<LX.Music.MusicInfo> = ({ item, index }) => {
        const active = item.id == currentMusicId
        return (
      <TouchableOpacity
        style={styles.item}
        activeOpacity={0.7}
        onPress={() => { handlePlay(index) }}
      >
        {active ? <Icon name="play" size={10} color={theme['c-primary-font']} style={styles.playingIcon} /> : <View style={styles.iconPlaceholder} />}
        <View style={styles.itemInfo}>
          <Text
            size={14}
            color={active ? theme['c-primary-font'] : theme['c-font']}
            numberOfLines={1}
            style={active ? styles.activeText : undefined}
          >{item.name}</Text>
          <Text size={11} color={theme['c-font-label']} numberOfLines={1}>{item.singer}</Text>
        </View>
      </TouchableOpacity>
        )
      }

      return (
    <Dialog ref={dialogRef} onHide={onHide} title={`${t('play_list')} (${list.length})`} closeBtn height="62%">
      <FlatList
        data={list}
        renderItem={renderItem}
        keyExtractor={(item, index) => `${item.id}_${index}`}
        initialNumToRender={20}
        style={styles.list}
      />
    </Dialog>
      )
    })

const styles = createStyle({
  list: {
    width: '100%',
  },
  item: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: scaleSizeW(9),
    paddingHorizontal: scaleSizeW(14),
    minHeight: 48,
  },
  iconPlaceholder: {
    width: 10,
    marginRight: scaleSizeW(6),
  },
  playingIcon: {
    marginRight: scaleSizeW(6),
  },
  itemInfo: {
    flex: 1,
  },
  activeText: {
    fontWeight: '600',
  },
})

void usePlayerMusicInfo
