import SwiftUI
import UIKit

// MARK: - 音乐库：歌单墙 + 全部歌曲汇总

/// 音乐库歌单墙上的一格。数据来源可能是账号同步歌单，也可能是本机导入歌单。
struct LibraryWallItem: Identifiable {
    let id: String
    let name: String
    let coverURL: URL?
    let count: Int
    let subtitle: String
    let onOpen: () -> Void
    var onUpdate: (() -> Void)? = nil
    var onRename: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
}

/// 被隐藏的歌单（只影响音乐库展示，不删任何数据）
final class HiddenPlaylistStore: ObservableObject {
    static let shared = HiddenPlaylistStore()

    @Published private(set) var keys: Set<String> = []

    private let storageKey = "beans.library.hiddenPlaylists"

    private init() {
        keys = Set(UserDefaults.standard.stringArray(forKey: storageKey) ?? [])
    }

    func isHidden(_ id: String) -> Bool { keys.contains(id) }

    func hide(_ id: String) {
        keys.insert(id)
        persist()
    }

    func unhide(_ id: String) {
        keys.remove(id)
        persist()
    }

    func unhideAll() {
        keys.removeAll()
        persist()
    }

    private func persist() {
        UserDefaults.standard.set(Array(keys), forKey: storageKey)
    }
}

/// 3 列 × 2 行的横向歌单墙：一屏 6 个，可以一直往右滑。
struct PlaylistWallView: View {
    let items: [LibraryWallItem]

    private let rows = 2
    private let columns = 3
    private let spacing: CGFloat = 12

    var body: some View {
        GeometryReader { proxy in
            let cellWidth = max(72, (proxy.size.width - spacing * CGFloat(columns - 1)) / CGFloat(columns))
            // 行高按「封面 + 标题 + 副标题」实际高度算，避免文字被下一行盖住
            let rowHeight = cellWidth + Self.captionHeight
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHGrid(rows: Array(repeating: GridItem(.fixed(rowHeight), spacing: spacing), count: rows), spacing: spacing) {
                    ForEach(items) { item in
                        card(item, width: cellWidth)
                    }
                }
                .padding(.vertical, 2)
            }
            .frame(height: rowHeight * CGFloat(rows) + spacing * CGFloat(rows - 1) + 4)
        }
        .frame(height: wallHeight)
    }

    /// 标题 + 间距 + 副标题占用的固定高度
    private static let captionHeight: CGFloat = 46

    /// 外部布局用：按屏宽估算两行的高度（与 GeometryReader 内部算法一致）
    private var wallHeight: CGFloat {
        let screenWidth = min(UIScreen.main.bounds.width - 32, 860)
        let cellWidth = max(72, (screenWidth - spacing * CGFloat(columns - 1)) / CGFloat(columns))
        let rowHeight = cellWidth + Self.captionHeight
        return rowHeight * CGFloat(rows) + spacing * CGFloat(rows - 1) + 4
    }

    private func card(_ item: LibraryWallItem, width: CGFloat) -> some View {
        Button {
            BeansHaptics.tap()
            item.onOpen()
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                CoverImage(url: item.coverURL, size: width, cornerRadius: 14)
                Text(item.name)
                    .font(BeansFont.appFont(13, .semibold))
                    .foregroundStyle(Color.beansLabel)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(item.subtitle)
                    .font(BeansFont.appFont(11))
                    .foregroundStyle(Color.beansComment)
                    .lineLimit(1)
            }
            .frame(width: width, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(GlassPressButtonStyle(scale: 0.96))
        .contextMenu {
            if let onUpdate = item.onUpdate {
                Button {
                    BeansHaptics.tap()
                    onUpdate()
                } label: {
                    Label("更新歌单", systemImage: "arrow.clockwise")
                }
            }
            if let onRename = item.onRename {
                Button {
                    BeansHaptics.tap()
                    onRename()
                } label: {
                    Label("重命名", systemImage: "pencil")
                }
            }
            Button {
                BeansHaptics.tap()
                HiddenPlaylistStore.shared.hide(item.id)
                ToastCenter.shared.show("已隐藏「\(item.name)」")
            } label: {
                Label("在音乐库隐藏", systemImage: "eye.slash")
            }
            if let onDelete = item.onDelete {
                Button(role: .destructive) {
                    BeansHaptics.tap()
                    onDelete()
                } label: {
                    Label("删除歌单", systemImage: "trash")
                }
            }
        }
    }
}

/// 「全部歌单」：3 列网格展示所有歌单，可逐个隐藏。
struct LibraryAllPlaylistsSheet: View {
    let items: [LibraryWallItem]
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var hidden = HiddenPlaylistStore.shared

    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    /// 三列网格的单格边长：按屏宽扣除内边距与列间距
    private var gridCellWidth: CGFloat {
        (min(UIScreen.main.bounds.width, 892) - 32 - 28) / 3
    }

    var body: some View {
        BeansNavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 18) {
                    ForEach(items) { item in
                        Button {
                            dismiss()
                            item.onOpen()
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                CoverImage(url: item.coverURL, size: gridCellWidth, cornerRadius: 14)
                                Text(item.name)
                                    .font(BeansFont.appFont(12, .semibold))
                                    .foregroundStyle(Color.beansLabel)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                                Text(item.subtitle)
                                    .font(BeansFont.appFont(10))
                                    .foregroundStyle(Color.beansComment)
                                    .lineLimit(1)
                            }
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            if let onUpdate = item.onUpdate {
                                Button {
                                    dismiss()
                                    onUpdate()
                                } label: {
                                    Label("更新歌单", systemImage: "arrow.clockwise")
                                }
                            }
                            if let onRename = item.onRename {
                                Button {
                                    dismiss()
                                    onRename()
                                } label: {
                                    Label("重命名", systemImage: "pencil")
                                }
                            }
                            Button {
                                hidden.hide(item.id)
                            } label: {
                                Label("隐藏", systemImage: "eye.slash")
                            }
                            if let onDelete = item.onDelete {
                                Button(role: .destructive) {
                                    dismiss()
                                    onDelete()
                                } label: {
                                    Label("删除", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                .padding(16)
                .padding(.bottom, 40)
            }
            .navigationTitle("全部歌单")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}

// MARK: - 全部歌曲（歌单汇总去重）

enum SongLanguageTag {
    /// 没有语言字段，用文字脚本粗略区分：假名 / 韩文 / 汉字 / 其余按欧美
    static func tag(for song: Song) -> String {
        let text = song.name + song.artists + song.album
        if text.range(of: "[\\u3040-\\u30FF]", options: .regularExpression) != nil { return "日语" }
        if text.range(of: "[\\uAC00-\\uD7AF]", options: .regularExpression) != nil { return "韩语" }
        if text.range(of: "[\\u4E00-\\u9FFF]", options: .regularExpression) != nil { return "华语" }
        return "欧美"
    }
}

/// 汇总所有歌单里的歌曲：歌手名 + 歌名相同视为同一首，只留一条。
enum LibrarySongAggregator {
    static func merge(_ groups: [[Song]]) -> [Song] {
        var seen = Set<String>()
        var result: [Song] = []
        for group in groups {
            for song in group {
                let name = song.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                let artist = song.artists.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                guard !name.isEmpty else { continue }
                let key = "\(name)|\(artist)"
                guard seen.insert(key).inserted else { continue }
                result.append(song)
            }
        }
        return result
    }
}

/// 音乐库里的「全部歌曲」区块：默认只露一小部分，点「全部」看完整列表。
struct LibraryAllSongsSection: View {
    @EnvironmentObject private var player: PlayerManager
    let songs: [Song]
    var previewCount: Int = 8
    let onShowAll: () -> Void
    let onPlay: ([Song], Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "全部歌曲", trailing: songs.isEmpty ? nil : "全部 \(songs.count) 首") {
                onShowAll()
            }
            if songs.isEmpty {
                EmptyStateView(icon: "music.note", text: "还没有歌曲\n同步歌单或导入歌单后会汇总到这里")
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(songs.prefix(previewCount).enumerated()), id: \.element.identityKey) { index, song in
                        SongCell(song: song) {
                            onPlay(Array(songs.prefix(previewCount)), index)
                        }
                        if index < min(previewCount, songs.count) - 1 {
                            Divider().overlay(Color.beansComment.opacity(0.12))
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background { BeansGlass(shape: RoundedRectangle(cornerRadius: 22, style: .continuous)) }
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .beansCardShadow(radius: 8, y: 3)
            }
        }
    }
}

/// 全部歌曲页：分页加载 + 按歌手 / 语言筛选，几千首也不会一次渲染卡住。
struct LibraryAllSongsSheet: View {
    @EnvironmentObject private var player: PlayerManager
    @Environment(\.dismiss) private var dismiss

    let songs: [Song]

    @State private var artistFilter: String?
    @State private var languageFilter: String?
    @State private var searchText = ""
    /// 分批渲染：首屏 60 首，滑到底自动加 60
    @State private var visibleCount = 60
    private let pageSize = 60

    /// 歌手 / 语言标签只算一次，避免每次滚动都重新遍历上千首
    private let artistsCache: [String]
    private let languagesCache: [String]
    private let languageMap: [String: String]

    init(songs: [Song]) {
        self.songs = songs
        var counter: [String: Int] = [:]
        var languages = Set<String>()
        var map: [String: String] = [:]
        map.reserveCapacity(songs.count)
        for song in songs {
            for name in song.artists.components(separatedBy: " / ") {
                let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty, trimmed != "未知歌手" else { continue }
                counter[trimmed, default: 0] += 1
            }
            let tag = SongLanguageTag.tag(for: song)
            map[song.identityKey] = tag
            languages.insert(tag)
        }
        artistsCache = counter.sorted { $0.value > $1.value }.prefix(12).map(\.key)
        languagesCache = languages.sorted()
        languageMap = map
    }

    private var filtered: [Song] {
        var list = songs
        if let artistFilter {
            list = list.filter { $0.artists.contains(artistFilter) }
        }
        if let languageFilter {
            list = list.filter { languageMap[$0.identityKey] == languageFilter }
        }
        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !keyword.isEmpty {
            list = list.filter {
                $0.name.lowercased().contains(keyword)
                    || $0.artists.lowercased().contains(keyword)
                    || $0.album.lowercased().contains(keyword)
            }
        }
        return list
    }

    private var shown: [Song] {
        Array(filtered.prefix(visibleCount))
    }

    var body: some View {
        BeansNavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    Text("共 \(filtered.count) 首" + (filtered.count == songs.count ? "" : "（全部 \(songs.count) 首）"))
                        .font(BeansFont.appFont(12, .medium))
                        .foregroundStyle(Color.beansComment)
                        .padding(.horizontal, 16)

                    if !languagesCache.isEmpty {
                        tagRow(title: "语言", values: languagesCache, selection: $languageFilter)
                    }
                    if !artistsCache.isEmpty {
                        tagRow(title: "歌手", values: artistsCache, selection: $artistFilter)
                    }

                    LazyVStack(spacing: 0) {
                        ForEach(Array(shown.enumerated()), id: \.element.identityKey) { index, song in
                            SongCell(song: song) {
                                player.play(songs: filtered, startAt: index)
                            }
                            if index < shown.count - 1 {
                                Divider().overlay(Color.beansComment.opacity(0.12))
                            }
                        }
                        if visibleCount < filtered.count {
                            HStack(spacing: 8) {
                                ProgressView().scaleEffect(0.8)
                                Text("已加载 \(min(visibleCount, filtered.count)) / \(filtered.count) 首")
                                    .font(BeansFont.appFont(11))
                                    .foregroundStyle(Color.beansComment)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .onAppear {
                                visibleCount = min(filtered.count, visibleCount + pageSize)
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background { BeansGlass(shape: RoundedRectangle(cornerRadius: 22, style: .continuous)) }
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 40)
                }
                .padding(.top, 8)
            }
            .searchable(text: $searchText, prompt: "搜索歌名 / 歌手 / 专辑")
            .navigationTitle("全部歌曲")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
            .onChange(of: searchText) { _ in resetPaging() }
            .onChange(of: artistFilter) { _ in resetPaging() }
            .onChange(of: languageFilter) { _ in resetPaging() }
        }
    }

    private func resetPaging() {
        visibleCount = pageSize
    }

    private func tagRow(title: String, values: [String], selection: Binding<String?>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(BeansFont.appFont(12, .semibold))
                .foregroundStyle(Color.beansComment)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    chip("全部", active: selection.wrappedValue == nil) {
                        selection.wrappedValue = nil
                    }
                    ForEach(values, id: \.self) { value in
                        chip(value, active: selection.wrappedValue == value) {
                            selection.wrappedValue = (selection.wrappedValue == value) ? nil : value
                        }
                    }
                }
                .padding(.horizontal, 1)
            }
        }
        .padding(.horizontal, 16)
    }

    private func chip(_ text: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button {
            BeansHaptics.tap()
            action()
        } label: {
            Text(text)
                .font(BeansFont.appFont(12, .medium))
                .foregroundStyle(active ? Color.white : Color.beansLabel)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background {
                    Capsule().fill(active ? Color.beansAmber : Color.beansComment.opacity(0.12))
                }
        }
        .buttonStyle(.plain)
    }
}
