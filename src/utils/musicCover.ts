/**
 * 歌曲封面提取（统一）。
 *
 * 项目里存在两种歌曲信息结构：
 * 1. 列表里的 LX.Music.MusicInfo：封面在 `meta.picUrl`
 * 2. 播放器快照 LX.Player.MusicInfo：封面在顶层 `pic`（已由 setPlayerMusicInfo
 *    从 meta.picUrl 拷贝而来）
 *
 * 之前多处只认其一，导致部分位置封面一直拿不到（显示 "LX" 占位）。
 * 这里同时兼容两种结构，所有需要封面的地方都从这里取。
 */
export const getMusicPicUrl = (
  musicInfo: (LX.Music.MusicInfo | LX.Player.MusicInfo | null | undefined),
): string | null => {
  if (!musicInfo) return null
  // 播放器快照：顶层 pic
  if ('pic' in musicInfo && typeof musicInfo.pic == 'string' && musicInfo.pic) {
    return musicInfo.pic
  }
  // 列表歌曲：meta.picUrl
  const meta = (musicInfo as LX.Music.MusicInfo).meta
  const picUrl = meta?.picUrl
  return typeof picUrl == 'string' && picUrl ? picUrl : null
}
