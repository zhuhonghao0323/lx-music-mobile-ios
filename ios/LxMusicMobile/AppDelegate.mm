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

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
  LXConfigureAudioSession();

  RCTBridge *bridge = [[RCTBridge alloc] initWithDelegate:self launchOptions:launchOptions];
  [ReactNativeNavigation bootstrapWithBridge:bridge];
  // You can add your custom initial props in the dictionary below.
  // They will be passed down to the ViewController used by React Native.
  self.initialProps = @{};

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
