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
  private var sourceName: String { state["sourceName"] as? String ?? "音源" }
  /// 可用音源列表（RN 推送 "id|名称" 用 \u0001 连接）
  private var sources: [(id: String, name: String)] {
    guard let raw = state["sources"] as? String, !raw.isEmpty else { return [] }
    return raw.split(separator: "\u{1}").compactMap { seg in
      let parts = seg.split(separator: "|", maxSplits: 1).map(String.init)
      guard parts.count == 2 else { return nil }
      return (parts[0], parts[1])
    }
  }
  /// 排序项
  private var sorts: [(id: String, name: String)] {
    guard let raw = state["sorts"] as? String, !raw.isEmpty else { return [] }
    return raw.split(separator: "\u{1}").compactMap { seg in
      let parts = seg.split(separator: "|", maxSplits: 1).map(String.init)
      guard parts.count == 2 else { return nil }
      return (parts[0], parts[1])
    }
  }
  private var currentSortId: String { state["sortId"] as? String ?? "" }
  private var currentTagName: String { state["tagName"] as? String ?? "" }

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
          Menu {
            ForEach(sources, id: \.id) { src in
              Button {
                bridge.send(pageId: pageId, command: "selectSource", payload: ["source": src.id])
              } label: {
                if src.id.uppercased() == sourceName.uppercased() {
                  Label(src.name, systemImage: "checkmark")
                } else {
                  Text(src.name)
                }
              }
            }
          } label: {
            Label(sourceName, systemImage: "music.note.list")
              .labelStyle(.titleAndIcon)
              .font(.subheadline)
          }
          .accessibilityLabel("切换音源")
        }
        ToolbarItem(placement: .principal) {
          // 频道切换：歌单 / 排行榜（与 RN 版一致）
          Picker("频道", selection: Binding(
            get: { channel },
            set: { bridge.send(pageId: pageId, command: "switchChannel", payload: ["channel": $0]) }
          )) {
            Text("歌单").tag("songlist")
            Text("排行榜").tag("top")
          }
          .pickerStyle(.segmented)
          .frame(width: 160)
        }
        ToolbarItem(placement: .topBarTrailing) {
          HStack(spacing: 0) {
            // 排序 / 分类筛选
            Menu {
              Section("排序") {
                ForEach(sorts, id: \.id) { srt in
                  Button {
                    bridge.send(pageId: pageId, command: "selectSort", payload: ["sortId": srt.id])
                  } label: {
                    if srt.id == currentSortId {
                      Label(srt.name, systemImage: "checkmark")
                    } else {
                      Text(srt.name)
                    }
                  }
                }
              }
              Section("分类") {
                Button {
                  bridge.send(pageId: pageId, command: "openTagPicker")
                } label: {
                  Label(currentTagName.isEmpty ? "全部分类" : currentTagName,
                        systemImage: "line.3.horizontal.decrease.circle")
                }
              }
            } label: {
              Image(systemName: "line.3.horizontal.decrease").symbolRenderingMode(.hierarchical)
            }
            .accessibilityLabel("排序与分类")

            Button { bridge.send(pageId: pageId, command: "openSearch") } label: {
              Image(systemName: "magnifyingglass").symbolRenderingMode(.hierarchical)
            }
            .frame(minWidth: DS.minTap, minHeight: DS.minTap)
            .accessibilityLabel("搜索")
          }
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
