//
//  LXDocumentPickerModule.m
//  Android 侧：react-native-file-system 的 AndroidScoped.openDocument（SAF 文件选择器）
//
//  iOS 没有 SAF，等价能力是 UIDocumentPickerViewController。
//  这里直接用它实现，避免为了「选一个文件」再引入一个第三方依赖。
//
//  与 Android 的差异：
//    - Android 返回的是 content:// URI 且可以持久授权；
//      iOS 这里用 asCopy:YES 把文件复制到 App 沙盒临时目录，返回普通文件路径，
//      因此调用方拿到的路径可以直接用 RNFS 读写，不需要额外权限处理。
//

#import <React/RCTBridgeModule.h>
#import <React/RCTUtils.h>
#import <UIKit/UIKit.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

@interface LXDocumentPickerModule : NSObject <RCTBridgeModule, UIDocumentPickerDelegate>
@end

@implementation LXDocumentPickerModule {
  RCTPromiseResolveBlock _resolve;
  RCTPromiseRejectBlock _reject;
}

RCT_EXPORT_MODULE(LXDocumentPickerModule)

+ (BOOL)requiresMainQueueSetup { return NO; }

RCT_EXPORT_METHOD(pick:(NSDictionary *)options
                resolver:(RCTPromiseResolveBlock)resolve
                rejecter:(RCTPromiseRejectBlock)reject) {
  dispatch_async(dispatch_get_main_queue(), ^{
    if (self->_resolve != nil) {
      reject(@"busy", @"已有一个文件选择器在展示中", nil);
      return;
    }

    NSMutableArray<UTType *> *types = [NSMutableArray array];

    NSArray<NSString *> *extTypes = options[@"extTypes"];
    if ([extTypes isKindOfClass:[NSArray class]]) {
      for (NSString *ext in extTypes) {
        if (![ext isKindOfClass:[NSString class]]) continue;
        UTType *type = [UTType typeWithFilenameExtension:ext];
        if (type != nil) [types addObject:type];
      }
    }

    // 没指定类型时放开为「任意文件」，音源脚本/歌单备份/音频都能选
    if (types.count == 0) [types addObject:UTTypeItem];

    UIDocumentPickerViewController *picker =
      [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:types asCopy:YES];
    picker.delegate = self;
    picker.allowsMultipleSelection = [options[@"multi"] boolValue];
    picker.shouldShowFileExtensions = YES;

    UIViewController *presenter = RCTPresentedViewController();
    if (presenter == nil) {
      reject(@"no_presenter", @"找不到可用于展示选择器的界面", nil);
      return;
    }

    self->_resolve = resolve;
    self->_reject = reject;
    [presenter presentViewController:picker animated:YES completion:nil];
  });
}

#pragma mark - UIDocumentPickerDelegate

- (void)documentPicker:(UIDocumentPickerViewController *)controller
didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
  RCTPromiseResolveBlock resolve = _resolve;
  _resolve = nil;
  _reject = nil;
  if (resolve == nil) return;

  NSURL *url = urls.firstObject;
  if (url == nil) {
    resolve([NSNull null]);
    return;
  }

  // asCopy:YES 时文件已经在沙盒临时目录里，但仍需确认可读
  NSNumber *size = @0;
  [url getResourceValue:&size forKey:NSURLFileSizeKey error:nil];

  resolve(@{
    @"name": url.lastPathComponent ?: @"",
    @"path": url.path ?: @"",
    @"size": size ?: @0,
  });
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller {
  RCTPromiseRejectBlock reject = _reject;
  _resolve = nil;
  _reject = nil;
  if (reject != nil) reject(@"canceled", @"用户取消了选择", nil);
}

@end
