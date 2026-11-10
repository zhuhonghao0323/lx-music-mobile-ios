//
// Swift ↔ Objective-C 桥接头
//
// Swift 文件里 `import React` 依赖这里把 RN 的 ObjC 头暴露给 Swift。
// 只需要暴露用到的那几个：RCTViewManager / RCTEventEmitter / RCTBridge。
//

#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>
#import <React/RCTViewManager.h>
#import <React/RCTBridge.h>
#import <React/RCTUIManager.h>
#import <React/RCTUtils.h>
