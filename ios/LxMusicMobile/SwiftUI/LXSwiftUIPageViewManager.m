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
