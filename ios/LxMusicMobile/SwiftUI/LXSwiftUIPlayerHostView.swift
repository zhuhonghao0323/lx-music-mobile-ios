import UIKit
import SwiftUI
import React

/// 把 SwiftUI 播放页包装成 UIView，供 RN 侧的 `SwiftUIPlayerView` 渲染。
@objc(LXSwiftUIPlayerHostView)
final class LXSwiftUIPlayerHostView: UIView {
  private var hostingController: UIHostingController<SwiftUIPlayerView>?
  private weak var bridgeModule: LXSwiftUIPlayerModule?

  @objc init(module: LXSwiftUIPlayerModule?) {
    self.bridgeModule = module
    super.init(frame: .zero)
    setup()
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    setup()
  }

  private func setup() {
    backgroundColor = .clear
    // 把 JS 命令回传通道接到 bridge 上
    PlayerBridge.shared.commandHandler = { [weak self] command, payload in
      self?.bridgeModule?.sendCommandToJS(command: command, payload: payload)
    }

    let host = UIHostingController(rootView: SwiftUIPlayerView())
    host.view.backgroundColor = .clear
    host.view.translatesAutoresizingMaskIntoConstraints = false
    addSubview(host.view)
    NSLayoutConstraint.activate([
      host.view.leadingAnchor.constraint(equalTo: leadingAnchor),
      host.view.trailingAnchor.constraint(equalTo: trailingAnchor),
      host.view.topAnchor.constraint(equalTo: topAnchor),
      host.view.bottomAnchor.constraint(equalTo: bottomAnchor),
    ])
    hostingController = host
  }
}
