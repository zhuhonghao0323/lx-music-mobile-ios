import { StyleSheet, TouchableOpacity } from 'react-native'

import { usePlayerMusicInfo } from '@/store/player/hook'
import { scaleSizeW } from '@/utils/pixelRatio'

import playerState from '@/store/player/state'
import { LIST_IDS, NAV_SHEAR_NATIVE_IDS } from '@/config/constant'
import Image from '@/components/common/Image'
import { useCallback } from 'react'
import { setLoadErrorPicUrl, setMusicInfo } from '@/core/player/playInfo'
import { setNavActiveId } from '@/core/common'

// 封面尺寸加大，配合更高的胶囊（64 高），圆角更大更接近波点
const PIC_HEIGHT = scaleSizeW(50)

const styles = StyleSheet.create({
  image: {
    width: PIC_HEIGHT,
    height: PIC_HEIGHT,
    borderRadius: scaleSizeW(14),
  },
})

export default ({ isHome }: { isHome: boolean }) => {
  const musicInfo = usePlayerMusicInfo()
  const handlePress = () => {
    if (!musicInfo.id) return
    // 布局重构后播放页是底部 Tab 之一，不再 push 独立的全屏播放页。
    // 直接切到「正在播放」Tab，与点击中间导航按钮行为一致。
    setNavActiveId('nav_player')

    // toast(global.i18n.t('play_detail_todo_tip'), 'long')
  }

  const handleLongPress = () => {
    if (!isHome) return
    const listId = playerState.playMusicInfo.listId
    if (!listId || listId == LIST_IDS.DOWNLOAD) return
    global.app_event.jumpListPosition()
  }

  const handleError = useCallback((url: string | number) => {
    setLoadErrorPicUrl(url as string)
    setMusicInfo({
      pic: null,
    })
  }, [])

  return (
    <TouchableOpacity onLongPress={handleLongPress} onPress={handlePress} activeOpacity={0.7} >
      <Image url={musicInfo.pic} nativeID={NAV_SHEAR_NATIVE_IDS.playDetail_pic} style={styles.image} onError={handleError} />
    </TouchableOpacity>
  )
}


// const styles = StyleSheet.create({
//   playInfoImg: {

//   },
// })
