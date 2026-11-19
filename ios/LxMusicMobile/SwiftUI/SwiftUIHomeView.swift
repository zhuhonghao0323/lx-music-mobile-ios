import SwiftUI

/// 主页（歌单发现）SwiftUI 实现。
/// 数据由 RN 推来（JSON），滚动到底部时通知 RN 加载下一页。
struct SwiftUIHomeView: View {
  let pageId: String
  @ObservedObject private var bridge = PageBridge.shared

  private var state: [String: Any] { bridge.state(pageId) }
  private var items: [SonglistCell] { SonglistCell.decode(state["items"] as? String) }
  private var isLoading: Bool { state["loading"] as? Bool ?? false }
  private var hasMore: Bool { state["hasMore"] as? Bool ?? false }
  private var channel: String { state["channel"] as? String ?? "songlist" }

  private let columns = [GridItem(.adaptive(minimum: 100), spacing: DS.Space.sm)]

  var body: some View {
    NavigationStack {
      ScrollView {
        LazyVGrid(columns: columns, spacing: DS.Space.sm) {
          ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
            Button {
              bridge.send(pageId: pageId, command: "openItem", payload: ["id": item.id, "name": item.name])
            } label: {
              cell(item)
            }
            .buttonStyle(.plain)
            .onAppear {
              if index >= items.count - 4 && hasMore && !isLoading {
                bridge.send(pageId: pageId, command: "loadMore")
              }
            }
          }
        }
        .padding(.horizontal, DS.Space.sm)

        if isLoading {
          ProgressView().padding(DS.Space.sm)
        }
      }
      .background(.background)
      .navigationTitle("发现")
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button { bridge.send(pageId: pageId, command: "switchSource") } label: {
            Image(systemName: "music.note.list").symbolRenderingMode(.hierarchical)
          }
          .frame(minWidth: DS.minTap, minHeight: DS.minTap)
          .accessibilityLabel("切换音源")
        }
        ToolbarItem(placement: .topBarTrailing) {
          Button { bridge.send(pageId: pageId, command: "openSearch") } label: {
            Image(systemName: "magnifyingglass").symbolRenderingMode(.hierarchical)
          }
          .frame(minWidth: DS.minTap, minHeight: DS.minTap)
          .accessibilityLabel("搜索")
        }
      }
    }
  }

  private func cell(_ item: SonglistCell) -> some View {
    VStack(alignment: .leading, spacing: DS.Space.xs) {
      Group {
        if let url = URL(string: item.img), !item.img.isEmpty {
          AsyncImage(url: url) { phase in
            if case .success(let img) = phase { img.resizable().scaledToFill() } else { placeholder }
          }
        } else {
          placeholder
        }
      }
      .frame(height: 100)
      .clipShape(RoundedRectangle(cornerRadius: DS.Radius.cover, style: .continuous))

      Text(item.name)
        .font(.footnote)
        .lineLimit(2)
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  private var placeholder: some View {
    ZStack {
      Color.secondary.opacity(0.12)
      Image(systemName: "music.note.list").symbolRenderingMode(.hierarchical).foregroundStyle(.tertiary)
    }
  }
}

struct SonglistCell: Identifiable, Decodable {
  let id: String
  let name: String
  let img: String

  static func decode(_ json: String?) -> [SonglistCell] {
    guard let json, let data = json.data(using: .utf8) else { return [] }
    return (try? JSONDecoder().decode([SonglistCell].self, from: data)) ?? []
  }
}
