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
    // 关键：不要让 UIKit 再插一次 safeArea，否则首帧尺寸计算错误，
    // 表现为内容顶到状态栏、与顶部导航重叠，切页后才恢复。
    host.safeAreaRegions = []
    host.view.insetsLayoutMarginsFromSafeArea = false
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
