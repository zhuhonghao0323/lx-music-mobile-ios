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
    /// id → 歌单名：管理页的「已隐藏」列表要靠它显示名字，才能逐个恢复
    @Published private(set) var names: [String: String] = [:]

    private let storageKey = "beans.library.hiddenPlaylists"
    private let namesKey = "beans.library.hiddenPlaylistNames"

    private init() {
        keys = Set(UserDefaults.standard.stringArray(forKey: storageKey) ?? [])
        names = UserDefaults.standard.dictionary(forKey: namesKey) as? [String: String] ?? [:]
    }

    func isHidden(_ id: String) -> Bool { keys.contains(id) }

    func name(for id: String) -> String { names[id] ?? "已隐藏歌单" }

    func hide(_ id: String, name: String? = nil) {
        keys.insert(id)
        if let name, !name.isEmpty { names[id] = name }
        persist()
    }

    func unhide(_ id: String) {
        keys.remove(id)
        names.removeValue(forKey: id)
        persist()
    }

    func unhideAll() {
        keys.removeAll()
        names.removeAll()
        persist()
    }

    private func persist() {
        UserDefaults.standard.set(Array(keys), forKey: storageKey)
        UserDefaults.standard.set(names, forKey: namesKey)
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

/// 「全部歌单」：3 列网格展示所有歌单。
/// 支持搜索 / 平台筛选 / 排序 / 批量隐藏 / 单个删除 / 已隐藏歌单恢复。
struct LibraryAllPlaylistsSheet: View {
    let items: [LibraryWallItem]
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var hidden = HiddenPlaylistStore.shared

    /// nil = 全部平台
    @State private var platformFilter: String? = nil
    @State private var searchText = ""
    @State private var sortMode: AllPlaylistSort = .standard
    /// 管理模式：批量隐藏 / 删除
    @State private var manageMode = false
    @State private var selection: Set<String> = []
    @State private var showHiddenList = false
    @State private var pendingDelete: LibraryWallItem?
    @State private var showDeleteConfirm = false

    private enum AllPlaylistSort: String, CaseIterable, Identifiable {
        case standard = "默认顺序"
        case name = "按名称"
        case count = "按歌曲数"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .standard: return "arrow.up.arrow.down"
            case .name: return "textformat.abc"
            case .count: return "music.note.list"
            }
        }
    }

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
        var list = items
        if let platformFilter {
            list = list.filter { $0.platformKey == platformFilter }
        }
        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !keyword.isEmpty {
            list = list.filter { $0.name.localizedCaseInsensitiveContains(keyword) }
        }
        switch sortMode {
        case .standard:
            break
        case .name:
            list.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        case .count:
            list.sort { $0.count > $1.count }
        }
        return list
    }

    var body: some View {
        BeansNavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    searchField
                    if platforms.count > 1 { platformChips }
                    if filteredItems.isEmpty {
                        emptyState
                    } else {
                        grid
                    }
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
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Menu {
                        ForEach(AllPlaylistSort.allCases) { mode in
                            Button {
                                BeansHaptics.tap()
                                sortMode = mode
                            } label: {
                                Label {
                                    Text(verbatim: mode.rawValue)
                                } icon: {
                                    Image(systemName: sortMode == mode ? "checkmark" : mode.icon)
                                }
                            }
                        }
                        Divider()
                        Button {
                            BeansHaptics.tap()
                            manageMode = false
                            showHiddenList = true
                        } label: {
                            Label {
                                Text(verbatim: hidden.keys.isEmpty ? "已隐藏歌单" : "已隐藏歌单（\(hidden.keys.count)）")
                            } icon: {
                                Image(systemName: "eye.slash")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.beansAmber)
                    }
                    Button(manageMode ? "完成" : "管理") {
                        BeansHaptics.tap()
                        withAnimation {
                            manageMode.toggle()
                            selection.removeAll()
                        }
                    }
                    .font(BeansFont.appFont(14, .semibold))
                    .foregroundStyle(Color.beansAmber)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if manageMode { manageBar }
            }
            .sheet(isPresented: $showHiddenList) {
                hiddenListSheet
            }
            .confirmationDialog(
                "删除这个歌单？",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("删除「\(pendingDelete?.name ?? "歌单")」", role: .destructive) {
                    guard let item = pendingDelete else { return }
                    pendingDelete = nil
                    dismiss()
                    item.onDelete?()
                }
                Button("取消", role: .cancel) { pendingDelete = nil }
            } message: {
                Text("会同时删除平台上的这个歌单，无法撤销。只想在音乐库里不显示，请用「隐藏」。")
            }
        }
        .librarySwipeBack { dismiss() }
    }

    // MARK: - 搜索 / 分类

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.beansComment)
            TextField("搜索歌单名称", text: $searchText)
                .font(BeansFont.appFont(13))
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .submitLabel(.search)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.beansComment.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Capsule().fill(Color.primary.opacity(0.06)))
        .padding(.horizontal, 16)
    }

    private var platformChips: some View {
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

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: searchText.isEmpty ? "square.stack.3d.up" : "magnifyingglass")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(Color.beansComment.opacity(0.55))
            Text(searchText.isEmpty ? "这个分类下还没有歌单" : "没有匹配「\(searchText)」的歌单")
                .font(BeansFont.appFont(13))
                .foregroundStyle(Color.beansComment)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    // MARK: - 网格

    private var grid: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 18) {
            ForEach(filteredItems) { item in
                ZStack(alignment: .topLeading) {
                    Button {
                        if manageMode {
                            BeansHaptics.tap()
                            if selection.contains(item.id) {
                                selection.remove(item.id)
                            } else {
                                selection.insert(item.id)
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
                        .opacity(manageMode && !selection.contains(item.id) ? 0.55 : 1)
                    }
                    .buttonStyle(.plain)
                    if manageMode {
                        Image(systemName: selection.contains(item.id) ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 22))
                            .foregroundStyle(selection.contains(item.id) ? Color.beansAmber : Color.beansComment.opacity(0.6))
                            .shadow(radius: 2)
                            .padding(4)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if manageMode {
                        Button {
                            BeansHaptics.tap()
                            pendingDelete = item
                            showDeleteConfirm = true
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(6)
                                .background(Circle().fill(Color.black.opacity(0.5)))
                        }
                        .buttonStyle(.plain)
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
                            hidden.hide(item.id, name: item.name)
                            ToastCenter.shared.show("已隐藏「\(item.name)」，可在右上角恢复")
                        } label: {
                            Label("隐藏", systemImage: "eye.slash")
                        }
                        if item.onDelete != nil {
                            Button(role: .destructive) {
                                pendingDelete = item
                                showDeleteConfirm = true
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

    // MARK: - 管理栏

    private var manageBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Button {
                    BeansHaptics.tap()
                    if !filteredItems.isEmpty, selection.count == filteredItems.count {
                        selection.removeAll()
                    } else {
                        selection = Set(filteredItems.map { $0.id })
                    }
                } label: {
                    Label(
                        (!filteredItems.isEmpty && selection.count == filteredItems.count) ? "取消全选" : "全选",
                        systemImage: "checklist"
                    )
                    .font(BeansFont.appFont(13, .semibold))
                }
                .buttonStyle(.bordered)
                .tint(Color.beansAmber)

                Spacer(minLength: 0)

                Text("已选 \(selection.count)")
                    .font(BeansFont.appFont(12))
                    .foregroundStyle(Color.beansComment)
            }

            HStack(spacing: 10) {
                Button {
                    BeansHaptics.tap()
                    guard !selection.isEmpty else {
                        ToastCenter.shared.show("请先选择歌单")
                        return
                    }
                    var count = 0
                    for item in filteredItems where selection.contains(item.id) {
                        hidden.hide(item.id, name: item.name)
                        count += 1
                    }
                    selection.removeAll()
                    ToastCenter.shared.show("已隐藏 \(count) 个歌单，可在右上角「已隐藏歌单」恢复")
                } label: {
                    Label("隐藏所选", systemImage: "eye.slash")
                        .font(BeansFont.appFont(13, .semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.beansAmber)

                Button {
                    BeansHaptics.tap()
                    guard let item = filteredItems.first(where: { selection.contains($0.id) }) else {
                        ToastCenter.shared.show("请先选择一个歌单")
                        return
                    }
                    if selection.count > 1 {
                        ToastCenter.shared.show("平台删除一次只能处理一个歌单，已选中第一个")
                    }
                    pendingDelete = item
                    showDeleteConfirm = true
                } label: {
                    Label("删除", systemImage: "trash")
                        .font(BeansFont.appFont(13, .semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }

            if !hidden.keys.isEmpty {
                Text("已隐藏 \(hidden.keys.count) 个歌单")
                    .font(BeansFont.appFont(11))
                    .foregroundStyle(Color.beansComment)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.regularMaterial)
    }

    // MARK: - 已隐藏歌单

    private var hiddenListSheet: some View {
        BeansNavigationStack {
            List {
                if hidden.keys.isEmpty {
                    Text("没有被隐藏的歌单")
                        .font(BeansFont.appFont(13))
                        .foregroundStyle(Color.beansComment)
                } else {
                    ForEach(hidden.keys.sorted { hidden.name(for: $0) < hidden.name(for: $1) }, id: \.self) { id in
                        HStack(spacing: 10) {
                            Image(systemName: "eye.slash")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.beansComment)
                            Text(verbatim: hidden.name(for: id))
                                .font(BeansFont.appFont(14))
                                .foregroundStyle(Color.beansLabel)
                            Spacer(minLength: 8)
                            Button("恢复") {
                                BeansHaptics.tap()
                                hidden.unhide(id)
                                ToastCenter.shared.show("已恢复显示")
                            }
                            .font(BeansFont.appFont(13, .semibold))
                            .foregroundStyle(Color.beansAmber)
                            .buttonStyle(.borderless)
                        }
                    }
                    .onDelete { offsets in
                        let ids = hidden.keys.sorted { hidden.name(for: $0) < hidden.name(for: $1) }
                        for index in offsets {
                            guard ids.indices.contains(index) else { continue }
                            hidden.unhide(ids[index])
                        }
                    }
                }
            }
            .navigationTitle("已隐藏歌单")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("全部恢复") {
                        BeansHaptics.tap()
                        hidden.unhideAll()
                        ToastCenter.shared.show("已恢复显示全部歌单")
                    }
                    .font(BeansFont.appFont(13, .semibold))
                    .disabled(hidden.keys.isEmpty)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { showHiddenList = false }
                        .font(BeansFont.appFont(14, .semibold))
                }
            }
        }
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
