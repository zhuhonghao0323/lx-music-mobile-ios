/**
 * 歌曲封面提取（统一）。
 *
 * 项目里歌曲封面字段是 `musicInfo.meta.picUrl`，不是 `pic`。
 * 之前多处误用 `.pic` 导致 Image 拿到 undefined，一直显示 "LX" 占位符。
 * 这里集中封装，所有需要封面的地方都从这里取。
 */
export const getMusicPicUrl = (musicInfo: LX.Music.MusicInfo | null | undefined): string | null => {
  if (!musicInfo) return null
  const picUrl = musicInfo.meta?.picUrl
  return typeof picUrl == 'string' && picUrl ? picUrl : null
}
