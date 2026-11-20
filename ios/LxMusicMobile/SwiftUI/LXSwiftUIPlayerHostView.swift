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
    host.view.insetsLayoutMarginsFromSafeArea = false
    host.view.translatesAutoresizingMaskIntoConstraints = false
    addSubview(host.view)
    // 用 safeAreaLayoutGuide 约束，内容自动避开状态栏/Home 指示条
    // RN 传入的 frame 已经在安全区内（geo h 已扣除状态栏/Home 条），
    // 这里若再扣一次 safeArea 会双重避让 → 顶部白条、内容被压缩。
    // 直接贴 superView 四边即可。
    NSLayoutConstraint.activate([
      host.view.leadingAnchor.constraint(equalTo: leadingAnchor),
      host.view.trailingAnchor.constraint(equalTo: trailingAnchor),
      host.view.topAnchor.constraint(equalTo: topAnchor),
      host.view.bottomAnchor.constraint(equalTo: bottomAnchor),
    ])
    hostingController = host
  }
}

/// 从全局 keyWindow 读取安全区（window 早已布局完成，首帧即准确；
/// 不像 safeAreaLayoutGuide 要等视图布局后才算出，会首帧重叠、切页才正常）。
func LXWindowSafeInsets() -> UIEdgeInsets {
  if #available(iOS 15.0, *) {
    let scenes = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
    for scene in scenes {
      for w in scene.windows where w.isKeyWindow {
        return w.safeAreaInsets
      }
    }
  }
  return .zero
}
