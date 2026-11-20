import SwiftUI

/// 「我的」页 SwiftUI 实现。
///
/// 数据由 RN 通过 PageBridge 推送（统计 + 歌单 JSON 串），
/// 用户操作经 PageBridge.send 回传 RN 执行，业务逻辑不在此实现。
struct SwiftUIMineView: View {
  let pageId: String
  @ObservedObject private var bridge = PageBridge.shared

  private var state: [String: Any] { bridge.state(pageId) }

  private var favoriteCount: Int { state["favoriteCount"] as? Int ?? 0 }
  private var playlistCount: Int { state["playlistCount"] as? Int ?? 0 }
  private var totalPlayTime: String { state["totalPlayTime"] as? String ?? "--" }
  private var lists: [PlaylistItem] { PlaylistItem.decode(state["lists"] as? String) }

  var body: some View {
    GeometryReader { geo in
      content
        .overlay {
          LXDebugOverlay(lines: [
            "MINE geo: w=\(Int(geo.size.width)) h=\(Int(geo.size.height))",
            LXDiagInsets(),
          ])
        }
    }
  }

  private var content: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 0) {
          statsRow
          DSSectionHeader("我的歌单", trailing: AnyView(createButton))
          playlistGrid
        }
      }
      .background(.background)
      .navigationTitle("我的")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button { bridge.send(pageId: pageId, command: "openSetting") } label: {
            Image(systemName: "gearshape").symbolRenderingMode(.hierarchical)
          }
          .frame(minWidth: DS.minTap, minHeight: DS.minTap)
          .accessibilityLabel("设置")
        }
      }
    }
  }

  // MARK: - 统计
  private var statsRow: some View {
    HStack(spacing: 0) {
      statCell("\(favoriteCount)", "收藏歌曲")
      Divider().frame(height: 32)
      statCell("\(playlistCount)", "我的歌单")
      Divider().frame(height: 32)
      statCell(totalPlayTime, "累计播放")
    }
    .padding(.vertical, DS.Space.sm)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
    .padding(.horizontal, DS.Space.sm)
    .padding(.top, DS.Space.sm)
  }

  private func statCell(_ value: String, _ label: String) -> some View {
    VStack(spacing: 4) {
      Text(value)
        .font(value.count > 4 ? .subheadline.weight(.semibold) : .title2.weight(.bold))
        .lineLimit(1)
        .minimumScaleFactor(0.6)
      Text(label).font(.caption).foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity)
  }

  // MARK: - 新建按钮
  private var createButton: some View {
    Button { bridge.send(pageId: pageId, command: "createList") } label: {
      Image(systemName: "plus").symbolRenderingMode(.hierarchical)
    }
    .frame(minWidth: DS.minTap, minHeight: DS.minTap)
    .accessibilityLabel("新建列表")
  }

  // MARK: - 歌单网格
  private var playlistGrid: some View {
    let columns = [GridItem(.adaptive(minimum: 104), spacing: DS.Space.sm)]
    return LazyVGrid(columns: columns, spacing: DS.Space.sm) {
      ForEach(lists) { item in
        Button {
          bridge.send(pageId: pageId, command: "openList", payload: ["id": item.id])
        } label: {
          playlistCell(item)
        }
        .buttonStyle(.plain)
        .contextMenu {
          Button("添加本地") { bridge.send(pageId: pageId, command: "listOp", payload: ["action": "localFile", "id": item.id]) }
          Button("更新") { bridge.send(pageId: pageId, command: "listOp", payload: ["action": "sync", "id": item.id]) }
          Button("导入") { bridge.send(pageId: pageId, command: "listOp", payload: ["action": "import", "id": item.id]) }
          Button("导出") { bridge.send(pageId: pageId, command: "listOp", payload: ["action": "export", "id": item.id]) }
          Button("移除", role: .destructive) { bridge.send(pageId: pageId, command: "listOp", payload: ["action": "remove", "id": item.id]) }
        }
      }
    }
    .padding(.horizontal, DS.Space.sm)
  }

  private func playlistCell(_ item: PlaylistItem) -> some View {
    VStack(alignment: .leading, spacing: DS.Space.xs) {
      ZStack(alignment: .bottomTrailing) {
        coverImage(item)
          .frame(width: 100, height: 100)
          .clipShape(RoundedRectangle(cornerRadius: DS.Radius.cover, style: .continuous))
        Text("\(item.count)")
          .font(.caption2.weight(.semibold))
          .padding(.horizontal, 6)
          .padding(.vertical, 2)
          .background(.ultraThinMaterial, in: Capsule())
          .padding(6)
      }
      Text(item.name)
        .font(.footnote)
        .lineLimit(2)
        .multilineTextAlignment(.leading)
    }
  }

  @ViewBuilder
  private func coverImage(_ item: PlaylistItem) -> some View {
    if let urlStr = item.cover, let url = URL(string: urlStr) {
      AsyncImage(url: url) { phase in
        if case .success(let img) = phase {
          img.resizable().scaledToFill()
        } else {
          placeholderCover
        }
      }
    } else {
      placeholderCover
    }
  }

  private var placeholderCover: some View {
    ZStack {
      Color.secondary.opacity(0.12)
      Image(systemName: "music.note.list")
        .symbolRenderingMode(.hierarchical)
        .foregroundStyle(.tertiary)
    }
  }
}

/// 歌单数据（RN 侧序列化为 JSON 串推送）
struct PlaylistItem: Identifiable, Decodable {
  let id: String
  let name: String
  let count: Int
  let cover: String?

  static func decode(_ json: String?) -> [PlaylistItem] {
    guard let json, let data = json.data(using: .utf8) else { return [] }
    return (try? JSONDecoder().decode([PlaylistItem].self, from: data)) ?? []
  }
}
