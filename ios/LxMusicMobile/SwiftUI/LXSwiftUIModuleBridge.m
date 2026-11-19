//
// LXSwiftUIModuleBridge.m
//
// 【关键】Swift 写的 RCTEventEmitter 模块不会自动注册。
//
// RCT_EXPORT_MODULE 宏靠 +load 把类登记进 RCTModuleClasses，
// 而 Swift 类不参与 +load，所以纯 Swift 的模块永远不会出现在
// NativeModules 里 —— 组件能渲染（ViewManager 是 ObjC），但
// 状态推不下去、命令回不来，界面全是空数据。
//
// 这里用 RN 官方推荐的 RCT_EXTERN_MODULE 为 Swift 模块补上注册。
//

#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>

// 播放页状态桥
@interface RCT_EXTERN_MODULE(LXSwiftUIPlayerModule, RCTEventEmitter)
RCT_EXTERN_METHOD(updateState:(NSDictionary *)state)
RCT_EXTERN_METHOD(isSupported:(RCTPromiseResolveBlock)resolve
                rejecter:(RCTPromiseRejectBlock)reject)
@end

// 通用页面状态桥
@interface RCT_EXTERN_MODULE(LXSwiftUIPageModule, RCTEventEmitter)
RCT_EXTERN_METHOD(updatePageState:(NSDictionary *)payload)
RCT_EXTERN_METHOD(isSupported:(RCTPromiseResolveBlock)resolve
                rejecter:(RCTPromiseRejectBlock)reject)
@end
