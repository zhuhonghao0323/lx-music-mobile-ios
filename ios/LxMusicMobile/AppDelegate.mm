#import "AppDelegate.h"
#import <ReactNativeNavigation/ReactNativeNavigation.h>

#import <React/RCTBundleURLProvider.h>
#import <React/RCTLinkingManager.h>
#import <AVFoundation/AVFoundation.h>

@implementation AppDelegate

/// 音频会话配置。
///
/// 为什么在 AppDelegate 里再设一次：react-native-track-player 的 iOS 端
/// 会在 setupPlayer 时自己配置 AVAudioSession，但那是 JS 侧初始化完成之后的事。
/// 如果用户一启动就锁屏、或者 setupPlayer 因音源加载失败而没走到，
/// 会话没被设成 playback 就会导致「后台被挂起 + 锁屏控件不出现」。
/// 这里先设一次作为兜底，RNTP 之后会覆盖成同样的值，不冲突。
///
/// 音频中断（来电、闹钟、其他 App 抢占）由 RNTP 内部的 SwiftAudio 处理，
/// 它会向 JS 侧派发 RemoteDuck 事件；恢复逻辑见
/// src/plugins/player/service.ts 中对 Event.RemoteDuck 的处理。
static void LXConfigureAudioSession(void) {
  AVAudioSession *session = [AVAudioSession sharedInstance];
  NSError *error = nil;
  if (![session setCategory:AVAudioSessionCategoryPlayback
                       mode:AVAudioSessionModeDefault
                    options:0
                      error:&error]) {
    NSLog(@"[LXMusic] 配置音频会话失败: %@", error.localizedDescription);
  }
  error = nil;
  if (![session setActive:YES error:&error]) {
    NSLog(@"[LXMusic] 激活音频会话失败: %@", error.localizedDescription);
  }
}

/// 崩溃日志落盘。
///
/// 背景：react-native-exception-handler 在 iOS 上只弹一个不含 App 符号的提示框，
/// 拿不到可用堆栈。这里额外把 NSException 的 callStackSymbols 写到
/// Documents/crash.log（Info.plist 已开启 UIFileSharingEnabled，
/// 用户可以在「文件」App 里直接导出），用于定位原生崩溃。
static NSUncaughtExceptionHandler *LXPreviousUncaughtHandler = NULL;

static void LXHandleUncaughtException(NSException *exception) {
  @try {
    NSMutableString *text = [NSMutableString string];
    [text appendString:@"\n===== LXMusic iOS Crash =====\n"];
    [text appendFormat:@"time   : %@\n", [NSDate date]];
    [text appendFormat:@"name   : %@\n", exception.name ?: @"(unknown)"];
    [text appendFormat:@"reason : %@\n", exception.reason ?: @"(unknown)"];
    [text appendString:@"\n--- callStackSymbols ---\n"];
    NSArray<NSString *> *symbols = exception.callStackSymbols;
    if (symbols.count > 0) {
      [text appendFormat:@"%@\n", [symbols componentsJoinedByString:@"\n"]];
    } else {
      [text appendString:@"(empty)\n"];
    }
    [text appendString:@"\n--- callStackReturnAddresses ---\n"];
    [text appendFormat:@"%@\n", [exception.callStackReturnAddresses componentsJoinedByString:@"\n"]];
    [text appendString:@"===== END =====\n"];

    NSString *documents = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    if (documents.length > 0) {
      NSString *path = [documents stringByAppendingPathComponent:@"crash.log"];
      NSData *data = [text dataUsingEncoding:NSUTF8StringEncoding];
      if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        [data writeToFile:path atomically:YES];
      } else {
        NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:path];
        [handle seekToEndOfFile];
        [handle writeData:data];
        [handle closeFile];
      }
    }
  } @catch (NSException *__unused ignored) {
    // 崩溃处理里再崩就没救了，直接放过
  }

  if (LXPreviousUncaughtHandler != NULL) {
    LXPreviousUncaughtHandler(exception);
  }
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
  LXConfigureAudioSession();

  RCTBridge *bridge = [[RCTBridge alloc] initWithDelegate:self launchOptions:launchOptions];
  [ReactNativeNavigation bootstrapWithBridge:bridge];
  // You can add your custom initial props in the dictionary below.
  // They will be passed down to the ViewController used by React Native.
  self.initialProps = @{};

  // react-native-exception-handler 会在 JS 初始化时（app.ts 导入 errorHandle）
  // 设置自己的 uncaught handler。这里延迟 3 秒接管：
  // 把它的 handler 存为 previous，崩溃时先落盘再交给它弹原有提示框。
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)),
                 dispatch_get_main_queue(), ^{
    LXPreviousUncaughtHandler = NSGetUncaughtExceptionHandler();
    NSSetUncaughtExceptionHandler(&LXHandleUncaughtException);
  });

  return YES;
}

- (NSArray<id<RCTBridgeModule>> *)extraModulesForBridge:(RCTBridge *)bridge {
  return [ReactNativeNavigation extraModulesForBridge:bridge];
}

- (NSURL *)sourceURLForBridge:(RCTBridge *)bridge
{
  return [self getBundleURL];
}
- (NSURL *)getBundleURL
{
#if DEBUG
  return [[RCTBundleURLProvider sharedSettings] jsBundleURLForBundleRoot:@"index"];
#else
  return [[NSBundle mainBundle] URLForResource:@"main" withExtension:@"jsbundle"];
#endif
}

/// 深链处理：与 Android 的 android:scheme="lxmusic" 对齐。
/// JS 侧通过 Linking 监听，见 src/core/init/deeplink。
- (BOOL)application:(UIApplication *)application
            openURL:(NSURL *)url
            options:(NSDictionary<UIApplicationOpenURLOptionsKey, id> *)options
{
  return [RCTLinkingManager application:application openURL:url options:options];
}

/// 通过 Universal Link / 场景恢复唤起时也交给 RN 的 Linking 模块
- (BOOL)application:(UIApplication *)application
continueUserActivity:(NSUserActivity *)userActivity
  restorationHandler:(void (^)(NSArray<id<UIUserActivityRestoring>> * _Nullable))restorationHandler
{
  return [RCTLinkingManager application:application
                     continueUserActivity:userActivity
                       restorationHandler:restorationHandler];
}

@end
