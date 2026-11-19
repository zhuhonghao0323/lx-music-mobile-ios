import SwiftUI

/// 搜索页 SwiftUI 实现：系统搜索框 + 历史/热搜 chip + 结果列表。
struct SwiftUISearchView: View {
  let pageId: String
  @ObservedObject private var bridge = PageBridge.shared
  @State private var keyword: String = ""

  private var state: [String: Any] { bridge.state(pageId) }
  private var history: [String] { (state["history"] as? String).flatMap { $0.split(separator: "\u{1}").map(String.init) } ?? [] }
  private var hots: [String] { (state["hots"] as? String).flatMap { $0.split(separator: "\u{1}").map(String.init) } ?? [] }
  private var results: [SongResultCell] { SongResultCell.decode(state["results"] as? String) }
  private var searching: Bool { state["searching"] as? Bool ?? false }
  private var hasKeyword: Bool { state["hasKeyword"] as? Bool ?? false }

  var body: some View {
    NavigationStack {
      Group {
        if hasKeyword {
          resultList
        } else {
          discoverList
        }
      }
      .navigationTitle("搜索")
      .navigationBarTitleDisplayMode(.inline)
      .searchable(text: $keyword, prompt: "搜索歌曲、歌手、歌单")
      .onSubmit(of: .search) {
        bridge.send(pageId: pageId, command: "search", payload: ["keyword": keyword])
      }
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button { bridge.send(pageId: pageId, command: "switchSource") } label: {
            Image(systemName: "line.3.horizontal.decrease.circle").symbolRenderingMode(.hierarchical)
          }
          .frame(minWidth: DS.minTap, minHeight: DS.minTap)
          .accessibilityLabel("切换音源")
        }
      }
    }
  }

  // MARK: - 发现（历史 + 热搜）
  private var discoverList: some View {
    List {
      if !history.isEmpty {
        Section {
          ForEach(history, id: \.self) { word in
            Button { keyword = word; runSearch(word) } label: {
              Label(word, systemImage: "clock.arrow.circlepath")
                .font(.body)
            }
          }
        } header: {
          HStack {
            Text("搜索历史")
            Spacer()
            Button("清空") { bridge.send(pageId: pageId, command: "clearHistory") }
              .font(.caption)
          }
        }
      }
      if !hots.isEmpty {
        Section("热门搜索") {
          ForEach(Array(hots.enumerated()), id: \.offset) { index, word in
            Button { keyword = word; runSearch(word) } label: {
              HStack(spacing: DS.Space.xs) {
                Text("\(index + 1)")
                  .font(.caption.weight(.bold))
                  .foregroundStyle(index < 3 ? Color.accentColor : Color.secondary)
                  .frame(width: 20, alignment: .leading)
                Text(word).font(.body).foregroundStyle(.primary)
              }
            }
          }
        }
      }
    }
    .listStyle(.insetGrouped)
  }

  private func runSearch(_ word: String) {
    bridge.send(pageId: pageId, command: "search", payload: ["keyword": word])
  }

  // MARK: - 结果
  private var resultList: some View {
    Group {
      if searching {
        ProgressView("搜索中…").frame(maxWidth: .infinity, maxHeight: .infinity)
      } else if results.isEmpty {
        DSEmptyState(symbol: "magnifyingglass", title: "没有找到结果")
      } else {
        List(results) { item in
          Button {
            bridge.send(pageId: pageId, command: "playResult", payload: ["index": item.index])
          } label: {
            HStack(spacing: DS.Space.sm) {
              VStack(alignment: .leading, spacing: 4) {
                Text(item.name).font(.body).lineLimit(1)
                Text(item.singer).font(.caption).foregroundStyle(.secondary).lineLimit(1)
              }
              Spacer()
              if let dur = item.duration, !dur.isEmpty {
                Text(dur).font(.caption).foregroundStyle(.tertiary)
              }
            }
          }
          .buttonStyle(.plain)
        }
        .listStyle(.plain)
      }
    }
  }
}

struct SongResultCell: Identifiable, Decodable {
  let index: Int
  let id: String
  let name: String
  let singer: String
  let duration: String?

  static func decode(_ json: String?) -> [SongResultCell] {
    guard let json, let data = json.data(using: .utf8) else { return [] }
    return (try? JSONDecoder().decode([SongResultCell].self, from: data)) ?? []
  }
}
