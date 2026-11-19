import { useEffect, useRef, useState } from 'react'
import { usePlayerMusicInfo } from '@/store/player/hook'
import { getMusicPicUrl } from '@/utils/musicCover'
import { getAverageColor } from '@/utils/imageColor'

/**
 * 播放器动态背景数据：
 * - coverUrl：当前歌曲封面（meta.picUrl）
 * - accentColor：封面平均色（进程级缓存，异步获取，未就绪为 null）
 *
 * 切歌时自动更新；主色用于玻璃层 tint 注入与背景遮罩，
 * 让玻璃、背景、封面形成自然的色彩关系。
 */
export const usePlayerDynamicBg = () => {
  const musicInfo = usePlayerMusicInfo()
  const coverUrl = getMusicPicUrl(musicInfo)
  const [accentColor, setAccentColor] = useState<string | null>(null)
  const requestedRef = useRef<string | null>(null)

  useEffect(() => {
    if (!coverUrl) {
      setAccentColor(null)
      requestedRef.current = null
      return
    }
    if (requestedRef.current == coverUrl) return
    requestedRef.current = coverUrl
    setAccentColor(null)
    void getAverageColor(coverUrl).then(color => {
      if (requestedRef.current == coverUrl) setAccentColor(color)
    })
  }, [coverUrl])

  return { coverUrl, accentColor }
}
