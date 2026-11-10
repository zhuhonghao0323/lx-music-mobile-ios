import Foundation
import React

/// RN ↔ SwiftUI 播放页的桥。
///
/// 职责只有两件事：
/// 1. 接收 JS 推来的播放状态，转给 `PlayerBridge`（SwiftUI 据此渲染）
/// 2. 把 SwiftUI 上的用户操作回传给 JS（真正的业务逻辑仍由 RN 执行）
///
/// 业务逻辑一行都不在这里实现，保证「只重写 UI 层」的边界。
@objc(LXSwiftUIPlayerModule)
final class LXSwiftUIPlayerModule: RCTEventEmitter {
  @objc static override func requiresMainQueueSetup() -> Bool { true }

  private var hasListeners = false

  override func supportedEvents() -> [String]! {
    return ["lx-swiftui-player-command"]
  }

  override func startObserving() {
    hasListeners = true
  }

  override func stopObserving() {
    hasListeners = false
  }

  /// JS 推送播放状态
  @objc(updateState:)
  func updateState(_ state: NSDictionary) {
    let dict = (state as? [String: Any]) ?? [:]
    DispatchQueue.main.async {
      PlayerBridge.shared.apply(dict)
    }
  }

  /// SwiftUI → JS 的命令回传
  func sendCommandToJS(command: String, payload: [String: Any]) {
    let body: [String: Any] = ["command": command, "payload": payload]
    // RCTEventEmitter 要求在主线程发送事件
    if Thread.isMainThread {
      guard hasListeners else { return }
      sendEvent(withName: "lx-swiftui-player-command", body: body)
    } else {
      DispatchQueue.main.async { [weak self] in
        guard let self = self, self.hasListeners else { return }
        self.sendEvent(withName: "lx-swiftui-player-command", body: body)
      }
    }
  }

  /// 让 JS 侧确认模块可用
  @objc(isSupported:rejecter:)
  func isSupported(_ resolve: RCTPromiseResolveBlock, rejecter _: RCTPromiseRejectBlock) {
    resolve(true)
  }
}
