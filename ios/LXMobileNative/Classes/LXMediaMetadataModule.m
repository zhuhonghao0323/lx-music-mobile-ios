//
//  LXMediaMetadataModule.m
//  Android 侧：react-native-local-media-metadata（lyswhut fork，只有 Android 实现）
//
//  用途：扫描本地音乐时读取音频标签（标题/歌手/专辑/封面/时长）。
//  iOS 用系统 AVFoundation 的 AVURLAsset 读取，不引入任何第三方解码库。
//
//  能力边界（已与 JS 层对齐，见 src/utils/localMediaMetadata.ios.ts）：
//    - 读取：标题/歌手/专辑/时长/封面/同名 .lrc 歌词 —— 支持
//    - 写入：iOS 没有公开 API 能原地改写音频标签（AVAssetExportSession 只能
//      重新导出新文件），因此 writeMetadata/writePic/writeLyric 降级为 no-op。
//

#import <React/RCTBridgeModule.h>
#import <AVFoundation/AVFoundation.h>

@interface LXMediaMetadataModule : NSObject <RCTBridgeModule>
@end

@implementation LXMediaMetadataModule

RCT_EXPORT_MODULE(LocalMediaMetadata)

+ (BOOL)requiresMainQueueSetup { return NO; }

static NSString *LXStringFromMetadata(NSArray<AVMetadataItem *> *items, AVMetadataKey key) {
  for (AVMetadataItem *item in items) {
    if (![item.commonKey isEqualToString:key]) continue;
    NSString *value = [item stringValue];
    if (value.length > 0) return value;
  }
  return nil;
}

static double LXDurationSeconds(AVURLAsset *asset) {
  CMTime duration = asset.duration;
  if (CMTIME_IS_INVALID(duration) || CMTIME_IS_INDEFINITE(duration)) return 0;
  double seconds = CMTimeGetSeconds(duration);
  return isfinite(seconds) ? seconds : 0;
}

RCT_EXPORT_METHOD(readMetadata:(NSString *)filePath
                      resolver:(RCTPromiseResolveBlock)resolve
                      rejecter:(RCTPromiseRejectBlock)reject) {
  NSURL *url = [NSURL fileURLWithPath:filePath];
  AVURLAsset *asset = [AVURLAsset URLAssetWithURL:url options:@{ AVURLAssetPreferPreciseDurationAndTimingKey: @YES }];

  [asset loadValuesAsynchronouslyForKeys:@[ @"commonMetadata", @"duration" ]
                      completionHandler:^{
    NSError *error = nil;
    AVKeyValueStatus metadataStatus = [asset statusOfValueForKey:@"commonMetadata" error:&error];
    if (metadataStatus != AVKeyValueStatusLoaded) {
      resolve([NSNull null]);
      return;
    }

    NSArray<AVMetadataItem *> *items = asset.commonMetadata;
    NSString *title = LXStringFromMetadata(items, AVMetadataCommonKeyTitle);
    NSString *artist = LXStringFromMetadata(items, AVMetadataCommonKeyArtist);
    NSString *album = LXStringFromMetadata(items, AVMetadataCommonKeyAlbumName);
    double duration = LXDurationSeconds(asset);

    NSString *ext = url.pathExtension.lowercaseString ?: @"";
    NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:nil];
    unsigned long long size = [attributes[NSFileSize] unsignedLongLongValue];

    // Android 侧返回的 bitrate 是字符串（如 "320kbps"），这里按 时长/文件大小 估算
    NSString *bitrate = @"";
    if (duration > 0 && size > 0) {
      double kbps = (double)size * 8.0 / duration / 1000.0;
      bitrate = [NSString stringWithFormat:@"%.0fkbps", kbps];
    }

    NSString *name = title;
    if (name.length == 0) name = [filePath.lastPathComponent stringByDeletingPathExtension];

    resolve(@{
      @"type": ext.length > 0 ? ext : @"mp3",
      @"ext": ext.length > 0 ? ext : @"mp3",
      @"bitrate": bitrate,
      // interval 的单位是「秒」：JS 侧 formatPlayTime2 用 time / 60 取分钟
      @"interval": @((int)llround(duration)),
      @"size": @(size),
      @"albumName": album ?: @"",
      @"singer": artist ?: @"",
      @"name": name ?: @"",
    });
  }];
}

/// 读取封面并落盘到 picDir，返回图片路径。
/// Android 侧同样是把封面解出来存到临时目录再交给 JS 显示。
RCT_EXPORT_METHOD(readPic:(NSString *)filePath
                   picDir:(NSString *)picDir
                 resolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject) {
  NSURL *url = [NSURL fileURLWithPath:filePath];
  AVURLAsset *asset = [AVURLAsset URLAssetWithURL:url options:nil];

  [asset loadValuesAsynchronouslyForKeys:@[ @"commonMetadata" ] completionHandler:^{
    NSError *error = nil;
    if ([asset statusOfValueForKey:@"commonMetadata" error:&error] != AVKeyValueStatusLoaded) {
      resolve(@"");
      return;
    }

    for (AVMetadataItem *item in asset.commonMetadata) {
      if (![item.commonKey isEqualToString:AVMetadataCommonKeyArtwork]) continue;
      NSData *data = nil;
      if ([item.value isKindOfClass:[NSData class]]) {
        data = (NSData *)item.value;
      } else if ([item.value isKindOfClass:[NSDictionary class]]) {
        data = ((NSDictionary *)item.value)[@"data"];
      }
      if (data.length == 0) continue;

      NSString *target = [picDir stringByAppendingPathComponent:
        [NSString stringWithFormat:@"%08x.jpg", (unsigned int)filePath.hash]];
      [[NSFileManager defaultManager] createDirectoryAtPath:picDir
                               withIntermediateDirectories:YES
                                                attributes:nil
                                                     error:nil];
      if ([[NSFileManager defaultManager] createFileAtPath:target contents:data attributes:nil]) {
        resolve(target);
        return;
      }
    }
    resolve(@"");
  }];
}

/// 读取歌词：优先同名 .lrc（与 Android 的 isReadLrcFile 行为一致）
RCT_EXPORT_METHOD(readLyric:(NSString *)filePath
                isReadLrcFile:(BOOL)isReadLrcFile
                    resolver:(RCTPromiseResolveBlock)resolve
                    rejecter:(RCTPromiseRejectBlock)reject) {
  if (isReadLrcFile) {
    NSString *lrcPath = [[filePath stringByDeletingPathExtension] stringByAppendingPathExtension:@"lrc"];
    NSString *content = [NSString stringWithContentsOfFile:lrcPath
                                                  encoding:NSUTF8StringEncoding
                                                     error:nil];
    if (content.length > 0) {
      resolve(content);
      return;
    }
  }
  // 内嵌歌词（ID3 USLT 等）在 iOS 上没有稳定的通用读取路径，这里返回空字符串，
  // JS 层会退回到在线歌词。属于已知能力差异，见风险清单。
  resolve(@"");
}

// 以下三个写入方法：iOS 无法原地改写音频标签，明确降级为 no-op
RCT_EXPORT_METHOD(writeMetadata:(NSString *)filePath
                       metadata:(NSDictionary *)metadata
                    isOverwrite:(BOOL)isOverwrite
                       resolver:(RCTPromiseResolveBlock)resolve
                       rejecter:(RCTPromiseRejectBlock)reject) {
  resolve(nil);
}

RCT_EXPORT_METHOD(writePic:(NSString *)filePath
                  picPath:(NSString *)picPath
                 resolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject) {
  resolve(nil);
}

RCT_EXPORT_METHOD(writeLyric:(NSString *)filePath
                     lyric:(NSString *)lyric
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject) {
  resolve(nil);
}

@end
