import SwiftUI

// MARK: - 音乐库歌单：置顶 + 自定义顺序

/// 只影响本机展示的偏好：置顶歌单、歌单排列顺序。
/// 不改平台服务器上的任何数据；置顶上限 6 个，正好铺满首页一排。
final class LibraryPlaylistPrefs: ObservableObject {
    static let shared = LibraryPlaylistPrefs()
    static let maxPinned = 6

    private let pinnedKey = "beans.library.pinnedPlaylists.v1"
    private let orderKey = "beans.library.playlistOrder.v1"

    @Published private(set) var pinned: [String]
    @Published private(set) var order: [String]

    private init() {
        pinned = UserDefaults.standard.stringArray(forKey: pinnedKey) ?? []
        order = UserDefaults.standard.stringArray(forKey: orderKey) ?? []
    }

    func isPinned(_ id: String) -> Bool { pinned.contains(id) }

    /// 返回 false 表示已经置顶满 6 个
    @discardableResult
    func pin(_ id: String) -> Bool {
        guard !pinned.contains(id) else { return true }
        guard pinned.count < Self.maxPinned else { return false }
        pinned.append(id)
        persistPinned()
        return true
    }

    func unpin(_ id: String) {
        guard pinned.contains(id) else { return }
        pinned.removeAll { $0 == id }
        persistPinned()
    }

    /// 返回 false 表示置顶已满，调用方负责提示
    @discardableResult
    func togglePin(_ id: String) -> Bool {
        if isPinned(id) {
            unpin(id)
            return true
        }
        return pin(id)
    }

    func movePinned(from source: IndexSet, to destination: Int) {
        pinned.move(fromOffsets: source, toOffset: destination)
        persistPinned()
    }

    func applyOrder(_ ids: [String]) {
        order = ids
        persistOrder()
    }

    /// 按用户拖拽的顺序排列；没排过的歌单保持原相对顺序，排在已排过的后面。
    func sorted(_ items: [LibraryWallItem]) -> [LibraryWallItem] {
        guard !order.isEmpty else { return items }
        var rank: [String: Int] = [:]
        for (index, id) in order.enumerated() where rank[id] == nil {
            rank[id] = index
        }
        return items.enumerated()
            .sorted { lhs, rhs in
                let left = rank[lhs.element.id] ?? Int.max
                let right = rank[rhs.element.id] ?? Int.max
                if left != right { return left < right }
                return lhs.offset < rhs.offset
            }
            .map(\.element)
    }

    private func persistPinned() {
        UserDefaults.standard.set(pinned, forKey: pinnedKey)
    }

    private func persistOrder() {
        UserDefaults.standard.set(order, forKey: orderKey)
    }
}

// MARK: - 首页置顶歌单卡片

struct LibraryPinnedPlaylistCard: View {
    let item: LibraryWallItem
    var width: CGFloat = 132

    var body: some View {
        Button {
            BeansHaptics.tap()
            item.onOpen()
        } label: {
            VStack(alignment: .leading, spacing: 7) {
                ZStack(alignment: .bottomTrailing) {
                    CoverImage(url: item.coverURL, size: width, cornerRadius: 16)
                    if let badge = item.badge {
                        LibraryPlatformBadgeView(badge: badge, compact: true)
                            .padding(5)
                    }
                    Image(systemName: "pin.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(5)
                        .background(Circle().fill(.black.opacity(0.42)))
                        .padding(5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
            Button {
                BeansHaptics.tap()
                LibraryPlaylistPrefs.shared.unpin(item.id)
                ToastCenter.shared.show("已取消置顶「\(item.name)」")
            } label: {
                Label("取消置顶", systemImage: "pin.slash")
            }
            Button {
                BeansHaptics.tap()
                HiddenPlaylistStore.shared.hide(item.id, name: item.name)
                LibraryPlaylistPrefs.shared.unpin(item.id)
                ToastCenter.shared.show("已隐藏「\(item.name)」")
            } label: {
                Label("在音乐库隐藏", systemImage: "eye.slash")
            }
        }
    }
}

// MARK: - 歌单排序 / 置顶页

/// 拖拽调整音乐库全部歌单的顺序，右侧图钉控制置顶（最多 6 个）。
struct LibraryPlaylistOrderSheet: View {
    let items: [LibraryWallItem]

    @ObservedObject private var prefs = LibraryPlaylistPrefs.shared
    @EnvironmentObject private var theme: ThemeStore
    @Environment(\.dismiss) private var dismiss
    @State private var rows: [LibraryWallItem]
    @State private var editMode: EditMode = .active

    init(items: [LibraryWallItem]) {
        self.items = items
        _rows = State(initialValue: LibraryPlaylistPrefs.shared.sorted(items))
    }

    var body: some View {
        BeansNavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.beansAmber)
                    Text("点右侧图钉置顶，最多 \(LibraryPlaylistPrefs.maxPinned) 个；拖动右侧把手调整顺序")
                        .font(BeansFont.appFont(11))
                        .foregroundStyle(Color.beansComment)
                    Spacer(minLength: 0)
                    Text("\(prefs.pinned.count)/\(LibraryPlaylistPrefs.maxPinned)")
                        .font(BeansFont.appFont(11, .semibold))
                        .foregroundStyle(prefs.pinned.count >= LibraryPlaylistPrefs.maxPinned ? Color.beansAmber : Color.beansComment)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)

                List {
                    ForEach(rows) { item in
                        HStack(spacing: 12) {
                            CoverImage(url: item.coverURL, size: 44, cornerRadius: 10)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.name)
                                    .font(BeansFont.appFont(14, .medium))
                                    .foregroundStyle(Color.beansLabel)
                                    .lineLimit(1)
                                HStack(spacing: 6) {
                                    if let badge = item.badge {
                                        Text(badge.title)
                                            .font(BeansFont.appFont(9, .semibold))
                                            .foregroundStyle(badge.tint)
                                    }
                                    Text(item.subtitle)
                                        .font(BeansFont.appFont(11))
                                        .foregroundStyle(Color.beansComment)
                                }
                                .lineLimit(1)
                            }
                            Spacer(minLength: 0)
                            Button {
                                BeansHaptics.tap()
                                if prefs.isPinned(item.id) {
                                    prefs.unpin(item.id)
                                } else if !prefs.pin(item.id) {
                                    ToastCenter.shared.show("最多置顶 \(LibraryPlaylistPrefs.maxPinned) 个歌单，先取消一个吧")
                                }
                            } label: {
                                Image(systemName: prefs.isPinned(item.id) ? "pin.fill" : "pin")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(prefs.isPinned(item.id) ? Color.beansAmber : Color.beansComment.opacity(0.55))
                                    .frame(width: 36, height: 36)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.borderless)
                        }
                        .padding(.vertical, 3)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                    .onMove { source, destination in
                        rows.move(fromOffsets: source, toOffset: destination)
                        prefs.applyOrder(rows.map(\.id))
                    }
                }
                .environment(\.editMode, $editMode)
                .listStyle(.plain)
                .beansScrollContentBackgroundHidden()
            }
            .background {
                GlassBackdrop(customColor: theme.backgroundSyncAll ? theme.customBackground : nil)
            }
            .navigationTitle("歌单排序")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        prefs.applyOrder(rows.map(\.id))
                        dismiss()
                    }
                }
            }
        }
    }
}
