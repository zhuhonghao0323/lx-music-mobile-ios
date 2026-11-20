import SwiftUI

/// 歌单详情 SwiftUI 实现：顶部切换歌单 + 功能按钮排 + 歌曲列表。
struct SwiftUIMylistView: View {
  let pageId: String
  @ObservedObject private var bridge = PageBridge.shared

  private var state: [String: Any] { bridge.state(pageId) }
  private var listName: String { state["listName"] as? String ?? "歌单" }
  private var songs: [ListSongCell] { ListSongCell.decode(state["songs"] as? String) }
  private var lists: [(id: String, name: String)] {
    guard let raw = state["lists"] as? String, !raw.isEmpty else { return [] }
    return raw.split(separator: "\u{1}").compactMap { seg in
      let parts = seg.split(separator: "|", maxSplits: 1).map(String.init)
      guard parts.count == 2 else { return nil }
      return (parts[0], parts[1])
    }
  }
  private var currentId: String { state["listId"] as? String ?? "" }

  /// 功能按钮（与 RN 版一致）
  private let ops: [(id: String, symbol: String, label: String)] = [
    ("sort", "arrow.up.arrow.down", "排序"),
    ("duplicate", "square.on.square", "重复"),
    ("localFile", "folder.badge.plus", "本地"),
    ("sync", "arrow.triangle.2.circlepath", "更新"),
    ("import", "square.and.arrow.down", "导入"),
    ("export", "square.and.arrow.up", "导出"),
    ("remove", "trash", "移除"),
  ]

  var body: some View {
    GeometryReader { _ in
      content
    }
  }

  private var content: some View {
    NavigationStack {
      VStack(spacing: 0) {
        // 顶部：切换歌单按钮 + 歌单名 + 搜索
        HStack(spacing: DS.Space.sm) {
          Menu {
            ForEach(lists, id: \.id) { l in
              Button {
                bridge.send(pageId: pageId, command: "switchList", payload: ["id": l.id])
              } label: {
                if l.id == currentId {
                  Label(l.name, systemImage: "checkmark")
                } else {
                  Text(l.name)
                }
              }
            }
          } label: {
            HStack(spacing: 4) {
              Image(systemName: "line.3.horizontal").symbolRenderingMode(.hierarchical)
              Text(listName).font(.headline).lineLimit(1)
              Image(systemName: "chevron.down").symbolRenderingMode(.hierarchical).font(.caption)
            }
            .foregroundStyle(.primary)
          }
          .accessibilityLabel("切换歌单")

          Spacer()

          Button {
            bridge.send(pageId: pageId, command: "searchInList")
          } label: {
            Image(systemName: "magnifyingglass").symbolRenderingMode(.hierarchical)
          }
          .frame(minWidth: DS.minTap, minHeight: DS.minTap)
          .accessibilityLabel("搜索歌单内歌曲")
        }
        .padding(.horizontal, DS.Space.md)
        .padding(.vertical, DS.Space.xs)

        // 功能按钮排（横向滚动，按钮风格统一）
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: DS.Space.sm) {
            ForEach(ops, id: \.id) { op in
              Button {
                bridge.send(pageId: pageId, command: "listOp", payload: ["action": op.id, "id": currentId])
              } label: {
                VStack(spacing: 4) {
                  Image(systemName: op.symbol)
                    .symbolRenderingMode(.hierarchical)
                    .frame(width: 40, height: 40)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                  Text(op.label).font(.caption2).foregroundStyle(.secondary)
                }
              }
              .frame(minWidth: 44, minHeight: 44)
            }
          }
          .padding(.horizontal, DS.Space.md)
        }
        .padding(.vertical, DS.Space.xs)

        // 歌曲列表
        List {
          ForEach(Array(songs.enumerated()), id: \.element.id) { idx, song in
            Button {
              bridge.send(pageId: pageId, command: "playSong", payload: ["index": idx])
            } label: {
              HStack(spacing: DS.Space.sm) {
                Text("\(idx + 1)")
                  .font(.caption.monospacedDigit())
                  .foregroundStyle(.secondary)
                  .frame(width: 22, alignment: .trailing)
                VStack(alignment: .leading, spacing: 2) {
                  Text(song.name).font(.body).lineLimit(1)
                  Text(song.singer).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                if !song.interval.isEmpty {
                  Text(song.interval).font(.caption).foregroundStyle(.tertiary)
                }
              }
            }
            .buttonStyle(.plain)
          }
        }
        .listStyle(.plain)
      }
      .navigationBarHidden(true)
    }
  }
}

struct ListSongCell: Identifiable, Decodable {
  let id: String
  let name: String
  let singer: String
  let interval: String
  static func decode(_ json: String?) -> [ListSongCell] {
    guard let json, let d = json.data(using: .utf8) else { return [] }
    return (try? JSONDecoder().decode([ListSongCell].self, from: d)) ?? []
  }
}
