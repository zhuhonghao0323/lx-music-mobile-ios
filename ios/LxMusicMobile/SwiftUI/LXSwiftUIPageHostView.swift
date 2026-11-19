import UIKit
import SwiftUI
import React

/// 基类：通用 SwiftUI 页面宿主
class LXSwiftUIPageHostBase: UIView {
  fileprivate weak var bridgeModule: LXSwiftUIPageModule?

  @objc init(module: LXSwiftUIPageModule?) {
    self.bridgeModule = module
    super.init(frame: .zero)
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
  }

  /// 子类覆盖：返回实际页面
  func makeRootView() -> AnyView {
    AnyView(EmptyView())
  }

  /// pageId（用于命令回传时标识来源页）
  var pageId: String { "unknown" }

  func install() {
    backgroundColor = .clear
    let pid = pageId
    PageBridge.shared.commandHandler = { [weak self] pageId, command, payload in
      self?.bridgeModule?.sendCommandToJS(pageId: pageId, command: command, payload: payload)
    }
    let root = makeRootView()
    let host = UIHostingController(rootView: root)
    host.view.backgroundColor = .clear
    host.view.translatesAutoresizingMaskIntoConstraints = false
    addSubview(host.view)
    NSLayoutConstraint.activate([
      host.view.leadingAnchor.constraint(equalTo: leadingAnchor),
      host.view.trailingAnchor.constraint(equalTo: trailingAnchor),
      host.view.topAnchor.constraint(equalTo: topAnchor),
      host.view.bottomAnchor.constraint(equalTo: bottomAnchor),
    ])
    _ = pid
  }
}

/// 「我的」页宿主
@objc(LXSwiftUIMineHostView)
final class LXSwiftUIMineHostView: LXSwiftUIPageHostBase {
  override var pageId: String { "mine" }
  override func makeRootView() -> AnyView { AnyView(SwiftUIMineView(pageId: pageId)) }
  @objc override init(module: LXSwiftUIPageModule?) {
    super.init(module: module)
    install()
  }
  required init?(coder: NSCoder) { super.init(coder: coder) }
}
