import { memo, useCallback, useMemo } from 'react'
import { View, TouchableOpacity, FlatList, Dimensions, type ListRenderItem } from 'react-native'
import { useTheme } from '@/store/theme/hook'
import { useMyList } from '@/store/list/hook'
import Text from '@/components/common/Text'
import Image from '@/components/common/Image'
import { Icon } from '@/components/common/Icon'
import { createStyle } from '@/utils/tools'
import { scaleSizeW } from '@/utils/pixelRatio'
import { haptic } from '@/utils/haptics'
import { useListCover } from '../Mylist/useListCover'
import { useIsGlass } from '@/theme/glass'

/** 单个歌单图标（封面网格单元） */
const ListTile = memo(({ listInfo, size, onPress, onLongPress }: {
  listInfo: LX.List.MyListInfo
  size: number
  onPress: (info: LX.List.MyListInfo) => void
  onLongPress?: (info: LX.List.MyListInfo) => void
}) => {
  const theme = useTheme()
  const isGlass = useIsGlass()
  // 歌单封面 = 列表内第一首歌封面（进程级缓存）
  const cover = useListCover(listInfo.id)

  return (
    <TouchableOpacity
      style={[styles.tile, { width: size }]}
      activeOpacity={0.75}
      onPress={() => { haptic.tap(); onPress(listInfo) }}
      onLongPress={onLongPress ? () => { haptic.longPress(); onLongPress(listInfo) } : undefined}
    >
      <View style={[styles.tileCoverWrap, { width: size, height: size }]}>
        <Image
          url={cover}
          style={[styles.tileCover, {
            backgroundColor: isGlass ? 'rgba(255,255,255,0.08)' : theme['c-primary-light-500-alpha-800'],
          }]}
        />
        {/* 收藏/默认列表加一个小角标，便于区分 */}
        {listInfo.id == 'love'
          ? (
              <View style={[styles.badge, { backgroundColor: theme['c-primary-font'] }]}>
                <Icon name="love" size={9} color={theme['c-main-background']} />
              </View>
            )
          : null}
      </View>
      <Text style={styles.tileName} size={12} color={theme['c-font']} numberOfLines={2}>{listInfo.name}</Text>
    </TouchableOpacity>
  )
})

/**
 * 「我的」页的歌单图标网格。
 *
 * 按图标网格直接展示全部列表（试听列表 / 我的收藏 / 自建歌单），
 * 点图标进入该列表的歌曲页（复用现有 MusicList 的全部能力：
 * 播放、添加到播放列表、多选、排序等）。
 */
export default memo(({ onSelectList, onLongPressList }: {
  onSelectList: (info: LX.List.MyListInfo) => void
  onLongPressList?: (info: LX.List.MyListInfo) => void
}) => {
  const theme = useTheme()
  const allList = useMyList()

  // 每行 3 列，左右留白后均分
  const columns = 3
  const tileSize = useMemo(() => {
    const { width } = Dimensions.get('window')
    return Math.floor((width - scaleSizeW(16) * 2 - scaleSizeW(10) * (columns - 1)) / columns)
  }, [])

  const renderItem: ListRenderItem<LX.List.MyListInfo> = useCallback(({ item }) => (
    <ListTile
      listInfo={item}
      size={tileSize}
      onPress={onSelectList}
      onLongPress={onLongPressList}
    />
  ), [tileSize, onSelectList, onLongPressList])

  return (
    <FlatList
      data={allList}
      renderItem={renderItem}
      keyExtractor={item => item.id}
      numColumns={columns}
      style={styles.grid}
      contentContainerStyle={styles.gridContent}
      columnWrapperStyle={styles.gridRow}
      showsVerticalScrollIndicator={false}
      // 列表项数量通常很少，全量渲染即可
      initialNumToRender={12}
      ListEmptyComponent={
        <View style={styles.empty}>
          <Icon name="album" size={34} color={theme['c-font-label']} />
        </View>
      }
    />
  )
})

const styles = createStyle({
  grid: {
    flex: 1,
  },
  gridContent: {
    paddingHorizontal: scaleSizeW(16),
    paddingTop: scaleSizeW(6),
    paddingBottom: scaleSizeW(12),
  },
  gridRow: {
    justifyContent: 'flex-start',
    gap: scaleSizeW(10),
    marginBottom: scaleSizeW(14),
  },
  tile: {
    alignItems: 'flex-start',
  },
  tileCoverWrap: {
    borderRadius: scaleSizeW(14),
    overflow: 'hidden',
  },
  tileCover: {
    width: '100%',
    height: '100%',
  },
  badge: {
    position: 'absolute',
    right: scaleSizeW(5),
    bottom: scaleSizeW(5),
    width: scaleSizeW(17),
    height: scaleSizeW(17),
    borderRadius: scaleSizeW(9),
    alignItems: 'center',
    justifyContent: 'center',
  },
  tileName: {
    marginTop: scaleSizeW(6),
    lineHeight: scaleSizeW(16),
  },
  empty: {
    alignItems: 'center',
    paddingTop: scaleSizeW(40),
  },
})
