import SwiftUI

/// 排行榜 SwiftUI 实现：左侧榜单列表 + 右侧歌曲列表。
struct SwiftUILeaderboardView: View {
  let pageId: String
  @ObservedObject private var bridge = PageBridge.shared

  private var state: [String: Any] { bridge.state(pageId) }
  private var boards: [BoardCell] { BoardCell.decode(state["boards"] as? String) }
  private var songs: [SongCell] { SongCell.decode(state["songs"] as? String) }
  private var currentBoardId: String { state["boardId"] as? String ?? "" }
  private var loading: Bool { state["loading"] as? Bool ?? false }

  var body: some View {
    NavigationStack {
      List {
        Section("榜单") {
          ForEach(boards) { board in
            Button {
              bridge.send(pageId: pageId, command: "selectBoard", payload: ["id": board.id])
            } label: {
              HStack {
                Text(board.name).foregroundStyle(.primary)
                Spacer()
                if board.id == currentBoardId {
                  Image(systemName: "checkmark").symbolRenderingMode(.hierarchical)
                }
              }
            }
          }
        }

        Section("歌曲") {
          if loading && songs.isEmpty {
            ProgressView().frame(maxWidth: .infinity)
          }
          ForEach(Array(songs.enumerated()), id: \.element.id) { idx, song in
            Button {
              bridge.send(pageId: pageId, command: "playSong", payload: ["index": idx])
            } label: {
              HStack(spacing: DS.Space.xs) {
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
      }
      .listStyle(.insetGrouped)
      .navigationTitle("排行榜")
      .navigationBarTitleDisplayMode(.inline)
      .refreshable {
        bridge.send(pageId: pageId, command: "refresh")
      }
    }
  }
}

struct BoardCell: Identifiable, Decodable {
  let id: String
  let name: String
  static func decode(_ json: String?) -> [BoardCell] {
    guard let json, let d = json.data(using: .utf8) else { return [] }
    return (try? JSONDecoder().decode([BoardCell].self, from: d)) ?? []
  }
}

struct SongCell: Identifiable, Decodable {
  let id: String
  let name: String
  let singer: String
  let interval: String
  static func decode(_ json: String?) -> [SongCell] {
    guard let json, let d = json.data(using: .utf8) else { return [] }
    return (try? JSONDecoder().decode([SongCell].self, from: d)) ?? []
  }
}
