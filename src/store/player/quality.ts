import { useEffect, useState } from 'react'

/** 当前实际播放的音质（由 setMusicUrl 成功后写入） */
let currentQuality: LX.Quality | null = null
const listeners = new Set<(q: LX.Quality | null) => void>()

export const setCurrentPlayQuality = (q: LX.Quality | null) => {
  currentQuality = q
  for (const fn of listeners) fn(q)
}

export const useCurrentPlayQuality = () => {
  const [value, setValue] = useState<LX.Quality | null>(currentQuality)
  useEffect(() => {
    listeners.add(setValue)
    return () => { listeners.delete(setValue) }
  }, [])
  return value
}

/** 把内部音质标识格式化成展示文案 */
export const formatQuality = (q: LX.Quality | null): string => {
  if (!q) return '--'
  switch (q) {
    case '128k': return '128kbps'
    case '192k': return '192kbps'
    case '320k': return '320kbps'
    case 'flac': return 'FLAC'
    case 'flac24bit': return 'FLAC 24bit'
    case 'ape': return 'APE'
    case 'wav': return 'WAV'
    default: return q
  }
}
