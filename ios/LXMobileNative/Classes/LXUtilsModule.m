//
//  LXUtilsModule.m
//  Android 侧：utils/UtilsModule.java
//
//  Android 上这个模块提供的是「系统能力兜底」：退出应用、屏幕常亮、设备名、
//  语言、窗口尺寸、分享、通知权限、电池优化白名单、Wi-Fi IP、安装 APK。
//  iOS 上逐项给出等价实现，其中与 Android 平台强绑定的两项按「无此概念」处理：
//    - installApk：iOS 不能安装 APK，直接返回 NO（JS 侧只在检查更新时用）
//    - 电池优化白名单：iOS 没有该机制，恒为「已优化」返回 YES，避免反复弹窗
//

#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>
#import <React/RCTUtils.h>
#import <UIKit/UIKit.h>
#import <UserNotifications/UserNotifications.h>
#import <ifaddrs.h>
#import <arpa/inet.h>
#import <net/if.h>

static NSString *const LXUtilsScreenStateEvent = @"screen-state";
static NSString *const LXUtilsScreenSizeEvent = @"screen-size-changed";

@interface LXUtilsModule : RCTEventEmitter <RCTBridgeModule>
@end

@implementation LXUtilsModule {
  BOOL _observing;
  BOOL _listeningSystemEvents;
}

RCT_EXPORT_MODULE(UtilsModule)

+ (BOOL)requiresMainQueueSetup { return NO; }

- (NSArray<NSString *> *)supportedEvents {
  return @[LXUtilsScreenStateEvent, LXUtilsScreenSizeEvent];
}

- (void)startObserving {
  _observing = YES;
  [self startSystemEventListening];
}

- (void)stopObserving {
  _observing = NO;
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - 系统事件

- (void)startSystemEventListening {
  if (_listeningSystemEvents) return;
  _listeningSystemEvents = YES;

  NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
  // Android 的 screen-state 来自亮屏/灭屏广播；iOS 用「进入活跃 / 退到后台」对应，
  // 锁屏会触发 resignActive，语义上最接近。
  [center addObserver:self
             selector:@selector(handleScreenOn)
                 name:UIApplicationDidBecomeActiveNotification
               object:nil];
  [center addObserver:self
             selector:@selector(handleScreenOff)
                 name:UIApplicationWillResignActiveNotification
               object:nil];
  [center addObserver:self
             selector:@selector(handleOrientationChanged)
                 name:UIDeviceOrientationDidChangeNotification
               object:nil];
}

- (void)emitEvent:(NSString *)name body:(id)body {
  if (!_observing) return;
  dispatch_async(dispatch_get_main_queue(), ^{
    [self sendEventWithName:name body:body];
  });
}

- (void)handleScreenOn {
  [self emitEvent:LXUtilsScreenStateEvent body:@{ @"state": @"ON" }];
}

- (void)handleScreenOff {
  [self emitEvent:LXUtilsScreenStateEvent body:@{ @"state": @"OFF" }];
}

- (void)handleOrientationChanged {
  CGSize size = [self windowSizeInPixels];
  [self emitEvent:LXUtilsScreenSizeEvent body:@{ @"width": @(size.width), @"height": @(size.height) }];
}

#pragma mark - 基础能力

- (CGSize)windowSizeInPixels {
  // Android 侧 getWindowSize 返回的是像素，这里保持同一单位
  CGRect bounds = [UIScreen mainScreen].bounds;
  CGFloat scale = [UIScreen mainScreen].scale;
  return CGSizeMake(bounds.size.width * scale, bounds.size.height * scale);
}

RCT_EXPORT_METHOD(exitApp) {
  dispatch_async(dispatch_get_main_queue(), ^{
    // iOS 没有「优雅退出」的公开 API。侧载场景下直接结束进程，
    // 与 Android 的 finishAffinity + System.exit 效果等价。
    exit(0);
  });
}

RCT_EXPORT_METHOD(getSupportedAbis:(RCTPromiseResolveBlock)resolve
                          rejecter:(RCTPromiseRejectBlock)reject) {
  // iOS 真机只有 arm64；模拟器为 x86_64/arm64，不影响业务判断
  resolve(@[@"arm64"]);
}

RCT_EXPORT_METHOD(installApk:(NSString *)filePath
  fileProviderAuthority:(NSString *)authority
               resolver:(RCTPromiseResolveBlock)resolve
               rejecter:(RCTPromiseRejectBlock)reject) {
  // iOS 无法安装 APK，也没有对应分发方式
  resolve(@NO);
}

RCT_EXPORT_METHOD(screenkeepAwake) {
  dispatch_async(dispatch_get_main_queue(), ^{
    [UIApplication sharedApplication].idleTimerDisabled = YES;
  });
}

RCT_EXPORT_METHOD(screenUnkeepAwake) {
  dispatch_async(dispatch_get_main_queue(), ^{
    [UIApplication sharedApplication].idleTimerDisabled = NO;
  });
}

RCT_EXPORT_METHOD(getWIFIIPV4Address:(RCTPromiseResolveBlock)resolve
                            rejecter:(RCTPromiseRejectBlock)reject) {
  // 同步功能会把这个地址显示给用户，用于在桌面端填写连接地址
  resolve([self wifiIPv4Address] ?: @"");
}

- (NSString *)wifiIPv4Address {
  NSString *address = nil;
  struct ifaddrs *interfaces = NULL;
  if (getifaddrs(&interfaces) != 0) return nil;

  for (struct ifaddrs *cursor = interfaces; cursor != NULL; cursor = cursor->ifa_next) {
    if (cursor->ifa_addr == NULL) continue;
    if (cursor->ifa_addr->sa_family != AF_INET) continue;
    if ((cursor->ifa_flags & IFF_LOOPBACK) != 0) continue;
    NSString *name = [NSString stringWithUTF8String:cursor->ifa_name];
    // en0 是 iPhone 的 Wi-Fi 网卡
    if (![name isEqualToString:@"en0"]) continue;

    char buffer[INET_ADDRSTRLEN] = {0};
    struct sockaddr_in *sin = (struct sockaddr_in *)cursor->ifa_addr;
    if (inet_ntop(AF_INET, &sin->sin_addr, buffer, sizeof(buffer)) != NULL) {
      address = [NSString stringWithUTF8String:buffer];
      break;
    }
  }
  freeifaddrs(interfaces);
  return address;
}

RCT_EXPORT_METHOD(getDeviceName:(RCTPromiseResolveBlock)resolve
                       rejecter:(RCTPromiseRejectBlock)reject) {
  // iOS 16+ 读取设备名需要 entitlement（App Store 规则），侧载场景下
  // UIDevice.name 通常返回 "iPhone"，因此退回 model 作为更可用的标识。
  dispatch_async(dispatch_get_main_queue(), ^{
    NSString *name = [UIDevice currentDevice].name;
    if (name.length == 0) name = [UIDevice currentDevice].model ?: @"iPhone";
    resolve(name);
  });
}

RCT_EXPORT_METHOD(isNotificationsEnabled:(RCTPromiseResolveBlock)resolve
                                rejecter:(RCTPromiseRejectBlock)reject) {
  [[UNUserNotificationCenter currentNotificationCenter] getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings *settings) {
    BOOL enabled = settings.authorizationStatus == UNAuthorizationStatusAuthorized
      || settings.authorizationStatus == UNAuthorizationStatusProvisional;
    resolve(@(enabled));
  }];
}

RCT_EXPORT_METHOD(openNotificationPermissionActivity:(RCTPromiseResolveBlock)resolve
                                            rejecter:(RCTPromiseRejectBlock)reject) {
  UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
  [center requestAuthorizationWithOptions:(UNAuthorizationOptionAlert | UNAuthorizationOptionSound | UNAuthorizationOptionBadge)
                        completionHandler:^(BOOL granted, NSError *error) {
    resolve(@(granted));
  }];
}

RCT_EXPORT_METHOD(shareText:(NSString *)shareTitle
                      title:(NSString *)title
                       text:(NSString *)text) {
  dispatch_async(dispatch_get_main_queue(), ^{
    NSString *content = text.length > 0 ? text : (title ?: @"");
    if (content.length == 0) return;

    UIActivityViewController *controller =
      [[UIActivityViewController alloc] initWithActivityItems:@[content] applicationActivities:nil];
    UIViewController *presenter = RCTPresentedViewController();
    if (presenter == nil) return;

    // iPad 上必须提供 popover 锚点，否则会直接崩
    if (controller.popoverPresentationController != nil) {
      controller.popoverPresentationController.sourceView = presenter.view;
      controller.popoverPresentationController.sourceRect =
        CGRectMake(CGRectGetMidX(presenter.view.bounds), CGRectGetMidY(presenter.view.bounds), 1, 1);
      controller.popoverPresentationController.permittedArrowDirections = 0;
    }
    [presenter presentViewController:controller animated:YES completion:nil];
  });
}

RCT_EXPORT_METHOD(getSystemLocales:(RCTPromiseResolveBlock)resolve
                          rejecter:(RCTPromiseRejectBlock)reject) {
  NSArray<NSString *> *languages = [NSLocale preferredLanguages];
  NSString *locale = languages.firstObject;
  if (locale.length == 0) locale = [[NSLocale currentLocale] localeIdentifier];
  resolve(locale ?: @"en");
}

RCT_EXPORT_METHOD(getWindowSize:(RCTPromiseResolveBlock)resolve
                       rejecter:(RCTPromiseRejectBlock)reject) {
  dispatch_async(dispatch_get_main_queue(), ^{
    CGSize size = [self windowSizeInPixels];
    resolve(@{ @"width": @((int)size.width), @"height": @((int)size.height) });
  });
}

RCT_EXPORT_METHOD(listenWindowSizeChanged) {
  // Android 侧 JS 会调用这个方法开启监听，iOS 在 startObserving 时已统一注册，
  // 这里保留为 no-op 以免 JS 调用不存在的原生方法而报错。
  [self startSystemEventListening];
}

RCT_EXPORT_METHOD(isIgnoringBatteryOptimization:(RCTPromiseResolveBlock)resolve
                                       rejecter:(RCTPromiseRejectBlock)reject) {
  // iOS 没有电池优化白名单，恒为 true 可避免设置页反复提示用户去授权
  resolve(@YES);
}

RCT_EXPORT_METHOD(requestIgnoreBatteryOptimization:(RCTPromiseResolveBlock)resolve
                                          rejecter:(RCTPromiseRejectBlock)reject) {
  resolve(@YES);
}

@end
