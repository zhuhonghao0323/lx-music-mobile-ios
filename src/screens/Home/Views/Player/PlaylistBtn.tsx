import { memo } from 'react'
import Btn from '@/screens/PlayDetail/Vertical/Player/components/MoreBtn/Btn'

/** 播放页操作行的「当前播放列表」按钮：复用 Btn，保证与其它按钮完全一致 */
export default memo(({ onPress }: { onPress: () => void }) => {
  return <Btn icon="menu" onPress={onPress} />
})
