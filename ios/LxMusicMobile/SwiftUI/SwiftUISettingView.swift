import SwiftUI

/// 设置页 SwiftUI 实现：系统分组列表。
/// 每个分组点击后由 RN 打开原有的设置子页（保证设置项一个不丢）。
struct SwiftUISettingView: View {
  let pageId: String
  @ObservedObject private var bridge = PageBridge.shared

  private var state: [String: Any] { bridge.state(pageId) }
  private var version: String { state["version"] as? String ?? "" }
  private var themeName: String { state["themeName"] as? String ?? "" }

  /// 设置分组（与 RN 版 SETTING_SCREENS 一致）
  private let groups: [(id: String, title: String, symbol: String)] = [
    ("basic", "基础设置", "slider.horizontal.3"),
    ("player", "播放设置", "play.circle"),
    ("lyric_desktop", "桌面歌词", "text.bubble"),
    ("search", "搜索设置", "magnifyingglass"),
    ("list", "列表设置", "list.bullet"),
    ("sync", "同步与备份", "arrow.triangle.2.circlepath"),
    ("backup", "数据备份", "externaldrive"),
    ("other", "其他", "ellipsis.circle"),
  ]

  var body: some View {
    GeometryReader { _ in
      content
    }
  }

  private var content: some View {
    NavigationStack {
      List {
        Section("设置") {
          ForEach(groups, id: \.id) { g in
            Button {
              bridge.send(pageId: pageId, command: "openSettingPage", payload: ["id": g.id])
            } label: {
              HStack(spacing: DS.Space.sm) {
                Image(systemName: g.symbol)
                  .symbolRenderingMode(.hierarchical)
                  .frame(width: 24)
                Text(g.title).foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                  .symbolRenderingMode(.hierarchical)
                  .font(.caption)
                  .foregroundStyle(.tertiary)
              }
            }
          }
        }

        Section("外观") {
          Button {
            bridge.send(pageId: pageId, command: "openSettingPage", payload: ["id": "basic"])
          } label: {
            HStack {
              Text("当前主题").foregroundStyle(.primary)
              Spacer()
              Text(themeName).foregroundStyle(.secondary)
            }
          }
        }

        Section("关于") {
          Button {
            bridge.send(pageId: pageId, command: "openSettingPage", payload: ["id": "version"])
          } label: {
            HStack {
              Text("版本").foregroundStyle(.primary)
              Spacer()
              Text(version).foregroundStyle(.secondary)
            }
          }
          Button {
            bridge.send(pageId: pageId, command: "openSettingPage", payload: ["id": "about"])
          } label: {
            Text("关于洛雪音乐").foregroundStyle(.primary)
          }
        }
      }
      .listStyle(.insetGrouped)
      .navigationTitle("设置")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button {
            bridge.send(pageId: pageId, command: "back")
          } label: {
            Image(systemName: "chevron.left").symbolRenderingMode(.hierarchical)
          }
          .frame(minWidth: DS.minTap, minHeight: DS.minTap)
          .accessibilityLabel("返回")
        }
      }
    }
  }
}
