import { toOldMusicInfo } from '@/utils'
import music from '@/utils/musicSdk'

export interface Comment {
  id: string
  text: string
  images?: string[]
  location?: string
  timeStr?: string
  userName: string
  avatar?: string
  userId?: string
  likedCount?: number
  replyNum?: number
  reply: Comment[]
}
export interface CommentInfo {
  source: LX.OnlineSource
  comments: Comment[]
  total: number
  page: number
  limit: number
  maxPage: number
}

/**
 * 判断某个源是否支持评论。
 *
 * 不看 source 字符串白名单，而是直接探测 SDK 是否带 comment 能力，
 * 这样自定义源、特殊源等情况都能正确判断，不会误报「不支持评论」。
 */
export const isCommentSupported = (source: string | null | undefined): boolean => {
  if (!source) return false
  const sdk = (music as Record<string, { comment?: unknown } | undefined>)[source]
  return !!sdk?.comment
}

export const getNewComment = async(musicInfo: LX.Music.MusicInfoOnline, page: number, limit: number, retryNum = 0): Promise<CommentInfo> => {
  // 源不存在时（本地/下载等无评论接口的来源）直接抛出可读错误，
  // 避免 music[source] 为 undefined 后取 .comment 造成 "Cannot read property 'comment' of undefined" 崩溃
  const sdk = music[musicInfo?.source as LX.OnlineSource]
  if (!sdk?.comment) throw new Error('comment_not_support')
  let resp
  try {
    resp = await (sdk.comment.getComment(toOldMusicInfo(musicInfo), page, limit) as Promise<CommentInfo>)
  } catch (error: any) {
    console.log(error.message)
    if (error.message == '取消请求' || ++retryNum > 2) throw error
    resp = await getNewComment(musicInfo, page, limit, retryNum)
  }
  return resp
}

export const getHotComment = async(musicInfo: LX.Music.MusicInfoOnline, page: number, limit: number, retryNum = 0): Promise<CommentInfo> => {
  const sdk = music[musicInfo?.source as LX.OnlineSource]
  if (!sdk?.comment) throw new Error('comment_not_support')
  let resp
  try {
    resp = await (sdk.comment.getHotComment(toOldMusicInfo(musicInfo), page, limit) as Promise<CommentInfo>)
  } catch (error: any) {
    console.log(error.message)
    if (error.message == '取消请求' || ++retryNum > 2) throw error
    resp = await getHotComment(musicInfo, page, limit, retryNum)
  }
  return resp
}

export const filterList = (list: Comment[]) => {
  const set = new Set()
  return list.filter(c => {
    let id = String(c.id)
    if (set.has(id)) return false
    set.add(id)
    return true
  })
}
