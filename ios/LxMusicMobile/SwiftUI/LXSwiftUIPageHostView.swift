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
    host.view.insetsLayoutMarginsFromSafeArea = false
    host.view.translatesAutoresizingMaskIntoConstraints = false
    addSubview(host.view)
    // RN 传入的 frame 已经在安全区内（geo h 已扣除状态栏/Home 条），
    // 这里若再扣一次 safeArea 会双重避让 → 顶部白条、内容被压缩。
    // 直接贴 superView 四边即可。
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

/// 主页宿主
@objc(LXSwiftUIHomeHostView)
final class LXSwiftUIHomeHostView: LXSwiftUIPageHostBase {
  override var pageId: String { "home" }
  override func makeRootView() -> AnyView { AnyView(SwiftUIHomeView(pageId: pageId)) }
  @objc override init(module: LXSwiftUIPageModule?) {
    super.init(module: module)
    install()
  }
  required init?(coder: NSCoder) { super.init(coder: coder) }
}

/// 搜索页宿主
@objc(LXSwiftUISearchHostView)
final class LXSwiftUISearchHostView: LXSwiftUIPageHostBase {
  override var pageId: String { "search" }
  override func makeRootView() -> AnyView { AnyView(SwiftUISearchView(pageId: pageId)) }
  @objc override init(module: LXSwiftUIPageModule?) {
    super.init(module: module)
    install()
  }
  required init?(coder: NSCoder) { super.init(coder: coder) }
}

/// 排行榜宿主
@objc(LXSwiftUILeaderboardHostView)
final class LXSwiftUILeaderboardHostView: LXSwiftUIPageHostBase {
  override var pageId: String { "leaderboard" }
  override func makeRootView() -> AnyView { AnyView(SwiftUILeaderboardView(pageId: pageId)) }
  @objc override init(module: LXSwiftUIPageModule?) {
    super.init(module: module)
    install()
  }
  required init?(coder: NSCoder) { super.init(coder: coder) }
}

/// 设置页宿主
@objc(LXSwiftUISettingHostView)
final class LXSwiftUISettingHostView: LXSwiftUIPageHostBase {
  override var pageId: String { "setting" }
  override func makeRootView() -> AnyView { AnyView(SwiftUISettingView(pageId: pageId)) }
  @objc override init(module: LXSwiftUIPageModule?) {
    super.init(module: module)
    install()
  }
  required init?(coder: NSCoder) { super.init(coder: coder) }
}

/// 歌单详情宿主
@objc(LXSwiftUIMylistHostView)
final class LXSwiftUIMylistHostView: LXSwiftUIPageHostBase {
  override var pageId: String { "mylist" }
  override func makeRootView() -> AnyView { AnyView(SwiftUIMylistView(pageId: pageId)) }
  @objc override init(module: LXSwiftUIPageModule?) {
    super.init(module: module)
    install()
  }
  required init?(coder: NSCoder) { super.init(coder: coder) }
}

