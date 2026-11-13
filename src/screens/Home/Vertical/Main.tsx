import { useCallback, useEffect, useMemo, useRef, useState, type ComponentRef } from 'react'
import { View, Animated, Easing } from 'react-native'
import Search from '../Views/Search'
import SongList from '../Views/SongList'
import Mylist from '../Views/Mylist'
import Leaderboard from '../Views/Leaderboard'
import Setting from '../Views/Setting'
import HomeView from '../Views/Home'
import PlayerView from '../Views/Player'
import MineView from '../Views/Mine'
import commonState, { type InitState as CommonState } from '@/store/common/state'
import { createStyle } from '@/utils/tools'
import PagerView, { type PageScrollStateChangedNativeEvent, type PagerViewOnPageSelectedEvent } from 'react-native-pager-view'
import { setNavActiveId } from '@/core/common'

const hideKeys = [
  'list.isShowAlbumName',
  'list.isShowInterval',
  'theme.fontShadow',
] as Readonly<Array<keyof LX.AppSetting>>

/**
 * 页面骨架：首次进入时才挂载，之后保持挂载（避免切 Tab 丢滚动位置）。
 * 二级页额外支持「从设置页返回时重新可见」的刷新逻辑。
 *
 * 入场动画只在「首次挂载」时播放一次。
 * 注意：不要在每次 navActiveId 变化时重放动画 —— PagerView 左右滑动本身
 * 已有过渡，重放会让被滑入的页面突然淡入+上浮一次，表现为页面抖动。
 */
const makePage = (PageComponent: React.ComponentType, navId: CommonState['navActiveId'], reloadOnSettingBack = false) => {
  return () => {
    const [visible, setVisible] = useState(commonState.navActiveId == navId)
    const component = useMemo(() => <PageComponent />, [])
    const enter = useRef(new Animated.Value(visible ? 1 : 0)).current
    const translateY = useRef(new Animated.Value(visible ? 0 : 8)).current
    // 是否已经播过入场动画（仅首帧播一次，之后不再重放）
    const enteredRef = useRef(visible)

    if (!enteredRef.current && visible) {
      // 从「隐藏」首次变为可见时才播放入场
      enteredRef.current = true
      enter.setValue(0)
      translateY.setValue(8)
      Animated.parallel([
        Animated.timing(enter, { toValue: 1, duration: 200, useNativeDriver: true }),
        Animated.timing(translateY, { toValue: 0, duration: 220, easing: Easing.out(Easing.cubic), useNativeDriver: true }),
      ]).start()
    }

    useEffect(() => {
      let currentId: CommonState['navActiveId'] = commonState.navActiveId
      const handleNavIdUpdate = (id: CommonState['navActiveId']) => {
        currentId = id
        if (id == navId) {
          // 只负责挂载，不重放动画（避免左右滑动时页面抖动）
          setVisible(true)
        }
      }
      const handleHide = () => {
        if (reloadOnSettingBack) {
          if (currentId != 'nav_setting') return
        }
        setVisible(false)
      }
      const handleConfigUpdated = (keys: Array<keyof LX.AppSetting>) => {
        if (keys.some(k => hideKeys.includes(k))) handleHide()
      }
      global.state_event.on('navActiveIdUpdated', handleNavIdUpdate)
      global.state_event.on('themeUpdated', handleHide)
      global.state_event.on('languageChanged', handleHide)
      global.state_event.on('configUpdated', handleConfigUpdated)

      return () => {
        global.state_event.off('navActiveIdUpdated', handleNavIdUpdate)
        global.state_event.off('themeUpdated', handleHide)
        global.state_event.off('languageChanged', handleHide)
        global.state_event.off('configUpdated', handleConfigUpdated)
      }
    // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [])

    if (!visible) return null
    return (
      <Animated.View style={{ flex: 1, opacity: enter, transform: [{ translateY }] }}>
        {component}
      </Animated.View>
    )
  }
}

const HomePage = makePage(HomeView, 'nav_home')
const PlayerPage = makePage(PlayerView, 'nav_player')
const MinePage = makePage(MineView, 'nav_mine')
const SearchPage = makePage(Search, 'nav_search', true)
const SongListPage = makePage(SongList, 'nav_songlist', true)
const LeaderboardPage = makePage(Leaderboard, 'nav_top', true)
const MylistPage = makePage(Mylist, 'nav_love', true)
const SettingPage = makePage(Setting, 'nav_setting')

/**
 * 页面顺序：前三个是底部 Tab（固定），后面是二级页。
 * 二级页通过 setNavActiveId 切换过来，不走底部导航。
 */
const indexMap = [
  'nav_home',
  'nav_player',
  'nav_mine',
  'nav_search',
  'nav_songlist',
  'nav_top',
  'nav_love',
  'nav_setting',
] as const

const viewMap: Record<CommonState['navActiveId'], number> = {
  nav_home: 0,
  nav_player: 1,
  nav_mine: 2,
  nav_search: 3,
  nav_songlist: 4,
  nav_top: 5,
  nav_love: 6,
  nav_setting: 7,
}

/** 播放页与歌词页不作为底部 Tab 展示，横滑由各自内部手势处理 */

const Main = () => {
  const pagerViewRef = useRef<ComponentRef<typeof PagerView>>(null)
  const activeIndexRef = useRef(viewMap[commonState.navActiveId])

  const onPageSelected = useCallback(({ nativeEvent }: PagerViewOnPageSelectedEvent) => {
    activeIndexRef.current = nativeEvent.position
    if (activeIndexRef.current != viewMap[commonState.navActiveId]) {
      setNavActiveId(indexMap[activeIndexRef.current] ?? 'nav_home')
    }
  }, [])

  const onPageScrollStateChanged = useCallback(({ nativeEvent }: PageScrollStateChangedNativeEvent) => {
    const idle = nativeEvent.pageScrollState == 'idle'
    if (global.lx.homePagerIdle != idle) global.lx.homePagerIdle = idle
  }, [])

  useEffect(() => {
    const handleUpdate = (id: CommonState['navActiveId']) => {
      const index = viewMap[id]
      if (index == null) return
      if (activeIndexRef.current == index) return
      activeIndexRef.current = index
      pagerViewRef.current?.setPageWithoutAnimation(index)
    }
    global.state_event.on('navActiveIdUpdated', handleUpdate)
    return () => {
      global.state_event.off('navActiveIdUpdated', handleUpdate)
    }
  }, [])

  // 横滑策略：主页 ↔ 播放页之间不再允许手势切屏（按需求取消），
  // 主 PagerView 一律禁用横滑。页面切换只通过底部三大图标与代码跳转。
  // 播放页内部的「封面 ↔ 歌词」由播放页自己的 PagerView 处理，与此无关。

  const component = useMemo(() => (
    <PagerView ref={pagerViewRef}
      initialPage={activeIndexRef.current}
      offscreenPageLimit={1}
      onPageSelected={onPageSelected}
      onPageScrollStateChanged={onPageScrollStateChanged}
      scrollEnabled={false}
      style={styles.pagerView}
    >
      <View collapsable={false} key="nav_home" style={styles.pageStyle}>
        <HomePage />
      </View>
      <View collapsable={false} key="nav_player" style={styles.pageStyle}>
        <PlayerPage />
      </View>
      <View collapsable={false} key="nav_mine" style={styles.pageStyle}>
        <MinePage />
      </View>
      <View collapsable={false} key="nav_search" style={styles.pageStyle}>
        <SearchPage />
      </View>
      <View collapsable={false} key="nav_songlist" style={styles.pageStyle}>
        <SongListPage />
      </View>
      <View collapsable={false} key="nav_top" style={styles.pageStyle}>
        <LeaderboardPage />
      </View>
      <View collapsable={false} key="nav_love" style={styles.pageStyle}>
        <MylistPage />
      </View>
      <View collapsable={false} key="nav_setting" style={styles.pageStyle}>
        <SettingPage />
      </View>
    </PagerView>
  ), [onPageScrollStateChanged, onPageSelected])

  return component
}

const styles = createStyle({
  pagerView: {
    flex: 1,
    overflow: 'hidden',
  },
  pageStyle: {
    flex: 1,
    width: '100%',
    overflow: 'hidden',
  },
})


export default Main
