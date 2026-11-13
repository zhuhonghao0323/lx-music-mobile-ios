import { forwardRef, useCallback, useImperativeHandle, useMemo, useRef, useState } from 'react'
import { View, TouchableOpacity, Animated, Modal, PanResponder, StyleSheet, Dimensions, Easing } from 'react-native'
import Text from '@/components/common/Text'
import { useI18n } from '@/lang'
import { useTheme } from '@/store/theme/hook'
import { usePlayMusicInfo, usePlayerMusicInfo } from '@/store/player/hook'
import { createStyle } from '@/utils/tools'
import { scaleSizeW } from '@/utils/pixelRatio'
import { haptic } from '@/utils/haptics'
import CommentHot from '@/screens/Comment/CommentHot'
import CommentNew from '@/screens/Comment/CommentNew'
import { isCommentSupported } from '@/screens/Comment/utils'

export interface CommentSheetType {
  show: () => void
  hide: () => void
}

type TabId = 'hot' | 'new'

const SCREEN_HEIGHT = Dimensions.get('window').height
/** 半屏高度：一进来先露出一小块 */
const HALF_HEIGHT = Math.round(SCREEN_HEIGHT * 0.45)
/** 展开后几乎铺满全屏 */
const FULL_HEIGHT = Math.round(SCREEN_HEIGHT * 0.92)

/**
 * 播放页「评论」抽屉（分段式）。
 *
 * 交互：
 * - 点击评论按钮 → 先弹出半屏（45%），能看到一部分评论
 * - 向上拖动 / 点击顶部手柄 → 展开到 92%，几乎铺满全屏，可正常滚动看全部评论
 * - 向下拖动 / 点击手柄 → 收回半屏，再往下拖则关闭
 */
export default forwardRef<CommentSheetType, { onHide?: () => void }>(({ onHide }, ref) => {
  const t = useI18n()
  const theme = useTheme()
  const musicInfo = usePlayerMusicInfo()
  const playMusicInfo = usePlayMusicInfo()
  const [visible, setVisible] = useState(false)
  const [tab, setTab] = useState<TabId>('hot')
  const [expanded, setExpanded] = useState(false)

  // 当前高度实时值（供手势跟手）
  const heightAnim = useRef(new Animated.Value(HALF_HEIGHT)).current
  const expandedRef = useRef(false)
  const startHeightRef = useRef(HALF_HEIGHT)

  useImperativeHandle(ref, () => ({
    show() {
      expandedRef.current = false
      setExpanded(false)
      heightAnim.setValue(HALF_HEIGHT)
      setVisible(true)
    },
    hide() {
      setVisible(false)
      onHide?.()
    },
  }))

  const animateTo = useCallback((to: number) => {
    Animated.timing(heightAnim, {
      toValue: to,
      duration: 220,
      easing: Easing.out(Easing.cubic),
      useNativeDriver: false,
    }).start()
  }, [heightAnim])

  const toggleExpand = useCallback(() => {
    haptic.tap()
    const next = !expandedRef.current
    expandedRef.current = next
    setExpanded(next)
    animateTo(next ? FULL_HEIGHT : HALF_HEIGHT)
  }, [animateTo])

  const close = useCallback(() => {
    setVisible(false)
    onHide?.()
  }, [onHide])

  // 顶部手柄拖拽：上下拖动切换档位
  const dragResponder = useMemo(() => PanResponder.create({
    onStartShouldSetPanResponder: () => true,
    onMoveShouldSetPanResponder: (_e, gs) => Math.abs(gs.dy) > 6,
    onPanResponderGrant: () => {
      startHeightRef.current = expandedRef.current ? FULL_HEIGHT : HALF_HEIGHT
    },
    onPanResponderMove: (_e, gs) => {
      const next = Math.max(120, Math.min(FULL_HEIGHT, startHeightRef.current - gs.dy))
      heightAnim.setValue(next)
    },
    onPanResponderRelease: (_e, gs) => {
      const current = Math.max(120, Math.min(FULL_HEIGHT, startHeightRef.current - gs.dy))
      // 拖得很低 → 关闭
      if (current < HALF_HEIGHT * 0.55 && gs.vy > 0.3) {
        close()
        return
      }
      // 越过中间线 → 展开，否则收回半屏
      const midpoint = (HALF_HEIGHT + FULL_HEIGHT) / 2
      const next = current > midpoint
      if (next == expandedRef.current) {
        animateTo(next ? FULL_HEIGHT : HALF_HEIGHT)
      } else {
        expandedRef.current = next
        setExpanded(next)
        animateTo(next ? FULL_HEIGHT : HALF_HEIGHT)
      }
    },
    onPanResponderTerminate: () => {
      animateTo(expandedRef.current ? FULL_HEIGHT : HALF_HEIGHT)
    },
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }), [animateTo, close, heightAnim])

  const handleTab = useCallback((id: TabId) => {
    haptic.tap()
    setTab(id)
  }, [])

  // 是否支持评论：用运行时探测 SDK，而不是 source 白名单
  const rawMusicInfo = playMusicInfo.musicInfo as unknown as LX.Music.MusicInfoOnline | undefined
  const onlineMusicInfo = isCommentSupported(rawMusicInfo?.source) ? rawMusicInfo : null

  if (!visible) return null

  return (
    <Modal transparent animationType="fade" visible onRequestClose={close} statusBarTranslucent>
      <View style={styles.backdrop}>
        <TouchableOpacity style={styles.backdropTouch} activeOpacity={1} onPress={close} />
        <Animated.View style={[styles.sheet, { height: heightAnim, backgroundColor: theme['c-content-background'] }]}>
          {/* 拖拽手柄 */}
          <View style={styles.handleWrap} {...dragResponder.panHandlers}>
            <TouchableOpacity style={styles.handleTouch} activeOpacity={0.7} onPress={toggleExpand}>
              <View style={[styles.handle, { backgroundColor: theme['c-font-label'] }]} />
            </TouchableOpacity>
          </View>

          {/* 标题 + 关闭 */}
          <View style={styles.header}>
            <Text size={15} color={theme['c-font']} numberOfLines={1} style={styles.title}>
              {t('comment_title', { name: musicInfo.name })}
            </Text>
            <TouchableOpacity style={styles.closeBtn} onPress={close} hitSlop={{ top: 8, bottom: 8, left: 8, right: 8 }}>
              <Text size={13} color={theme['c-font-label']}>{t('close')}</Text>
            </TouchableOpacity>
          </View>

          {/* 热门 / 最新 */}
          <View style={styles.tabBar}>
            {(['hot', 'new'] as TabId[]).map(id => (
              <TouchableOpacity key={id} style={styles.tabBtn} onPress={() => { handleTab(id) }}>
                <Text
                  size={14}
                  color={tab == id ? theme['c-primary-font'] : theme['c-font-label']}
                >{t(id == 'hot' ? 'comment_tab_hot' : 'comment_tab_new', { total: '' })}</Text>
              </TouchableOpacity>
            ))}
            <View style={styles.tabSpacer} />
            <TouchableOpacity style={styles.expandHint} onPress={toggleExpand} activeOpacity={0.7}>
              <Text size={12} color={theme['c-font-label']}>{expanded ? t('comment_collapse') : t('comment_expand')}</Text>
            </TouchableOpacity>
          </View>

          {/* 评论列表：靠 flex 撑满，展开后可完整滚动 */}
          <View style={styles.content}>
            {onlineMusicInfo
              ? (tab == 'hot'
                  ? <CommentHot key={`hot_${onlineMusicInfo.id}`} musicInfo={onlineMusicInfo} onUpdateTotal={() => {}} />
                  : <CommentNew key={`new_${onlineMusicInfo.id}`} musicInfo={onlineMusicInfo} onUpdateTotal={() => {}} />)
              : (
                  <View style={styles.empty}>
                    <Text size={13} color={theme['c-font-label']}>{t('comment_not support')}</Text>
                  </View>
                )}
          </View>
        </Animated.View>
      </View>
    </Modal>
  )
})

const styles = createStyle({
  backdrop: {
    flex: 1,
    justifyContent: 'flex-end',
    backgroundColor: 'rgba(0,0,0,0.42)',
  },
  backdropTouch: {
    ...StyleSheet.absoluteFillObject,
  },
  sheet: {
    width: '100%',
    borderTopLeftRadius: 20,
    borderTopRightRadius: 20,
    overflow: 'hidden',
  },
  handleWrap: {
    alignItems: 'center',
    paddingTop: scaleSizeW(8),
    paddingBottom: scaleSizeW(4),
  },
  handleTouch: {
    paddingHorizontal: scaleSizeW(30),
    paddingVertical: scaleSizeW(4),
  },
  handle: {
    width: scaleSizeW(40),
    height: 4,
    borderRadius: 2,
    opacity: 0.35,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: scaleSizeW(16),
    paddingBottom: scaleSizeW(4),
  },
  title: {
    flex: 1,
    fontWeight: '600',
  },
  closeBtn: {
    paddingLeft: scaleSizeW(10),
  },
  tabBar: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: scaleSizeW(10),
    paddingBottom: scaleSizeW(4),
  },
  tabBtn: {
    paddingHorizontal: scaleSizeW(12),
    paddingVertical: scaleSizeW(6),
  },
  tabSpacer: {
    flex: 1,
  },
  expandHint: {
    paddingHorizontal: scaleSizeW(12),
    paddingVertical: scaleSizeW(6),
  },
  content: {
    flex: 1,
  },
  empty: {
    alignItems: 'center',
    paddingTop: scaleSizeW(40),
  },
})
