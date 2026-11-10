//
// Swift ↔ Objective-C 桥接头
//
// Swift 文件里 `import React` 依赖这里把 RN 的 ObjC 头暴露给 Swift。
//
// 注意：这里刻意只引入最小集合。
// 如果引入 RCTViewManager.h / RCTView.h，会间接把 Yoga 拉进 Swift 的
// 预编译头（PCH），触发 “module 'yoga' ... is not defined in any loaded
// module map file” 的编译错误（本轮 CI 已实际踩到）。
//
// 因此视图层不使用 RCTViewManager，改用纯原生 UIView + JS 侧的
// UIManager 挂载方式，避免依赖 Yoga 相关头文件。
//

#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>
#import <React/RCTBridge.h>
#import <React/RCTUtils.h>
