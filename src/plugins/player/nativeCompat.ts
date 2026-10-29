/**
 * react-native-track-player 的 iOS/Android 参数差异兼容层
 *
 * 背景（这是个会导致启动后必崩的真 bug）：
 *
 * fork 的 JS 类型把方法定义成：
 *   updateNowPlayingMetadata(metadata: NowPlayingMetadata, playing: boolean)
 *
 * 但 iOS 的原生声明（ios/RNTrackPlayer/RNTrackPlayerBridge.m）是：
 *   RCT_EXTERN_METHOD(updateNowPlayingMetadata:(NSDictionary *)metadata
 *                     resolver:(RCTPromiseResolveBlock)resolve
 *                     rejecter:(RCTPromiseRejectBlock)reject)
 * ——只有 1 个业务参数，没有 playing。Android 侧才有 playing。
 *
 * 后果：JS 传 2 个，RN 自动补 2 个 promise 参数 → arguments 共 4 个，
 * 而原生的 _argumentBlocks 只有 3 个。RN 在 RCTModuleMethod 里是这么写的：
 *
 *   #if RCT_DEBUG
 *     if (arguments.count != _argumentBlocks.count) { RCTLogError(...); return nil; }
 *   #endif
 *   for (id json in arguments) { RCTArgumentBlock block = _argumentBlocks[index]; ... }
 *
 * 参数个数校验只在 Debug 构建里生效，Release 构建被编译掉了，
 * 于是 `_argumentBlocks[3]` 越界，抛 NSRangeException，
 * 再经 libc++abi 变成 std::terminate，最终表现就是：
 *
 *   *** -[__NSArrayM objectAtIndexedSubscript:]: index 3 beyond bounds [0 .. 2]
 *   打开 App、界面刚显示出来就闪退
 *
 * 之所以是「刚显示界面就崩」：恢复播放会走 playList.ts 的 updateMetaInfo，
 * 那里会调用 updateNowPlayingMetadata。
 *
 * 修法：iOS 上只传 metadata。Android 保持原样（原生接受 playing）。
 */

import { Platform } from 'react-native'
import TrackPlayer, { type NowPlayingMetadata } from 'react-native-track-player'

const isIOS = Platform.OS === 'ios'

export const updateNowPlayingMetadataCompat = async(
  metadata: NowPlayingMetadata,
  playing: boolean,
): Promise<void> => {
  if (isIOS) {
    // 必须只传 1 个参数，多传会越界崩溃（原因见文件头注释）
    const fn = TrackPlayer.updateNowPlayingMetadata as unknown as (
      m: NowPlayingMetadata,
    ) => Promise<void>
    await fn(metadata)
    return
  }
  await TrackPlayer.updateNowPlayingMetadata(metadata, playing)
}
