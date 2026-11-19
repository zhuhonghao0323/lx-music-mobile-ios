//
// LXSwiftUIPlayerViewManager.m
//
// 把 SwiftUI 播放页宿主视图暴露给 RN。
//
// 为什么用 Objective-C 写这个 Manager：
// Swift 侧一旦 import React 的视图相关头（RCTViewManager.h → RCTView.h），
// 就会把 Yoga 带进 Swift 的预编译头，触发
// "module 'yoga' ... is not defined in any loaded module map file"。
// ObjC 文件不受该限制，因此放在这里最稳。
//
// 这里通过 NSClassFromString 动态取 Swift 类，避免依赖生成的
// LxMusicMobile-Swift.h（该头在增量构建时可能尚未生成）。
//

#import <React/RCTViewManager.h>
#import <React/RCTBridge.h>
#import <UIKit/UIKit.h>
#import <objc/message.h>

@interface LXSwiftUIPlayerViewManager : RCTViewManager
@end

@implementation LXSwiftUIPlayerViewManager

RCT_EXPORT_MODULE(LXSwiftUIPlayerView)

+ (BOOL)requiresMainQueueSetup
{
  return YES;
}

- (UIView *)view
{
  Class hostClass = NSClassFromString(@"LXSwiftUIPlayerHostView");
  if (hostClass == Nil) {
    // 诊断：Swift 类未导出时给出醒目标记，避免静默返回空白视图
    UIView *fallback = [[UIView alloc] initWithFrame:CGRectZero];
    fallback.backgroundColor = [UIColor redColor];
    UILabel *label = [[UILabel alloc] init];
    label.text = @" LXSwiftUIPlayerHostView NOT FOUND ";
    label.textColor = [UIColor whiteColor];
    label.font = [UIFont boldSystemFontOfSize:14];
    label.numberOfLines = 0;
    label.textAlignment = NSTextAlignmentCenter;
    label.translatesAutoresizingMaskIntoConstraints = NO;
    [fallback addSubview:label];
    [NSLayoutConstraint activateConstraints:@[
      [label.centerXAnchor constraintEqualToAnchor:fallback.centerXAnchor],
      [label.centerYAnchor constraintEqualToAnchor:fallback.centerYAnchor],
    ]];
    NSLog(@"[LXSwiftUIPlayer] hostClass Nil!");
    return fallback;
  }

  id module = [self.bridge moduleForName:@"LXSwiftUIPlayerModule" lazilyLoadIfNecessary:YES];

  // initWithModule: 是 Swift 侧标记为 @objc 的初始化方法
  SEL initSelector = NSSelectorFromString(@"initWithModule:");
  if ([hostClass instancesRespondToSelector:initSelector]) {
    id allocated = [hostClass alloc];
    UIView *host = ((id (*)(id, SEL, id))objc_msgSend)(allocated, initSelector, module);
    return host;
  }

  // 兜底：无参初始化
  return [[hostClass alloc] init];
}

@end
