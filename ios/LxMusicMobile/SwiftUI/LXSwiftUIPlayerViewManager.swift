import Foundation
import React

/// 把 `LXSwiftUIPlayerHostView` 暴露给 RN，JS 侧用 `<SwiftUIPlayerView />` 渲染 SwiftUI 播放页。
///
/// 说明：模块与视图通过 `RCTBridge.module(for:)` 互相拿到引用，
/// 这样 SwiftUI 上的操作可以回传给同一个 JS 事件通道。
@objc(LXSwiftUIPlayerViewManager)
final class LXSwiftUIPlayerViewManager: RCTViewManager {
  @objc override static func requiresMainQueueSetup() -> Bool { true }

  override func view() -> UIView! {
    let module = self.bridge?.module(for: LXSwiftUIPlayerModule.self) as? LXSwiftUIPlayerModule
    return LXSwiftUIPlayerHostView(module: module)
  }
}
