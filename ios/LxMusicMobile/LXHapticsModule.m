//
// LXHapticsModule.m
//
// 全局触感反馈（Taptic Engine）。
// 用 Objective-C 实现，避免 Swift 桥接头引入 Yoga 的编译冲突。
//

#import <React/RCTBridgeModule.h>
#import <UIKit/UIKit.h>

@interface LXHapticsModule : NSObject <RCTBridgeModule>
@end

@implementation LXHapticsModule

RCT_EXPORT_MODULE(LXHaptics);

+ (BOOL)requiresMainQueueSetup
{
  return YES;
}

RCT_EXPORT_METHOD(impact:(NSString *)style)
{
  if (@available(iOS 10.0, *)) {
    UIImpactFeedbackStyle feedbackStyle = UIImpactFeedbackStyleLight;
    if ([style isEqualToString:@"medium"]) {
      feedbackStyle = UIImpactFeedbackStyleMedium;
    } else if ([style isEqualToString:@"heavy"]) {
      feedbackStyle = UIImpactFeedbackStyleHeavy;
    } else if ([style isEqualToString:@"soft"]) {
      if (@available(iOS 13.0, *)) feedbackStyle = UIImpactFeedbackStyleSoft;
    } else if ([style isEqualToString:@"rigid"]) {
      if (@available(iOS 13.0, *)) feedbackStyle = UIImpactFeedbackStyleRigid;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
      UIImpactFeedbackGenerator *generator = [[UIImpactFeedbackGenerator alloc] initWithStyle:feedbackStyle];
      [generator prepare];
      [generator impactOccurred];
    });
  }
}

RCT_EXPORT_METHOD(notification:(NSString *)type)
{
  if (@available(iOS 10.0, *)) {
    UINotificationFeedbackType feedbackType = UINotificationFeedbackTypeSuccess;
    if ([type isEqualToString:@"warning"]) {
      feedbackType = UINotificationFeedbackTypeWarning;
    } else if ([type isEqualToString:@"error"]) {
      feedbackType = UINotificationFeedbackTypeError;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
      UINotificationFeedbackGenerator *generator = [[UINotificationFeedbackGenerator alloc] init];
      [generator prepare];
      [generator notificationOccurred:feedbackType];
    });
  }
}

RCT_EXPORT_METHOD(selection)
{
  if (@available(iOS 10.0, *)) {
    dispatch_async(dispatch_get_main_queue(), ^{
      UISelectionFeedbackGenerator *generator = [[UISelectionFeedbackGenerator alloc] init];
      [generator prepare];
      [generator selectionChanged];
    });
  }
}

@end
