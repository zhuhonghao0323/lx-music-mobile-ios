import SwiftUI
import UIKit

// MARK: - 全屏子页返回（左上角按钮 + 从左往右手势）

/// 全屏页面的左上角返回按钮，外观与主页返回一致
struct LibraryBackButton: View {
    let action: () -> Void
    var body: some View {
        Button {
            BeansHaptics.tap()
            action()
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                Text("返回")
                    .font(BeansFont.appFont(14))
            }
            .foregroundStyle(Color.beansAmber)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// 从左往右滑（dx>0）返回，用于全屏子页
private struct LibrarySwipeBackModifier: ViewModifier {
    let action: () -> Void
    func body(content: Content) -> some View {
        content.gesture(
            DragGesture(minimumDistance: 40)
                .onEnded { value in
                    let dx = value.translation.width
                    let vx = value.predictedEndTranslation.width
                    guard dx > 90 || vx > 220,
                          abs(dx) > abs(value.translation.height) else { return }
                    BeansHaptics.tap()
                    action()
                }
        )
    }
}

extension View {
    func librarySwipeBack(_ action: @escaping () -> Void) -> some View {
        modifier(LibrarySwipeBackModifier(action: action))
    }
}

// MARK: - 音乐库：歌单墙 + 全部歌曲汇总

/// 歌单封面上的来源平台徽章
struct LibraryWallBadge {
    let title: String
    let symbol: String?
    let brandImage: String?
    let tint: Color
}

/// 音乐库歌单墙上的一格。数据来源可能是账号同步歌单，也可能是本机导入歌单。
struct LibraryWallItem: Identifiable {
    let id: String
    let name: String
    let coverURL: URL?
    let count: Int
    let subtitle: String
    var badge: LibraryWallBadge? = nil
    var platformKey: String = ""
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

    private func badgeView(_ badge: LibraryWallBadge) -> some View {
        LibraryPlatformBadgeView(badge: badge, compact: true)
    }

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
                ZStack(alignment: .bottomTrailing) {
                    CoverImage(url: item.coverURL, size: width, cornerRadius: 14)
                    if let badge = item.badge {
                        badgeView(badge)
                            .padding(5)
                    }
                }
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

    /// nil = 全部平台
    @State private var platformFilter: String? = nil
    /// 管理模式：批量隐藏 / 恢复隐藏
    @State private var manageMode = false
    @State private var managedHidden: Set<String> = []
    @State private var showHiddenOnly = false

    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    /// 三列网格的单格边长：按屏宽扣除内边距与列间距
    private var gridCellWidth: CGFloat {
        (min(UIScreen.main.bounds.width, 892) - 32 - 28) / 3
    }

    /// 平台筛选：按出现顺序去重
    private var platforms: [(key: String, badge: LibraryWallBadge)] {
        var seen = Set<String>()
        var result: [(String, LibraryWallBadge)] = []
        for item in items {
            guard let badge = item.badge, !item.platformKey.isEmpty else { continue }
            guard seen.insert(item.platformKey).inserted else { continue }
            result.append((item.platformKey, badge))
        }
        return result
    }

    private var filteredItems: [LibraryWallItem] {
        guard let platformFilter else { return items }
        return items.filter { $0.platformKey == platformFilter }
    }

    var body: some View {
        BeansNavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if platforms.count > 1 {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                filterChip(title: "全部", tint: Color.beansAmber, active: platformFilter == nil) {
                                    platformFilter = nil
                                }
                                ForEach(Array(platforms.enumerated()), id: \.offset) { _, entry in
                                    filterChip(title: entry.badge.title, tint: entry.badge.tint, active: platformFilter == entry.key) {
                                        platformFilter = (platformFilter == entry.key) ? nil : entry.key
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }

                    LazyVGrid(columns: columns, alignment: .leading, spacing: 18) {
                        ForEach(filteredItems) { item in
                            ZStack(alignment: .topLeading) {
                                Button {
                                    if manageMode {
                                        BeansHaptics.tap()
                                        if managedHidden.contains(item.id) {
                                            managedHidden.remove(item.id)
                                        } else {
                                            managedHidden.insert(item.id)
                                        }
                                    } else {
                                        dismiss()
                                        item.onOpen()
                                    }
                                } label: {
                                    VStack(alignment: .leading, spacing: 6) {
                                        ZStack(alignment: .bottomTrailing) {
                                            CoverImage(url: item.coverURL, size: gridCellWidth, cornerRadius: 14)
                                            if let badge = item.badge {
                                                LibraryPlatformBadgeView(badge: badge, compact: true)
                                                    .padding(5)
                                            }
                                        }
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
                                    .opacity(manageMode && !managedHidden.contains(item.id) ? 0.55 : 1)
                                }
                                .buttonStyle(.plain)
                                if manageMode {
                                    Image(systemName: managedHidden.contains(item.id) ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 22))
                                        .foregroundStyle(managedHidden.contains(item.id) ? Color.beansAmber : Color.beansComment.opacity(0.6))
                                        .shadow(radius: 2)
                                        .padding(4)
                                }
                            }
                            .contextMenu {
                                if !manageMode {
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
                                        ToastCenter.shared.show("已隐藏「\(item.name)」")
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
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.top, 10)
                .padding(.bottom, 40)
            }
            .navigationTitle(manageMode ? "管理歌单" : "全部歌单")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    LibraryBackButton { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(manageMode ? "完成" : "管理") {
                        BeansHaptics.tap()
                        withAnimation {
                            manageMode.toggle()
                            managedHidden.removeAll()
                        }
                    }
                    .font(BeansFont.appFont(14, .semibold))
                    .foregroundStyle(Color.beansAmber)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if manageMode {
                    VStack(spacing: 8) {
                        HStack(spacing: 10) {
                            Button {
                                BeansHaptics.tap()
                                for id in managedHidden { hidden.hide(id) }
                                let n = managedHidden.count
                                managedHidden.removeAll()
                                ToastCenter.shared.show(n > 0 ? "已隐藏 \(n) 个歌单" : "请先选择歌单")
                            } label: {
                                Label("隐藏所选", systemImage: "eye.slash")
                                    .font(BeansFont.appFont(13, .semibold))
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Color.beansAmber)

                            Button {
                                BeansHaptics.tap()
                                hidden.unhideAll()
                                ToastCenter.shared.show("已恢复显示全部隐藏歌单")
                            } label: {
                                Label("恢复全部隐藏", systemImage: "eye")
                                    .font(BeansFont.appFont(13, .semibold))
                            }
                            .buttonStyle(.bordered)
                            .tint(Color.beansAmber)
                        }
                        if !hidden.keys.isEmpty {
                            Text("当前有 \(hidden.keys.count) 个歌单被隐藏")
                                .font(BeansFont.appFont(11))
                                .foregroundStyle(Color.beansComment)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.regularMaterial)
                }
            }
        }
        .librarySwipeBack { dismiss() }
    }

    private func filterChip(title: String, tint: Color, active: Bool, action: @escaping () -> Void) -> some View {
        Button {
            BeansHaptics.tap()
            action()
        } label: {
            Text(title)
                .font(BeansFont.appFont(12, .semibold))
                .foregroundStyle(active ? .white : Color.beansLabel)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(active ? tint : Color.beansComment.opacity(0.12)))
        }
        .buttonStyle(.plain)
    }
}

/// 平台来源徽章：品牌图片优先，其次 SF Symbol
struct LibraryPlatformBadgeView: View {
    let badge: LibraryWallBadge
    var compact: Bool = false

    var body: some View {
        HStack(spacing: compact ? 3 : 4) {
            if let brand = badge.brandImage {
                Image(brand)
                    .resizable()
                    .scaledToFit()
                    .frame(width: compact ? 9 : 11, height: compact ? 9 : 11)
            } else if let symbol = badge.symbol {
                Image(systemName: symbol)
                    .font(.system(size: compact ? 7 : 9, weight: .bold))
            }
            Text(badge.title)
                .font(BeansFont.appFont(compact ? 8 : 9, .semibold))
                .lineLimit(1)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, compact ? 5 : 6)
        .padding(.vertical, compact ? 2.5 : 3)
        .background(Capsule().fill(badge.tint.opacity(0.94)))
        .overlay {
            Capsule().strokeBorder(.white.opacity(0.22), lineWidth: 0.5)
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
    @EnvironmentObject private var theme: ThemeStore
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var localLibrary = LocalLibraryStore.shared

    let songs: [Song]

    @State private var artistFilter: String?
    @State private var languageFilter: String?
    @State private var searchText = ""
    /// 分批渲染：首屏 60 首，滑到底自动加 60
    @State private var visibleCount = 60
    private let pageSize = 60

    // 批量管理
    @State private var selectionMode = false
    @State private var selected: Set<String> = []
    @State private var showAddToLocal = false
    @State private var showDedupeConfirm = false
    @State private var dedupeResult: String?

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
                            HStack(spacing: 8) {
                                if selectionMode {
                                    Image(systemName: selected.contains(song.identityKey) ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 20))
                                        .foregroundStyle(selected.contains(song.identityKey) ? Color.beansAmber : Color.beansComment.opacity(0.5))
                                        .onTapGesture {
                                            BeansHaptics.tap()
                                            if selected.contains(song.identityKey) {
                                                selected.remove(song.identityKey)
                                            } else {
                                                selected.insert(song.identityKey)
                                            }
                                        }
                                }
                                SongCell(song: song) {
                                    if selectionMode {
                                        if selected.contains(song.identityKey) {
                                            selected.remove(song.identityKey)
                                        } else {
                                            selected.insert(song.identityKey)
                                        }
                                    } else {
                                        player.play(songs: filtered, startAt: index)
                                    }
                                }
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
            .navigationTitle(selectionMode ? "已选 \(selected.count) 首" : "全部歌曲")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    LibraryBackButton { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 8) {
                        if selectionMode {
                            Button("全选") {
                                BeansHaptics.tap()
                                if selected.count == filtered.count {
                                    selected.removeAll()
                                } else {
                                    selected = Set(filtered.map(\.identityKey))
                                }
                            }
                            .font(BeansFont.appFont(13, .semibold))
                            .foregroundStyle(Color.beansAmber)
                        }
                        Menu {
                            Button {
                                BeansHaptics.tap()
                                withAnimation { selectionMode.toggle() }
                                if !selectionMode { selected.removeAll() }
                            } label: {
                                Label(selectionMode ? "退出多选" : "批量选择", systemImage: "checkmark.circle")
                            }
                            Button {
                                BeansHaptics.tap()
                                showDedupeConfirm = true
                            } label: {
                                Label("清除重复歌曲", systemImage: "wand.and.stars")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.system(size: 18))
                                .foregroundStyle(Color.beansAmber)
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if selectionMode && !selected.isEmpty {
                    HStack(spacing: 12) {
                        Button {
                            BeansHaptics.tap()
                            let list = filtered.filter { selected.contains($0.identityKey) }
                            let added = player.appendToQueue(list)
                            ToastCenter.shared.show(added > 0 ? "已加入播放列表 \(added) 首" : "播放列表中没有新增歌曲")
                        } label: {
                            Label("加入播放列表", systemImage: "music.note.list")
                                .font(BeansFont.appFont(13, .semibold))
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.beansAmber)

                        Button {
                            BeansHaptics.tap()
                            showAddToLocal = true
                        } label: {
                            Label("存入本地歌单", systemImage: "square.and.arrow.down")
                                .font(BeansFont.appFont(13, .semibold))
                        }
                        .buttonStyle(.bordered)
                        .tint(Color.beansAmber)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.regularMaterial)
                }
            }
            .sheet(isPresented: $showAddToLocal) {
                CopyToLocalPlaylistSheet(
                    songs: filtered.filter { selected.contains($0.identityKey) },
                    suggestedName: "我的收藏歌单"
                )
                .environmentObject(theme)
            }
            .alert("清除重复歌曲", isPresented: $showDedupeConfirm) {
                Button("清除", role: .destructive) { dedupeLocalSongs() }
                Button("取消", role: .cancel) {}
            } message: {
                Text("将扫描所有本地歌单，删除歌名与歌手相同的重复歌曲。此操作只影响本地歌单，不影响平台账号。")
            }
            .alert("去重完成", isPresented: Binding(
                get: { dedupeResult != nil },
                set: { if !$0 { dedupeResult = nil } }
            )) {
                Button("好的", role: .cancel) {}
            } message: {
                Text(dedupeResult ?? "")
            }
            .onChange(of: searchText) { _ in resetPaging() }
            .onChange(of: artistFilter) { _ in resetPaging() }
            .onChange(of: languageFilter) { _ in resetPaging() }
        }
        .librarySwipeBack { dismiss() }
    }

    private func dedupeLocalSongs() {
        var removed = 0
        for pl in localLibrary.playlists {
            var seen = Set<String>()
            var kept: [Song] = []
            for song in pl.songs {
                let name = song.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                let artist = song.artists.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                let key = "\(name)|\(artist)"
                if seen.insert(key).inserted {
                    kept.append(song)
                } else {
                    removed += 1
                }
            }
            if kept.count != pl.songs.count {
                // 直接重建该歌单内容
                localLibrary.replaceSongs(kept, in: pl.id)
            }
        }
        dedupeResult = removed == 0 ? "没有发现重复歌曲" : "已清除 \(removed) 首重复歌曲"
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
