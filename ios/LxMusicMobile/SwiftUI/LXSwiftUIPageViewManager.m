//
// LXSwiftUIPageViewManager.m
// 通用 SwiftUI 页面宿主，按页面名注册多个 RN 组件。
//
#import <React/RCTViewManager.h>
#import <React/RCTBridge.h>
#import <UIKit/UIKit.h>
#import <objc/message.h>

static UIView *LXMakeSwiftUIHost(RCTViewManager *mgr, NSString *hostClassName)
{
  Class hostClass = NSClassFromString(hostClassName);
  if (hostClass == Nil) return [[UIView alloc] initWithFrame:CGRectZero];

  id module = [mgr.bridge moduleForName:@"LXSwiftUIPageModule" lazilyLoadIfNecessary:YES];
  SEL initSelector = NSSelectorFromString(@"initWithModule:");
  if ([hostClass instancesRespondToSelector:initSelector]) {
    id allocated = [hostClass alloc];
    return ((id (*)(id, SEL, id))objc_msgSend)(allocated, initSelector, module);
  }
  return [[hostClass alloc] init];
}

// ---- 我的页 ----
@interface LXSwiftUIMineViewManager : RCTViewManager
@end
@implementation LXSwiftUIMineViewManager
RCT_EXPORT_MODULE(LXSwiftUIMineView)
+ (BOOL)requiresMainQueueSetup { return YES; }
- (UIView *)view { return LXMakeSwiftUIHost(self, @"LXSwiftUIMineHostView"); }
@end

// ---- 主页 ----
@interface LXSwiftUIHomeViewManager : RCTViewManager
@end
@implementation LXSwiftUIHomeViewManager
RCT_EXPORT_MODULE(LXSwiftUIHomeView)
+ (BOOL)requiresMainQueueSetup { return YES; }
- (UIView *)view { return LXMakeSwiftUIHost(self, @"LXSwiftUIHomeHostView"); }
@end

// ---- 搜索页 ----
@interface LXSwiftUISearchViewManager : RCTViewManager
@end
@implementation LXSwiftUISearchViewManager
RCT_EXPORT_MODULE(LXSwiftUISearchView)
+ (BOOL)requiresMainQueueSetup { return YES; }
- (UIView *)view { return LXMakeSwiftUIHost(self, @"LXSwiftUISearchHostView"); }
@end

// ---- 排行榜 ----
@interface LXSwiftUILeaderboardViewManager : RCTViewManager
@end
@implementation LXSwiftUILeaderboardViewManager
RCT_EXPORT_MODULE(LXSwiftUILeaderboardView)
+ (BOOL)requiresMainQueueSetup { return YES; }
- (UIView *)view { return LXMakeSwiftUIHost(self, @"LXSwiftUILeaderboardHostView"); }
@end

// ---- 设置页 ----
@interface LXSwiftUISettingViewManager : RCTViewManager
@end
@implementation LXSwiftUISettingViewManager
RCT_EXPORT_MODULE(LXSwiftUISettingView)
+ (BOOL)requiresMainQueueSetup { return YES; }
- (UIView *)view { return LXMakeSwiftUIHost(self, @"LXSwiftUISettingHostView"); }
@end

// ---- 歌单详情 ----
@interface LXSwiftUIMylistViewManager : RCTViewManager
@end
@implementation LXSwiftUIMylistViewManager
RCT_EXPORT_MODULE(LXSwiftUIMylistView)
+ (BOOL)requiresMainQueueSetup { return YES; }
- (UIView *)view { return LXMakeSwiftUIHost(self, @"LXSwiftUIMylistHostView"); }
@end
