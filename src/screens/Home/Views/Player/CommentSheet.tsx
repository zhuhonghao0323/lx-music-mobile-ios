import { forwardRef, useCallback, useImperativeHandle, useRef, useState } from 'react'
import { View, TouchableOpacity } from 'react-native'
import Popup, { type PopupType } from '@/components/common/Popup'
import Text from '@/components/common/Text'
import { useI18n } from '@/lang'
import { useTheme } from '@/store/theme/hook'
import { usePlayerMusicInfo } from '@/store/player/hook'
import { createStyle } from '@/utils/tools'
import { scaleSizeW } from '@/utils/pixelRatio'
import { haptic } from '@/utils/haptics'
import CommentHot from '@/screens/Comment/CommentHot'
import CommentNew from '@/screens/Comment/CommentNew'

export interface CommentSheetType {
  show: () => void
  hide: () => void
}

type TabId = 'hot' | 'new'

/** 支持评论的在线源（与 LX.OnlineSource 一致；local/download 等无评论接口） */
const ONLINE_SOURCES: LX.OnlineSource[] = ['kw', 'kg', 'tx', 'wy', 'mg']

/**
 * 播放页「评论」底部抽屉。
 *
 * 之前点评论没反应，是因为旧按钮 push 到评论页时用的是
 * componentIds.playDetail，而新版播放页是 Home 的 Tab，该 id 不存在。
 * 这里改为底部抽屉，直接复用评论列表组件。
 */
export default forwardRef<CommentSheetType, { onHide?: () => void }>(({ onHide }, ref) => {
  const t = useI18n()
  const theme = useTheme()
  const musicInfo = usePlayerMusicInfo()
  const popupRef = useRef<PopupType>(null)
  const [tab, setTab] = useState<TabId>('hot')

  useImperativeHandle(ref, () => ({
    show() {
      popupRef.current?.setVisible(true)
    },
    hide() {
      popupRef.current?.setVisible(false)
    },
  }))

  const handleTab = useCallback((id: TabId) => {
    haptic.tap()
    setTab(id)
  }, [])

  // 评论只支持在线源。
  // 注意不能只判断 musicInfo.id：本地歌曲也有 id，但其 source 为 'local'，
  // music['local'] 不存在，取 .comment 时会抛
  // "Cannot read property 'comment' of undefined" 直接崩溃。
  const source = musicInfo.id ? (musicInfo as unknown as LX.Music.MusicInfoOnline).source : null
  const onlineMusicInfo = source && ONLINE_SOURCES.includes(source)
    ? (musicInfo as unknown as LX.Music.MusicInfoOnline)
    : null

  return (
    <Popup ref={popupRef} title={t('comment_title', { name: musicInfo.name })} closeBtn position="bottom" onHide={onHide} plain>
      <View style={styles.container}>
        <View style={styles.tabBar}>
          {(['hot', 'new'] as TabId[]).map(id => (
            <TouchableOpacity key={id} style={styles.tabBtn} onPress={() => { handleTab(id) }}>
              <Text
                size={14}
                color={tab == id ? theme['c-primary-font'] : theme['c-font-label']}
              >{t(id == 'hot' ? 'comment_tab_hot' : 'comment_tab_new', { total: '' })}</Text>
            </TouchableOpacity>
          ))}
        </View>
        <View style={styles.content}>
          {onlineMusicInfo
            ? (tab == 'hot'
                ? <CommentHot musicInfo={onlineMusicInfo} onUpdateTotal={() => {}} />
                : <CommentNew musicInfo={onlineMusicInfo} onUpdateTotal={() => {}} />)
            : (
                <View style={styles.empty}>
                  <Text size={13} color={theme['c-font-label']}>{t('comment_not support')}</Text>
                </View>
              )}
        </View>
      </View>
    </Popup>
  )
})

const styles = createStyle({
  container: {
    flex: 1,
    minHeight: scaleSizeW(320),
  },
  tabBar: {
    flexDirection: 'row',
    paddingHorizontal: scaleSizeW(10),
    paddingBottom: scaleSizeW(6),
  },
  tabBtn: {
    paddingHorizontal: scaleSizeW(12),
    paddingVertical: scaleSizeW(6),
  },
  content: {
    flex: 1,
    minHeight: scaleSizeW(280),
  },
  empty: {
    alignItems: 'center',
    paddingTop: scaleSizeW(40),
  },
})
