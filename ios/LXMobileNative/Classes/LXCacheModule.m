//
//  LXCacheModule.m
//  Android 侧：cache/CacheModule.java
//
//  只统计/清理 iOS 的 Caches 目录（对应 Android 的 getCacheDir）。
//  注意音乐缓存目录在 Documents/TrackPlayer（见 src/plugins/player/cache.ts），
//  与 Android 一致，不属于「App 缓存」，这里不能误删，否则用户缓存会被清空。
//

#import <React/RCTBridgeModule.h>
#import <Foundation/Foundation.h>

@interface LXCacheModule : NSObject <RCTBridgeModule>
@end

@implementation LXCacheModule

RCT_EXPORT_MODULE(CacheModule)

+ (BOOL)requiresMainQueueSetup { return NO; }

static unsigned long long LXDirectorySize(NSURL *directory) {
  unsigned long long total = 0;
  NSFileManager *manager = [NSFileManager defaultManager];
  NSArray<NSURLResourceKey> *keys = @[ NSURLIsRegularFileKey, NSURLFileSizeKey, NSURLTotalFileAllocatedSizeKey ];
  NSDirectoryEnumerator<NSURL *> *enumerator =
    [manager enumeratorAtURL:directory
  includingPropertiesForKeys:keys
                     options:NSDirectoryEnumerationSkipsHiddenFiles
                errorHandler:nil];

  for (NSURL *url in enumerator) {
    NSDictionary<NSURLResourceKey, id> *values = [url resourceValuesForKeys:keys error:nil];
    if ([values[NSURLIsRegularFileKey] boolValue]) {
      NSNumber *size = values[NSURLTotalFileAllocatedSizeKey] ?: values[NSURLFileSizeKey];
      total += size.unsignedLongLongValue;
    }
  }
  return total;
}

RCT_EXPORT_METHOD(getAppCacheSize:(RCTPromiseResolveBlock)resolve
                         rejecter:(RCTPromiseRejectBlock)reject) {
  @try {
    NSURL *caches = [[NSFileManager defaultManager] URLForDirectory:NSCachesDirectory
                                                           inDomain:NSUserDomainMask
                                                  appropriateForURL:nil
                                                             create:NO
                                                              error:nil];
    unsigned long long size = caches != nil ? LXDirectorySize(caches) : 0;
    resolve(@(size));
  } @catch (NSException *exception) {
    resolve(@0);
  }
}

RCT_EXPORT_METHOD(clearAppCache:(RCTPromiseResolveBlock)resolve
                       rejecter:(RCTPromiseRejectBlock)reject) {
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    NSFileManager *manager = [NSFileManager defaultManager];
    NSURL *caches = [manager URLForDirectory:NSCachesDirectory
                                    inDomain:NSUserDomainMask
                           appropriateForURL:nil
                                      create:NO
                                       error:nil];
    if (caches == nil) {
      resolve(nil);
      return;
    }

    NSArray<NSURL *> *contents =
      [manager contentsOfDirectoryAtURL:caches
             includingPropertiesForKeys:nil
                                options:NSDirectoryEnumerationSkipsHiddenFiles
                                  error:nil];
    for (NSURL *url in contents) {
      [manager removeItemAtURL:url error:nil];
    }
    resolve(nil);
  });
}

@end
