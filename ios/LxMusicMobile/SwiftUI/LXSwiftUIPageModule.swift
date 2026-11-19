import Foundation
import React

/// 通用 SwiftUI 页面模块（多页面复用）。
///
/// JS 侧调用 updateState(pageId, state) 推状态；
/// SwiftUI 侧操作通过事件 lx-swiftui-page-command 回传（含 pageId）。
@objc(LXSwiftUIPageModule)
final class LXSwiftUIPageModule: RCTEventEmitter {
  @objc static override func requiresMainQueueSetup() -> Bool { true }

  private var hasListeners = false

  override func supportedEvents() -> [String]! {
    return ["lx-swiftui-page-command"]
  }

  override func startObserving() { hasListeners = true }
  override func stopObserving() { hasListeners = false }

  /// JS 推送某页状态：{ pageId: string, state: {...} }
  @objc(updatePageState:)
  func updatePageState(_ payload: NSDictionary) {
    guard let dict = payload as? [String: Any],
          let pageId = dict["pageId"] as? String else { return }
    let state = (dict["state"] as? [String: Any]) ?? [:]
    DispatchQueue.main.async {
      PageBridge.shared.apply(pageId: pageId, state: state)
    }
  }

  /// SwiftUI → JS 命令回传
  func sendCommandToJS(pageId: String, command: String, payload: [String: Any]) {
    let body: [String: Any] = ["pageId": pageId, "command": command, "payload": payload]
    let emit = { [weak self] in
      guard let self = self, self.hasListeners else { return }
      self.sendEvent(withName: "lx-swiftui-page-command", body: body)
    }
    if Thread.isMainThread { emit() } else { DispatchQueue.main.async(execute: emit) }
  }

  @objc(isSupported:rejecter:)
  func isSupported(_ resolve: RCTPromiseResolveBlock, rejecter _: RCTPromiseRejectBlock) {
    resolve(true)
  }
}
