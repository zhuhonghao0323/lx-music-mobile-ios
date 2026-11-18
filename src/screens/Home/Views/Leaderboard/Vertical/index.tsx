import { useEffect, useRef } from 'react'
import { View } from 'react-native'
import { createStyle } from '@/utils/tools'

import MusicList, { type MusicListType } from '../MusicList'
import { getLeaderboardSetting, saveLeaderboardSetting } from '@/utils/data'
import DrawerLayoutFixed, { type DrawerLayoutFixedType } from '@/components/common/DrawerLayoutFixed'
import HeaderBar, { type HeaderBarType, type HeaderBarProps } from './HeaderBar'
import { scaleSizeW } from '@/utils/pixelRatio'
import { useTheme } from '@/store/theme/hook'
// import { BorderWidths } from '@/theme'
// import { useTheme } from '@/store/theme/hook'
import BoardsList, { type BoardsListType, type BoardsListProps } from '../BoardsList'
import type { InitState as CommonState } from '@/store/common/state'
import settingState from '@/store/setting/state'
import { getBoardsList } from '@/core/leaderboard'
import { COMPONENT_IDS } from '@/config/constant'
import { handleCollect, handlePlay } from '../listAction'
import boardState, { type BoardItem } from '@/store/leaderboard/state'


const MAX_WIDTH = scaleSizeW(200)

export default () => {
  const drawer = useRef<DrawerLayoutFixedType>(null)
  const theme = useTheme()
  const musicListRef = useRef<MusicListType>(null)
  const isUnmountedRef = useRef(false)
  const boardsListRef = useRef<BoardsListType>(null)
  const headerBarRef = useRef<HeaderBarType>(null)
  const boundInfo = useRef<{ source: LX.OnlineSource, id: string | null }>({ source: 'kw', id: null })
  // const [width, setWidth] = useState(0)

  const handleBoundChange = (source: LX.OnlineSource, id: string) => {
    musicListRef.current?.loadList(source, id)
    void saveLeaderboardSetting({
      source,
      boardId: id,
    })
  }
  const syncBoardsList = (source: LX.OnlineSource, id: string | null) => {
    if (!id) return
    void getBoardsList(source).then(list => {
      if (!list.length) return
      requestAnimationFrame(() => {
        boardsListRef.current?.setList(list, id)
      })
    })
  }
  const resolveBoardId = (list: BoardItem[], boardId: string | null) => {
    if (!list.length) return null
    return list.some((item: { id: string }) => item.id == boardId) ? boardId : list[0].id
  }
  const onBoundChange: BoardsListProps['onBoundChange'] = (id) => {
    boundInfo.current.id = id
    void getBoardsList(boundInfo.current.source).then(list => {
      requestAnimationFrame(() => {
        const bound = list.find(l => l.id == id)
        headerBarRef.current?.setBound(boundInfo.current.source, id, bound?.name ?? 'Unknown')
      })
    })
    handleBoundChange(boundInfo.current.source, id)
    requestAnimationFrame(() => {
      drawer.current?.closeDrawer()
    })
  }
  const onPlay: BoardsListProps['onPlay'] = (id) => {
    boundInfo.current.id = id
    void handlePlay(id, boardState.listDetailInfo.list)
  }
  const onCollect: BoardsListProps['onCollect'] = (id, name) => {
    boundInfo.current.id = id
    void handleCollect(id, name, boundInfo.current.source)
  }
  const onShowBound = () => {
    syncBoardsList(boundInfo.current.source, boundInfo.current.id)
    requestAnimationFrame(() => {
      drawer.current?.openDrawer()
    })
  }
  const onSourceChange: HeaderBarProps['onSourceChange'] = (source) => {
    boundInfo.current.source = source
    void getBoardsList(source).then(list => {
      const id = resolveBoardId(list, null)
      if (!id) return
      const bound = list.find(item => item.id == id)
      requestAnimationFrame(() => {
        boardsListRef.current?.setList(list, id)
        headerBarRef.current?.setBound(source, id, bound?.name ?? 'Unknown')
        requestAnimationFrame(() => {
          handleBoundChange(source, id)
        })
      })
    })
  }

  const navigationView = () => {
    return (
      <BoardsList
        ref={boardsListRef}
        onBoundChange={onBoundChange}
        onCollect={onCollect}
        onPlay={onPlay}
      />
    )
  }

  // const theme = useTheme()


  useEffect(() => {
    const handleFixDrawer = (id: CommonState['navActiveId']) => {
      if (id == 'nav_top') drawer.current?.fixWidth()
      else drawer.current?.closeDrawer()
    }
    global.state_event.on('navActiveIdUpdated', handleFixDrawer)


    isUnmountedRef.current = false
    const loadSource = (source: LX.OnlineSource, boardId?: string) => {
      boundInfo.current.source = source
      void getBoardsList(source).then(list => {
        if (isUnmountedRef.current) return
        const resolvedId = resolveBoardId(list, boardId ?? '')
        if (!resolvedId) return
        boundInfo.current.id = resolvedId
        const bound = list.find(l => l.id == resolvedId)
        boardsListRef.current?.setList(list, resolvedId)
        headerBarRef.current?.setBound(source, resolvedId, bound?.name ?? 'Unknown')
        musicListRef.current?.loadList(source, resolvedId)
      })
    }
    void getLeaderboardSetting().then(({ source, boardId }) => {
      loadSource(source, boardId)
    })

    // 首页音乐图标切换音源后，排行榜同步重载（boardId 交由 resolveBoardId 自动取第一个）
    const handleSourceChanged = (source: LX.OnlineSource) => { loadSource(source) }
    global.app_event.on('leaderboardSourceChanged', handleSourceChanged)

    return () => {
      global.state_event.off('navActiveIdUpdated', handleFixDrawer)
      global.app_event.off('leaderboardSourceChanged', handleSourceChanged)
      isUnmountedRef.current = true
    }
  }, [])


  return (
    <DrawerLayoutFixed
      ref={drawer}
      visibleNavNames={[COMPONENT_IDS.home]}
      // drawerWidth={width}
      widthPercentage={0.82}
      widthPercentageMax={MAX_WIDTH}
      drawerPosition={settingState.setting['common.drawerLayoutPosition']}
      renderNavigationView={navigationView}
      drawerBackgroundColor={theme['c-content-background']}
      style={{ elevation: 1 }}
    >
      <View style={styles.container}>
        <HeaderBar ref={headerBarRef} onShowBound={onShowBound} onSourceChange={onSourceChange} />
        <MusicList ref={musicListRef} />
      </View>
    </DrawerLayoutFixed>
    // <View style={styles.container}>
    //   <LeftBar
    //     ref={leftBarRef}
    //     onChangeList={handleChangeBound}
    //   />
    //   <MusicList
    //     ref={musicListRef}
    //   />
    // </View>
  )
}

const styles = createStyle({
  container: {
    width: '100%',
    flex: 1,
    flexDirection: 'column',
    overflow: 'hidden',
    // borderTopWidth: BorderWidths.normal,
  },
  // content: {
  //   flex: 1,
  // },
})
