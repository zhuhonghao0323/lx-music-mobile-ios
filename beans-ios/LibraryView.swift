import SwiftUI
import UIKit

private enum LibraryRoute: Hashable {
    case playlist(Playlist)
}

enum LibraryProvider: String, CaseIterable, Identifiable {
    case netease = "网易云音乐"
    case qq = "QQ音乐"
    case kugou = "酷狗音乐"
    case migu = "咪咕音乐"
    case bodian = "波点音乐"
    case kuwo = "酷我音乐"

    var id: String { rawValue }

    var tint: LinearGradient {
        switch self {
        case .netease:
            return LinearGradient(colors: [Color(red: 0.93, green: 0.22, blue: 0.16), Color(red: 0.80, green: 0.15, blue: 0.12)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .qq:
            return LinearGradient(colors: [Color(red: 0.15, green: 0.78, blue: 0.55), Color(red: 0.05, green: 0.58, blue: 0.42)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .kugou:
            return LinearGradient(colors: [Color(red: 0.12, green: 0.58, blue: 0.95), Color(red: 0.02, green: 0.32, blue: 0.72)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .migu:
            return LinearGradient(colors: [Color(red: 0.98, green: 0.36, blue: 0.42), Color(red: 0.85, green: 0.16, blue: 0.36)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .bodian:
            return LinearGradient(colors: [Color(red: 0.10, green: 0.80, blue: 0.62), Color(red: 0.03, green: 0.55, blue: 0.48)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .kuwo:
            return LinearGradient(colors: [Color(red: 0.98, green: 0.72, blue: 0.12), Color(red: 0.90, green: 0.52, blue: 0.02)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    var icon: String {
        switch self {
        case .netease: return "cloud.fill"
        case .qq: return "play.rectangle.fill"
        case .kugou: return "music.note"
        case .migu: return "dot.radiowaves.left.and.right"
        case .bodian: return "b.circle.fill"
        case .kuwo: return "k.circle.fill"
        }
    }

    var brandImageName: String? {
        switch self {
        case .netease: return "BrandNetease"
        case .qq: return "BrandQQ"
        case .kugou: return "BrandKugou"
        case .migu: return "BrandMigu"
        case .bodian: return "BrandBodian"
        case .kuwo: return "BrandKuwo"
        }
    }

    /// 歌单卡片角标上的平台简称
    var shortName: String {
        switch self {
        case .netease: return "网易云"
        case .qq: return "QQ"
        case .kugou: return "酷狗"
        case .migu: return "咪咕"
        case .bodian: return "波点"
        case .kuwo: return "酷我"
        }
    }

    /// 角标底色（取品牌主色）
    var solidTint: Color {
        switch self {
        case .netease: return Color(red: 0.86, green: 0.19, blue: 0.14)
        case .qq: return Color(red: 0.07, green: 0.62, blue: 0.44)
        case .kugou: return Color(red: 0.06, green: 0.40, blue: 0.78)
        case .migu: return Color(red: 0.90, green: 0.20, blue: 0.36)
        case .bodian: return Color(red: 0.05, green: 0.60, blue: 0.52)
        case .kuwo: return Color(red: 0.92, green: 0.62, blue: 0.06)
        }
    }

    var badge: LibraryWallBadge {
        LibraryWallBadge(title: shortName, symbol: icon, brandImage: brandImageName, tint: solidTint)
    }
}

private extension LibraryProvider {
    var songSource: SongSource {
        switch self {
        case .netease: return .netease
        case .qq: return .qq
        case .kugou: return .kugou
        case .migu: return .migu
        case .bodian: return .bodian
        case .kuwo: return .kuwo
        }
    }
}

struct LibraryView: View {
    @EnvironmentObject private var theme: ThemeStore
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var player: PlayerManager
    @EnvironmentObject private var favorites: FavoritesStore
    @ObservedObject private var qqAuth = QQMusicAuth.shared
    @ObservedObject private var kugouAuth = KugouMusicAuth.shared
    @ObservedObject private var platformPrefs = PlatformPreferenceStore.shared

    @State private var showHistory = false
    @State private var showSectionSort = false
    @State private var showSyncedPlaylistSort = false
    /// 音乐库板块顺序（本地音乐库 / 我的歌单 / 最近播放，可自定义）
    @State private var libraryOrder = SectionOrderStore.load(SectionOrderStore.libraryKey, defaults: SectionOrderStore.libraryDefaults)
    @State private var navigationPath: [LibraryRoute] = []
    @State private var legacyRoute: LibraryRoute?
    @State private var showCreatePlaylist = false
    @State private var newPlaylistName = ""
    @State private var pendingDelete: Playlist?
    @State private var showDeleteConfirm = false
    @State private var source: LibraryProvider = .netease
    /// 音乐库左上角默认「全部歌单」：展示所有平台的歌单；切到某平台后只看该平台
    @State private var libraryShowsAll = true
    /// 左上角选中「手动导入歌单」：只展示本机导入的歌单
    @State private var libraryShowsImported = false
    @AppStorage("beans.homeHeaderHideSort") private var hideSortButton = false
    @AppStorage(PlatformPreferenceStore.hidePickerKey) private var hidePlatformPicker = false
    @State private var qqPlaylists: [Playlist] = []
    @State private var qqLoading = false
    @State private var qqSavedAt = Date.distantPast
    @State private var kugouPlaylists: [Playlist] = []
    @State private var kugouLoading = false
    @State private var kugouSavedAt = Date.distantPast
    @State private var bodianPlaylists: [Playlist] = []
    @State private var bodianLoading = false
    @State private var bodianSavedAt = Date.distantPast
    @State private var kuwoPlaylists: [Playlist] = []
    @State private var kuwoLoading = false
    @State private var kuwoSavedAt = Date.distantPast
    @State private var miguPlaylists: [Playlist] = []
    @State private var miguLoading = false
    @State private var miguSavedAt = Date.distantPast
    @ObservedObject private var bodianAuth = BodianMusicAuth.shared
    @ObservedObject private var kuwoAuth = KuwoMusicAuth.shared
    @ObservedObject private var miguAuth = MiguMusicAuth.shared
    @ObservedObject private var importedStore = ImportedPlaylistStore.shared
    @ObservedObject private var hiddenPlaylists = HiddenPlaylistStore.shared
    @ObservedObject private var localLibrary = LocalLibraryStore.shared
    @ObservedObject private var favoritePlaylists = FavoritePlaylistStore.shared
    @ObservedObject private var cloudSync = LibraryCloudSyncStore.shared
    @ObservedObject private var playlistPrefs = LibraryPlaylistPrefs.shared
    @State private var showCloudSyncSheet = false
    @State private var showPlaylistOrder = false
    @State private var showKuwoLogin = false
    @State private var showMiguLogin = false
    @State private var showAllPlaylistsSheet = false
    @State private var showAllSongsSheet = false
    @State private var selectedLocalPlaylist: LocalPlaylist?
    @State private var showImportSheet = false
    @State private var importPreset: Playlist?
    @State private var refreshingImportKeys: Set<String> = []
    @State private var renameTarget: ImportedPlaylist?
    @State private var renameText = ""
    @State private var showRenameAlert = false
    @State private var pendingDeleteImport: ImportedPlaylist?
    @State private var showDeleteImportConfirm = false
    @AppStorage("beans.uiStyle") private var uiStyleRaw = BeansUIStyle.liquid.rawValue
    private var libraryProviders: [LibraryProvider] { platformPrefs.enabledLibraryProviders }

    private var orderedNeteasePlaylists: [Playlist] {
        SyncedPlaylistOrderStore.shared.ordered(auth.playlists, source: .netease)
    }

    private var orderedQQPlaylists: [Playlist] {
        SyncedPlaylistOrderStore.shared.ordered(qqPlaylists, source: .qq)
    }

    private var orderedKugouPlaylists: [Playlist] {
        SyncedPlaylistOrderStore.shared.ordered(kugouPlaylists, source: .kugou)
    }

    private var orderedBodianPlaylists: [Playlist] {
        SyncedPlaylistOrderStore.shared.ordered(bodianPlaylists, source: .bodian)
    }

    private var orderedKuwoPlaylists: [Playlist] {
        SyncedPlaylistOrderStore.shared.ordered(kuwoPlaylists, source: .kuwo)
    }

    private var orderedMiguPlaylists: [Playlist] {
        SyncedPlaylistOrderStore.shared.ordered(miguPlaylists, source: .migu)
    }

    private var qqCacheAccountID: String {
        let raw = qqAuth.rawUin
        return raw.isEmpty ? qqAuth.playlistUin : raw
    }

    private var kugouCacheAccountID: String {
        kugouAuth.userId
    }

    private var bodianCacheAccountID: String {
        bodianAuth.isLoggedIn ? bodianAuth.uid : "bodian-guest"
    }

    private var kuwoCacheAccountID: String {
        kuwoAuth.isLoggedIn ? kuwoAuth.uid : "kuwo-guest"
    }

    private var miguCacheAccountID: String {
        miguAuth.isLoggedIn ? "migu-user" : "migu-guest"
    }

    private var syncedPlaylistBinding: Binding<[Playlist]> {
        Binding(
            get: {
                switch source {
                case .netease: return orderedNeteasePlaylists
                case .qq: return orderedQQPlaylists
                case .kugou: return orderedKugouPlaylists
                case .migu: return orderedMiguPlaylists
                case .bodian: return orderedBodianPlaylists
                case .kuwo: return orderedKuwoPlaylists
                }
            },
            set: { value in
                switch source {
                case .netease: auth.playlists = value
                case .qq: qqPlaylists = value
                case .kugou: kugouPlaylists = value
                case .migu: miguPlaylists = value
                case .bodian: bodianPlaylists = value
                case .kuwo: kuwoPlaylists = value
                }
                SyncedPlaylistOrderStore.shared.save(value, source: source.songSource)
            }
        )
    }

    private var isNativeClean: Bool {
        BeansUIStyle(rawValue: uiStyleRaw) == .nativeClean
    }

    var body: some View {
        let _ = theme.accent
        BeansNavigationStackWithPath(path: $navigationPath) {
        ZStack {
            // 页面背景：同步开启时显示壁纸/背景色，否则默认氛围渐变
            GlassBackdrop(customColor: theme.backgroundSyncAll ? theme.customBackground : nil)
            // 实例级 UITabBar 清透风格（固定全透明，无需调节）
            TabBarAppearanceConfigurator()
            if #unavailable(iOS 16.0) {
                NavigationLink(
                    destination: libraryDestination(legacyRoute ?? .playlist(Playlist(id: 0, name: "", coverURL: nil))),
                    isActive: Binding(
                        get: { legacyRoute != nil },
                        set: { if !$0 { legacyRoute = nil } }
                    )
                ) {
                    EmptyView()
                }
                .hidden()
            }
            ScrollView {
                LazyVStack(alignment: .leading, spacing: isNativeClean ? 30 : 24) {
                    if isNativeClean {
                        appleHeader
                    } else {
                        header
                    }
                    if !hidePlatformPicker {
                        providerPicker
                    }
                    // 板块按用户自定义顺序渲染（可拖拽排序）
                    ForEach(libraryOrder, id: \.self) { key in
                        switch key {
                        case "本地音乐库":
                            LocalMusicSection()
                        case "我的歌单":
                            VStack(alignment: .leading, spacing: 26) {
                                if libraryShowsImported {
                                    importedSection
                                } else if source == .migu {
                                    if !miguAuth.isLoggedIn { miguLoginBanner }
                                    playlistsWallSection
                                    miguSection
                                } else {
                                    if source == .kuwo && !kuwoAuth.isLoggedIn {
                                        kuwoLoginBanner
                                    }
                                    playlistsWallSection
                                    LibraryAllSongsSection(songs: aggregatedSongs) {
                                        showAllSongsSheet = true
                                    } onPlay: { list, index in
                                        player.play(songs: list, startAt: index)
                                    }
                                }
                            }
                        case "最近播放":
                            historySection
                        default:
                            EmptyView()
                        }
                    }
                }
                .padding(.horizontal, isNativeClean ? 24 : 16)
                .padding(.top, isNativeClean ? 20 : 8)
                .padding(.bottom, 190)
                .frame(maxWidth: 860)
                .frame(maxWidth: .infinity)
            }
            .beansScrollIndicatorsHidden()
            .beansScrollBounceBasedOnSize()
            .refreshable {
                await refreshCurrentSource(force: true)
            }
        }
        .task {
            source = platformPrefs.ensureVisible(source)
            await cloudSync.rebuildFromCache()
        }
        .task(id: source) {
            await refreshCurrentSource(force: false)
        }
        .onAppear {
            source = platformPrefs.ensureVisible(source)
        }
        .onReceive(platformPrefs.changes) { _ in
            let next = platformPrefs.ensureVisible(source)
            if next != source { source = next }
        }
        .onReceive(NotificationCenter.default.publisher(for: .beansNeteaseLoginDidUpdate)) { _ in
            guard platformPrefs.isEnabled(SearchProvider.netease) else { return }
            source = .netease
            Task { await auth.loadLibrary(force: true) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .beansQQLoginDidUpdate)) { _ in
            guard platformPrefs.isEnabled(SearchProvider.qq) else { return }
            source = .qq
            Task { await loadQQPlaylists(force: true) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .beansKugouLoginDidUpdate)) { _ in
            guard platformPrefs.isEnabled(SearchProvider.kugou) else { return }
            source = .kugou
            Task { await loadKugouPlaylists(force: true) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .beansBodianLoginDidUpdate)) { _ in
            guard platformPrefs.isEnabled(SearchProvider.bodian) else { return }
            source = .bodian
            Task { await loadBodianPlaylists(force: true) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .beansKuwoLoginDidUpdate)) { _ in
            guard platformPrefs.isEnabled(SearchProvider.kuwo) else { return }
            if kuwoAuth.isLoggedIn { source = .kuwo }
            Task { await loadKuwoPlaylists(force: true) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .beansMiguLoginDidUpdate)) { _ in
            guard platformPrefs.isEnabled(SearchProvider.migu) else { return }
            if miguAuth.isLoggedIn { source = .migu }
            Task { await loadMiguPlaylists(force: true) }
        }
        .sheet(isPresented: $showHistory) {
            HistoryView()
                .environmentObject(player)
                .environmentObject(auth)
                .environmentObject(theme)
        }
        .sheet(isPresented: $showSectionSort) {
            SectionOrderSheet(
                title: "音乐库板块排序",
                sections: SectionOrderStore.libraryDefaults,
                order: $libraryOrder,
                platformOrder: Binding(
                    get: { platformPrefs.orderedRaw },
                    set: { platformPrefs.orderedRaw = $0 }
                )
            )
                .onDisappear { SectionOrderStore.save(SectionOrderStore.libraryKey, libraryOrder) }
        }
        .sheet(isPresented: $showSyncedPlaylistSort) {
            SyncedPlaylistOrderSheet(
                title: "\(source.rawValue)歌单排序",
                source: source.songSource,
                playlists: syncedPlaylistBinding
            )
            .environmentObject(theme)
        }
        .sheet(isPresented: $showImportSheet) {
            ImportPlaylistSheet(defaultSource: source.songSource, presetPlaylist: importPreset)
                .environmentObject(theme)
        }
        .sheet(isPresented: $showKuwoLogin) {
            KuwoLoginSheet()
                .environmentObject(theme)
        }
        .sheet(isPresented: $showMiguLogin) {
            MiguLoginSheet()
                .environmentObject(theme)
        }
        .sheet(isPresented: $showPlaylistOrder) {
            LibraryPlaylistOrderSheet(items: wallItems)
                .environmentObject(theme)
        }
        .fullScreenCover(isPresented: $showAllPlaylistsSheet) {
            LibraryAllPlaylistsSheet(items: wallItems)
                .environmentObject(theme)
                .environmentObject(player)
        }
        .sheet(item: $selectedLocalPlaylist) { playlist in
            LocalPlaylistDetailSheet(playlistID: playlist.id)
                .environmentObject(player)
                .environmentObject(auth)
        }
        .sheet(isPresented: $showCloudSyncSheet) {
            LibraryCloudSyncSheet(sources: syncSources) {
                await refreshCloudSyncSources()
            }
            .environmentObject(theme)
        }
        .fullScreenCover(isPresented: $showAllSongsSheet) {
            LibraryAllSongsSheet(songs: aggregatedSongs)
                .environmentObject(player)
                .environmentObject(theme)
        }
        .alert("重命名歌单", isPresented: $showRenameAlert) {
            TextField("歌单名称", text: $renameText)
            Button("保存") {
                if let target = renameTarget {
                    importedStore.rename(key: target.key, to: renameText)
                }
                renameTarget = nil
            }
            Button("取消", role: .cancel) { renameTarget = nil }
        } message: {
            Text("只修改本机的歌单名称，不会影响平台上的原名")
        }
        .confirmationDialog("确定删除导入的歌单「\(pendingDeleteImport?.name ?? "")」吗？", isPresented: $showDeleteImportConfirm, titleVisibility: .visible) {
            Button("删除", role: .destructive) {
                if let target = pendingDeleteImport {
                    importedStore.remove(key: target.key)
                }
                pendingDeleteImport = nil
            }
            Button("取消", role: .cancel) { pendingDeleteImport = nil }
        }
        .alert("新建歌单", isPresented: $showCreatePlaylist) {
            TextField("歌单名称", text: $newPlaylistName)
            Button("创建") { createPlaylist() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("输入歌单名称，创建后同步到\(source.rawValue)")
        }
        .confirmationDialog("确定删除歌单「\(pendingDelete?.name ?? "")」吗？", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("删除", role: .destructive) { confirmDeletePlaylist() }
            Button("取消", role: .cancel) {}
        }
        .beansNavigationDestination(for: LibraryRoute.self) { route in
            libraryDestination(route)
        }
    }
    }

    @ViewBuilder
    private func libraryDestination(_ route: LibraryRoute) -> some View {
        switch route {
        case .playlist(let playlist):
            PlaylistView(playlist: playlist)
                .environmentObject(player)
                .environmentObject(auth)
                .environmentObject(theme)
        }
    }

    private func openRoute(_ route: LibraryRoute) {
        if #available(iOS 16.0, *) {
            navigationPath.append(route)
        } else {
            legacyRoute = route
        }
    }

    /// 打开本机自建歌单详情
    private func openLocalPlaylist(_ playlist: LocalPlaylist) {
        selectedLocalPlaylist = playlist
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                // 只保留图标 + 右侧小名称：副标题与名称重复，已去掉
                libraryTitleButton
                Spacer()
                HStack(spacing: 10) {
                GlassIconButton(systemName: "icloud.and.arrow.down", forceLiquid: isNativeClean) {
                    prepareAndShowCloudSync()
                }
                if !hideSortButton {
                    GlassIconButton(systemName: "arrow.up.arrow.down", forceLiquid: isNativeClean) {
                        BeansHaptics.tap()
                        showSectionSort = true
                    }
                    GlassIconButton(systemName: "list.number", forceLiquid: isNativeClean) {
                        BeansHaptics.tap()
                        showSyncedPlaylistSort = true
                    }
                }
                }
            }
        }
        .padding(.top, 8)
    }

    private var appleHeader: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .center) {
                libraryTitleButton
                Spacer(minLength: 12)
                GlassIconButton(systemName: "icloud.and.arrow.down", forceLiquid: isNativeClean) {
                    prepareAndShowCloudSync()
                }
                if !hideSortButton {
                    GlassIconButton(systemName: "arrow.up.arrow.down", forceLiquid: isNativeClean) {
                        BeansHaptics.tap()
                        showSectionSort = true
                    }
                    GlassIconButton(systemName: "list.number", forceLiquid: isNativeClean) {
                        BeansHaptics.tap()
                        showSyncedPlaylistSort = true
                    }
                }
            }
            Rectangle()
                .fill(Color.beansLabel.opacity(0.10))
                .frame(height: 1)
        }
        .padding(.top, 4)
    }

    private var libraryTitleText: String {
        if libraryShowsImported { return "手动导入" }
        if libraryShowsAll { return "全部歌单" }
        return source.rawValue
    }

    private var librarySubtitle: String {
        if libraryShowsImported {
            let n = importedStore.items.count
            return n == 0 ? "用链接导入平台歌单，歌曲保存在本机" : "本地保存 \(n) 个 · 可更新 / 删除"
        }
        let cloud = libraryShowsAll ? allCloudPlaylists : allCloudPlaylists.filter { $0.provider == source }
        let count = cloud.count + importedStore.items.count
        if libraryShowsAll {
            if count == 0 { return "全部平台的歌单与收藏会汇总在这里" }
            return "全部平台 · \(count) 个歌单"
        }
        if count == 0 { return "该平台暂无歌单，可切换平台或手动导入" }
        return "\(source.rawValue) · \(count) 个歌单"
    }

    private var libraryTitleButton: some View {
        Menu {
            // 第一项：全部（与主页「全部」一致）
            Button {
                BeansHaptics.tap()
                libraryShowsAll = true
                libraryShowsImported = false
            } label: {
                Label("全部歌单", systemImage: (libraryShowsAll && !libraryShowsImported) ? "checkmark" : "square.grid.2x2.fill")
            }
            Divider()
            ForEach(libraryProviders) { candidate in
                Button {
                    BeansHaptics.tap()
                    libraryShowsAll = false
                    libraryShowsImported = false
                    source = candidate
                } label: {
                    Label(LocalizedStringKey(candidate.rawValue), systemImage: (!libraryShowsAll && !libraryShowsImported && candidate == source) ? "checkmark" : candidate.icon)
                }
            }
            Divider()
            // 手动导入歌单：与酷狗、QQ 等并列
            Button {
                BeansHaptics.tap()
                libraryShowsImported = true
                libraryShowsAll = false
            } label: {
                Label("手动导入歌单", systemImage: libraryShowsImported ? "checkmark" : "square.and.arrow.down")
            }
        } label: {
            // 只留一个平台图标：不显示平台名，方形品牌图裁成圆形，
            // 避免「方形 + 圆角」的 App 图标外形出现在标题行里。
            let iconSize: CGFloat = isNativeClean ? 38 : 34
            Group {
                if libraryShowsImported {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: iconSize * 0.52, weight: .semibold))
                        .foregroundStyle(Color.beansLabel)
                } else if libraryShowsAll {
                    if let allIcon = UIImage(named: "BrandAll") {
                        Image(uiImage: allIcon)
                            .resizable()
                            .scaledToFill()
                            .clipShape(Circle())
                    } else {
                        Image(systemName: "square.grid.2x2.fill")
                            .font(.system(size: iconSize * 0.52, weight: .semibold))
                            .foregroundStyle(Color.beansLabel)
                    }
                } else if let brand = source.brandImageName, let img = UIImage(named: brand) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .clipShape(Circle())
                } else {
                    Image(systemName: source.icon)
                        .font(.system(size: iconSize * 0.52, weight: .semibold))
                        .foregroundStyle(Color.beansLabel)
                }
            }
            .frame(width: iconSize, height: iconSize)
            .clipShape(Circle())
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(libraryTitleText + "，" + librarySubtitle))
    }


    // MARK: - 歌单墙（3 列 × 2 行，可一直右滑）

    /// 歌单墙标题跟随左上角平台切换：网易云 → 网易云歌单，酷我 → 酷我歌单
    private var playlistWallTitle: String {
        if libraryShowsImported { return "导入歌单" }
        if libraryShowsAll { return "全部歌单" }
        return "\(source.shortName)歌单"
    }

    private var playlistsWallSection: some View {
        VStack(alignment: .leading, spacing: 22) {
            if !pinnedWallItems.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    SectionHeader(title: "置顶歌单", trailing: "排序") {
                        BeansHaptics.tap()
                        showPlaylistOrder = true
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(pinnedWallItems) { item in
                                LibraryPinnedPlaylistCard(item: item)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: playlistWallTitle, trailing: wallItems.isEmpty ? nil : "查看全部") {
                    BeansHaptics.tap()
                    showAllPlaylistsSheet = true
                }
                if wallItems.isEmpty {
                    EmptyStateView(icon: "music.note.list", text: "还没有歌单\n登录任一平台或导入歌单后会显示在这里")
                } else {
                    PlaylistWallView(items: wallItems)
                }
            }
        }
    }

    /// 酷我未登录时的引导卡：直接在音乐库完成登录，不用再绕到「我的」
    private var kuwoLoginBanner: some View {
        Button {
            BeansHaptics.tap()
            showKuwoLogin = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "k.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(Color(red: 0.97, green: 0.70, blue: 0.08))
                VStack(alignment: .leading, spacing: 3) {
                    Text("登录酷我音乐")
                        .font(BeansFont.appFont(14, .semibold))
                        .foregroundStyle(Color.beansLabel)
                    Text("网页登录后自动同步「我的歌单」，也可以直接粘贴歌单链接")
                        .font(BeansFont.appFont(11))
                        .foregroundStyle(Color.beansComment)
                        .lineLimit(2)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.beansComment.opacity(0.6))
            }
            .padding(14)
            .background { BeansGlass(shape: RoundedRectangle(cornerRadius: 20, style: .continuous)) }
            .contentShape(Rectangle())
        }
        .buttonStyle(GlassPressButtonStyle(scale: 0.98))
    }

    /// 咪咕未登录时的引导卡：咪咕网页登录后同步「我的歌单」
    private var miguLoginBanner: some View {
        Button {
            BeansHaptics.tap()
            showMiguLogin = true
        } label: {
            HStack(spacing: 12) {
                if let img = UIImage(named: "BrandMigu") {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 32, height: 32)
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                } else {
                    Image(systemName: "dot.radiowaves.left.and.right")
                        .font(.system(size: 28))
                        .foregroundStyle(Color(red: 0.90, green: 0.20, blue: 0.36))
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("登录咪咕音乐")
                        .font(BeansFont.appFont(14, .semibold))
                        .foregroundStyle(Color.beansLabel)
                    Text("网页登录后自动同步「我的歌单」，会员状态也会一起识别")
                        .font(BeansFont.appFont(11))
                        .foregroundStyle(Color.beansComment)
                        .lineLimit(2)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.beansComment.opacity(0.6))
            }
            .padding(14)
            .background { BeansGlass(shape: RoundedRectangle(cornerRadius: 20, style: .continuous)) }
            .contentShape(Rectangle())
        }
        .buttonStyle(GlassPressButtonStyle(scale: 0.98))
    }

    /// 置顶歌单：按置顶顺序取墙上的卡片，隐藏/删除后自动消失
    private var pinnedWallItems: [LibraryWallItem] {
        guard !playlistPrefs.pinned.isEmpty else { return [] }
        let lookup = Dictionary(wallItems.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return playlistPrefs.pinned.compactMap { lookup[$0] }
    }

    /// 当前平台账号同步回来的歌单
    private var syncedWallPlaylists: [Playlist] {
        switch source {
        case .netease: return auth.isLoggedIn ? auth.playlists : []
        case .qq: return qqAuth.isLoggedIn ? qqPlaylists : []
        case .kugou: return kugouAuth.isLoggedIn ? kugouPlaylists : []
        case .bodian: return bodianAuth.isLoggedIn ? bodianPlaylists : []
        case .kuwo: return kuwoAuth.isLoggedIn ? kuwoPlaylists : []
        case .migu: return miguAuth.isLoggedIn ? miguPlaylists : []
        }
    }
    // 音乐库歌单区现在展示全部平台（见 allCloudPlaylists），这个属性保留给其它板块使用。

    /// 所有已登录平台的云端歌单（不再只看当前选中平台）
    private var allCloudPlaylists: [(playlist: Playlist, provider: LibraryProvider)] {
        var result: [(Playlist, LibraryProvider)] = []
        for provider in libraryProviders {
            switch provider {
            case .netease:
                guard auth.isLoggedIn else { continue }
                result += orderedNeteasePlaylists.map { ($0, .netease) }
            case .qq:
                guard qqAuth.isLoggedIn else { continue }
                result += orderedQQPlaylists.map { ($0, .qq) }
            case .kugou:
                guard kugouAuth.isLoggedIn else { continue }
                result += orderedKugouPlaylists.map { ($0, .kugou) }
            case .bodian:
                guard bodianAuth.isLoggedIn else { continue }
                result += orderedBodianPlaylists.map { ($0, .bodian) }
            case .kuwo:
                guard kuwoAuth.isLoggedIn else { continue }
                result += orderedKuwoPlaylists.map { ($0, .kuwo) }
            case .migu:
                guard miguAuth.isLoggedIn else { continue }
                result += orderedMiguPlaylists.map { ($0, .migu) }
            }
        }
        return result
    }

    private func cacheAccountID(for provider: LibraryProvider) -> String {
        switch provider {
        case .netease: return "\(auth.user?.uid ?? 0)"
        case .qq: return qqCacheAccountID
        case .kugou: return kugouCacheAccountID
        case .bodian: return bodianCacheAccountID
        case .kuwo: return kuwoCacheAccountID
        case .migu: return miguCacheAccountID
        }
    }

    /// 歌单歌曲数：优先用已同步到本机的实际条数，其次用平台返回的 trackCount
    private func wallSongCount(for playlist: Playlist, provider: LibraryProvider) -> Int {
        let cached = SyncedPlaylistCache.shared.meta(for: playlist, accountID: cacheAccountID(for: provider))?.count ?? 0
        return max(playlist.trackCount, cached)
    }

    /// 音乐库要展示的全部歌单：本机导入 + 所有平台账号歌单，隐藏的不再出现
    private var wallItems: [LibraryWallItem] {
        var items: [LibraryWallItem] = []

        // 本地歌单（手工导入 + 本机自建）排在最前，归到「本地」分类
        let localBadge = LibraryWallBadge(title: "本地", symbol: "iphone", brandImage: nil, tint: Color(white: 0.42))
        for entry in importedStore.items {
            let id = "imported-\(entry.key)"
            guard !hiddenPlaylists.isHidden(id) else { continue }
            items.append(
                LibraryWallItem(
                    id: id,
                    name: entry.name,
                    coverURL: entry.coverURL,
                    count: entry.songs.count,
                    subtitle: beansSongCountText(entry.songs.count),
                    badge: localBadge,
                    platformKey: "local",
                    onOpen: { openRoute(LibraryRoute.playlist(entry.playlist)) },
                    onUpdate: { Task { await refreshImported(entry) } },
                    onRename: {
                        renameTarget = entry
                        renameText = entry.name
                        showRenameAlert = true
                    },
                    onDelete: {
                        pendingDeleteImport = entry
                        showDeleteImportConfirm = true
                    }
                )
            )
        }

        for entry in allCloudPlaylists {
            // 选定具体平台后，云歌单只看该平台；「全部」时不过滤
            if !libraryShowsAll, entry.provider != source { continue }
            let playlist = entry.playlist
            let id = "synced-\(playlist.source.rawValue)-\(playlist.id)"
            guard !hiddenPlaylists.isHidden(id) else { continue }
            let count = wallSongCount(for: playlist, provider: entry.provider)
            items.append(
                LibraryWallItem(
                    id: id,
                    name: playlist.name,
                    coverURL: playlist.coverURL,
                    count: count,
                    subtitle: count > 0 ? beansSongCountText(count) : "歌单",
                    badge: entry.provider.badge,
                    platformKey: entry.provider.rawValue,
                    onOpen: { openRoute(LibraryRoute.playlist(playlist)) },
                    onDelete: { requestDelete(playlist) }
                )
            )
        }

        // 本机自建歌单（在「我的」里创建的），同样归入「本地」分类
        for pl in localLibrary.playlists {
            let id = "local-\(pl.id.uuidString)"
            guard !hiddenPlaylists.isHidden(id) else { continue }
            items.append(
                LibraryWallItem(
                    id: id,
                    name: pl.name,
                    coverURL: pl.songs.first?.coverURL,
                    count: pl.songs.count,
                    subtitle: beansSongCountText(pl.songs.count),
                    badge: localBadge,
                    platformKey: "local",
                    onOpen: { openLocalPlaylist(pl) }
                )
            )
        }

        // 收藏歌单：主页「歌单收藏」转入音乐库，单独成「收藏」分类
        let favBadge = LibraryWallBadge(title: "收藏", symbol: "heart.fill", brandImage: nil, tint: Color.beansAmber)
        for pl in favoritePlaylists.playlists {
            let id = "favorite-\(pl.uniqueKey)"
            guard !hiddenPlaylists.isHidden(id) else { continue }
            items.append(
                LibraryWallItem(
                    id: id,
                    name: pl.name,
                    coverURL: pl.coverURL,
                    count: pl.trackCount,
                    subtitle: pl.trackCount > 0 ? beansSongCountText(pl.trackCount) : "收藏歌单",
                    badge: favBadge,
                    platformKey: "favorite",
                    onOpen: { openRoute(LibraryRoute.playlist(pl)) }
                )
            )
        }
        // 用户在「歌单排序」里拖拽过的顺序优先，其余保持上面分组顺序
        return playlistPrefs.sorted(items)
    }

    /// 云同步覆盖范围：已登录平台的云端歌单
    private var syncSources: [LibraryCloudSyncSource] {
        [
            LibraryCloudSyncSource(source: .netease, accountID: "\(auth.user?.uid ?? 0)", playlists: auth.isLoggedIn ? auth.playlists : []),
            LibraryCloudSyncSource(source: .qq, accountID: qqCacheAccountID, playlists: qqAuth.isLoggedIn ? qqPlaylists : []),
            LibraryCloudSyncSource(source: .kugou, accountID: kugouCacheAccountID, playlists: kugouAuth.isLoggedIn ? kugouPlaylists : []),
            LibraryCloudSyncSource(source: .bodian, accountID: bodianCacheAccountID, playlists: bodianAuth.isLoggedIn ? bodianPlaylists : []),
            LibraryCloudSyncSource(source: .kuwo, accountID: kuwoCacheAccountID, playlists: kuwoAuth.isLoggedIn ? kuwoPlaylists : []),
            LibraryCloudSyncSource(source: .migu, accountID: miguCacheAccountID, playlists: miguAuth.isLoggedIn ? miguPlaylists : [])
        ]
    }

    /// 所有歌单里的歌曲汇总：歌手名 + 歌名相同只留一首
    private var aggregatedSongs: [Song] {
        var groups: [[Song]] = []
        groups.append(cloudSync.cachedSongs)
        groups.append(importedStore.items.flatMap { $0.songs })
        groups.append(localLibrary.playlists.flatMap { $0.songs })
        return LibrarySongAggregator.merge(groups)
    }

    private var playlistsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "我的歌单", trailing: auth.isLoggedIn ? "新建" : nil) {
                if auth.isLoggedIn {
                    BeansHaptics.tap()
                    newPlaylistName = ""
                    showCreatePlaylist = true
                }
            }
            if !auth.isLoggedIn {
                EmptyStateView(icon: "music.note.list", text: "登录网易云音乐后即可查看你的歌单")
            } else if auth.playlists.isEmpty {
                createPlaylistCard
            } else {
                VStack(spacing: 0) {
                    ForEach(orderedNeteasePlaylists) { playlist in
                        Button {
                            openRoute(LibraryRoute.playlist(playlist))
                        } label: {
                            HStack(spacing: 12) {
                                CoverImage(url: playlist.coverURL, size: 56, cornerRadius: 12)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(playlist.name)
                                        .font(BeansFont.appFont(15, .medium))
                                        .foregroundStyle(Color.beansLabel)
                                        .lineLimit(1)
                                    Text(beansSongCountText(playlist.trackCount))
                                        .font(BeansFont.appFont(12))
                                        .foregroundStyle(Color.beansComment)
                                }
                                Spacer(minLength: 8)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Color.beansComment.opacity(0.6))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button {
                                BeansHaptics.tap()
                                requestDelete(playlist)
                            } label: {
                                Label("删除歌单", systemImage: "trash")
                            }
                        }
                        Divider().overlay(Color.beansComment.opacity(0.12))
                    }
                    // 新建歌单行
                    Button {
                        BeansHaptics.tap()
                        newPlaylistName = ""
                        showCreatePlaylist = true
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(style: StrokeStyle(lineWidth: 1.2, dash: [5, 3]))
                                    .foregroundStyle(Color.beansComment.opacity(0.45))
                                    .frame(width: 56, height: 56)
                                Image(systemName: "plus")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundStyle(Color.beansComment)
                            }
                            Text("新建歌单")
                                .font(BeansFont.appFont(15, .medium))
                                .foregroundStyle(Color.beansComment)
                            Spacer()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 6)
                .background {
                                        BeansGlass(shape: RoundedRectangle(cornerRadius: 24, style: .continuous))
                }
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .beansCardShadow(radius: 9, y: 3)
            }
        }
    }

    private var createPlaylistCard: some View {
        Button {
            BeansHaptics.tap()
            newPlaylistName = ""
            showCreatePlaylist = true
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                        .foregroundStyle(Color.beansComment.opacity(0.45))
                        .frame(width: 160, height: 160)
                    Image(systemName: "plus")
                        .font(.system(size: 26, weight: .medium))
                        .foregroundStyle(Color.beansComment)
                }
                Text("新建歌单")
                    .font(BeansFont.appFont(12, .medium))
                    .foregroundStyle(Color.beansComment)
            }
            .padding(8)
            .frame(maxWidth: .infinity)
            .background {
                                BeansGlass(shape: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - 导入歌单（LX 式「打开歌单 / 收藏」：本地保存，可更新）

    private var importedItems: [ImportedPlaylist] {
        // 「全部歌单」与「手动导入」都要看到所有平台的导入歌单。
        // 之前这里写死按当前平台过滤，导入了酷狗概念版歌单却停在网易云，
        // 于是下方永远空着——看起来像「导入没成功」。
        if libraryShowsImported || libraryShowsAll {
            return importedStore.items
        }
        return importedStore.playlists(for: source.songSource)
    }

    private var importedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("导入歌单")
                        .font(BeansFont.appFont(isNativeClean ? 20 : 18, .bold))
                        .foregroundStyle(Color.beansLabel)
                    Text(importedItems.isEmpty ? "用链接导入平台歌单，歌曲存在本机" : "本地保存 \(importedItems.count) 个 · 可随时更新")
                        .font(BeansFont.appFont(11.5))
                        .foregroundStyle(Color.beansComment)
                }
                Spacer(minLength: 8)
                Menu {
                    Button {
                        BeansHaptics.tap()
                        presentImport()
                    } label: {
                        Label("导入歌单…", systemImage: "square.and.arrow.down")
                    }
                    if !importedItems.isEmpty {
                        Button {
                            Task { await refreshAllImported() }
                        } label: {
                            Label("全部更新", systemImage: "arrow.clockwise")
                        }
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.beansAmber)
                        .frame(width: 34, height: 34)
                        .background { BeansSurface(shape: Circle()) }
                }
                .buttonStyle(.plain)
            }

            if importedItems.isEmpty {
                Button {
                    BeansHaptics.tap()
                    presentImport()
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(style: StrokeStyle(lineWidth: 1.2, dash: [5, 3]))
                                .foregroundStyle(Color.beansComment.opacity(0.45))
                                .frame(width: 56, height: 56)
                            Image(systemName: "square.and.arrow.down")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundStyle(Color.beansComment)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text("导入歌单")
                                .font(BeansFont.appFont(15, .medium))
                                .foregroundStyle(Color.beansLabel)
                            Text("粘贴歌单链接或 id，导入后可更新")
                                .font(BeansFont.appFont(11.5))
                                .foregroundStyle(Color.beansComment)
                        }
                        Spacer(minLength: 8)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.beansComment.opacity(0.6))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background { BeansGlass(shape: RoundedRectangle(cornerRadius: 22, style: .continuous)) }
                .beansCardShadow(radius: 8, y: 3)
            } else {
                VStack(spacing: 0) {
                    ForEach(importedItems) { item in
                        importedRow(item)
                        if item.key != importedItems.last?.key {
                            Divider().overlay(Color.beansComment.opacity(0.12))
                        }
                    }
                }
                .padding(.vertical, 6)
                .background { BeansGlass(shape: RoundedRectangle(cornerRadius: 24, style: .continuous)) }
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .beansCardShadow(radius: 9, y: 3)
            }
        }
    }

    private func importedRow(_ item: ImportedPlaylist) -> some View {
        Button {
            openRoute(LibraryRoute.playlist(item.playlist))
        } label: {
            HStack(spacing: 12) {
                ZStack(alignment: .bottomTrailing) {
                    CoverImage(url: item.coverURL, size: 56, cornerRadius: 12)
                    if refreshingImportKeys.contains(item.key) {
                        ProgressView()
                            .scaleEffect(0.6)
                            .padding(3)
                            .background(.thinMaterial, in: Circle())
                            .offset(x: 4, y: 4)
                    }
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.name)
                        .font(BeansFont.appFont(15, .medium))
                        .foregroundStyle(Color.beansLabel)
                        .lineLimit(1)
                    Text("\(beansSongCountText(item.songs.isEmpty ? item.trackCount : item.songs.count)) · 更新于 \(item.updatedAtText)")
                        .font(BeansFont.appFont(12))
                        .foregroundStyle(Color.beansComment)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.beansComment.opacity(0.6))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                BeansHaptics.tap()
                Task { await refreshImported(item) }
            } label: {
                Label("更新歌单", systemImage: "arrow.clockwise")
            }
            Button {
                BeansHaptics.tap()
                renameTarget = item
                renameText = item.name
                showRenameAlert = true
            } label: {
                Label("重命名", systemImage: "pencil")
            }
            Button(role: .destructive) {
                BeansHaptics.tap()
                pendingDeleteImport = item
                showDeleteImportConfirm = true
            } label: {
                Label("删除歌单", systemImage: "trash")
            }
        }
    }

    private func presentImport(preset: Playlist? = nil) {
        // 手动导入与当前停留的平台无关（「全部歌单」/「手动导入」下也能导），
        // 不再按 source 拦截；具体平台在导入页里自己选。
        importPreset = preset
        showImportSheet = true
    }

    private func refreshImported(_ item: ImportedPlaylist) async {
        guard !refreshingImportKeys.contains(item.key) else { return }
        refreshingImportKeys.insert(item.key)
        BeansLogger.shared.log("导入歌单更新：\(item.source.rawValue) \(item.sourceID) \(item.name)", level: .info)
        do {
            let payload = try await PlaylistImportService.fetch(source: item.source, sourceID: item.sourceID)
            importedStore.updateSongs(payload.songs, key: item.key)
            ToastCenter.shared.show("「\(item.name)」已更新 \(payload.songs.count) 首")
        } catch {
            let text = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            ToastCenter.shared.show("更新失败：\(text)")
            BeansLogger.shared.log("导入歌单更新失败：\(item.name) \(text)", level: .warn)
        }
        refreshingImportKeys.remove(item.key)
    }

    private func refreshAllImported() async {
        for item in importedItems {
            await refreshImported(item)
        }
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "最近播放", trailing: "查看全部") {
                showHistory = true
            }
            if player.history.isEmpty {
                EmptyStateView(icon: "clock.arrow.circlepath", text: "暂无播放记录")
            } else {
                VStack(spacing: 0) {
                    ForEach(player.history.prefix(5), id: \.identityKey) { song in
                        SongCell(song: song, suppressNativeCleanRowGlass: isNativeClean) {
                            playFromHistory(song)
                        }
                        Divider().overlay(Color.beansComment.opacity(0.15))
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background {
                                        BeansGlass(shape: RoundedRectangle(cornerRadius: 22, style: .continuous))
                }
                .beansCardShadow(radius: 8, y: 3)
            }
        }
    }

    /// 平台选择（网易云 / QQ音乐，样式与主页一致）
    private var providerPicker: some View {
        HStack(spacing: 4) {
            ForEach(libraryProviders) { p in
                Button {
                    BeansHaptics.tap()
                    if source != p { source = p }
                } label: {
                    HStack(spacing: 6) {
                        if let brandImageName = p.brandImageName {
                            Image(brandImageName)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 16, height: 16)
                        } else {
                            Image(systemName: p.icon)
                                .font(.system(size: 11, weight: .semibold))
                        }
                        Text(LocalizedStringKey(p.rawValue))
                            .font(BeansFont.appFont(13, .semibold))
                    }
                    .foregroundStyle(source == p ? Color.white : Color.beansComment)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background {
                        if source == p {
                            Capsule().fill(p.tint)
                        } else {
                            Capsule().fill(.clear)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
                .background { BeansSurface(shape: Capsule()) }
                .clipShape(Capsule())
        .beansCardShadow(radius: isNativeClean ? 1 : 6, y: isNativeClean ? 0.5 : 2)
    }

    /// 打开云同步面板前：先把所有已登录平台的歌单拉全，避免「明明登录了却显示未登录/无歌单」。
    /// 各平台的歌单数组原本只在切到该平台时才懒加载，同步面板会读到空数组。
    private func prepareAndShowCloudSync() {
        BeansHaptics.tap()
        // 关键：先把面板弹出来，再去后台补歌单。
        // 旧实现要等所有平台请求跑完才 show，任何一个平台超时（18s）都会让按钮看起来「点了没反应」，
        // 期间还在主线程上做解码，App 会明显卡住。
        if !showCloudSyncSheet { showCloudSyncSheet = true }
        Task { await refreshCloudSyncSources() }
    }

    /// 后台补齐各平台歌单：只更新 @State，不阻塞弹窗
    private func refreshCloudSyncSources() async {
        await withTaskGroup(of: Void.self) { group in
            if platformPrefs.isEnabled(SearchProvider.netease) && auth.isLoggedIn {
                group.addTask { await auth.loadLibrary(force: false) }
            }
            if platformPrefs.isEnabled(SearchProvider.qq) && qqAuth.isLoggedIn {
                group.addTask { await loadQQPlaylists(force: false) }
            }
            if platformPrefs.isEnabled(SearchProvider.kugou) && kugouAuth.isLoggedIn {
                group.addTask { await loadKugouPlaylists(force: false) }
            }
            if platformPrefs.isEnabled(SearchProvider.bodian) && bodianAuth.isLoggedIn {
                group.addTask { await loadBodianPlaylists(force: false) }
            }
            if platformPrefs.isEnabled(SearchProvider.kuwo) && kuwoAuth.isLoggedIn {
                group.addTask { await loadKuwoPlaylists(force: false) }
            }
            if platformPrefs.isEnabled(SearchProvider.migu) && miguAuth.isLoggedIn {
                group.addTask { await loadMiguPlaylists(force: false) }
            }
        }
    }

    private func refreshCurrentSource(force: Bool) async {
        switch source {
        case .netease:
            await auth.loadLibrary(force: force)
        case .qq:
            await loadQQPlaylists(force: force)
        case .kugou:
            await loadKugouPlaylists(force: force)
        case .migu:
            await loadMiguPlaylists(force: force)
        case .bodian:
            await loadBodianPlaylists(force: force)
        case .kuwo:
            await loadKuwoPlaylists(force: force)
        }
    }

    /// QQ 模式整体内容：用户歌单（创建 + 收藏同步）
    private var qqSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            qqPlaylistsSection
        }
    }

    /// 酷狗模式整体内容：只保留同步歌单
    private var kugouSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            kugouPlaylistsSection
        }
    }

    /// 咪咕模式整体内容：咪咕无账号体系，只展示本地红心收藏
    private var miguSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "咪咕红心收藏", trailing: favorites.miguFavoriteSongs.isEmpty ? nil : "\(favorites.miguFavoriteSongs.count) 首")
            if favorites.miguFavoriteSongs.isEmpty {
                EmptyStateView(icon: "heart", text: "还没有咪咕收藏\n在咪咕歌曲上点 ♡ 后会出现在这里")
            } else {
                VStack(spacing: 0) {
                    ForEach(favorites.miguFavoriteSongs, id: \.identityKey) { song in
                        SongCell(song: song, suppressNativeCleanRowGlass: isNativeClean) {
                            playMiguFavorite(song)
                        }
                        Divider().overlay(Color.beansComment.opacity(0.15))
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background {
                    BeansGlass(shape: RoundedRectangle(cornerRadius: 22, style: .continuous))
                }
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .beansCardShadow(radius: 8, y: 3)
            }
        }
    }

    private func playMiguFavorite(_ song: Song) {
        let list = favorites.miguFavoriteSongs
        guard let index = list.firstIndex(where: { $0.identityKey == song.identityKey }) else { return }
        player.play(songs: list, startAt: index)
    }

    /// 我的 QQ 歌单（登录后从 QQ 音乐拉取）
    private var qqPlaylistsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "我的 QQ 歌单", trailing: qqAuth.isLoggedIn ? (qqPlaylists.isEmpty ? "新建" : "新建 · \(qqPlaylists.count) 个") : nil) {
                if qqAuth.isLoggedIn {
                    BeansHaptics.tap()
                    newPlaylistName = ""
                    showCreatePlaylist = true
                }
            }
            if !qqAuth.isLoggedIn {
                EmptyStateView(icon: "music.note.list", text: "登录 QQ 音乐后即可查看你的歌单")
            } else if qqLoading {
                LoadingStateView()
            } else if qqPlaylists.isEmpty {
                EmptyStateView(icon: "music.note.list", text: "暂无 QQ 歌单")
            } else {
                VStack(spacing: 0) {
                    ForEach(orderedQQPlaylists) { playlist in
                        Button {
                            openRoute(LibraryRoute.playlist(playlist))
                        } label: {
                            HStack(spacing: 12) {
                                CoverImage(url: playlist.coverURL, size: 56, cornerRadius: 12)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(playlist.name)
                                        .font(BeansFont.appFont(15, .medium))
                                        .foregroundStyle(Color.beansLabel)
                                        .lineLimit(1)
                                    Text(beansSongCountText(playlist.trackCount))
                                        .font(BeansFont.appFont(12))
                                        .foregroundStyle(Color.beansComment)
                                }
                                Spacer(minLength: 8)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Color.beansComment.opacity(0.6))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button {
                                BeansHaptics.tap()
                                requestDelete(playlist)
                            } label: {
                                Label("删除歌单", systemImage: "trash")
                            }
                        }
                        Divider().overlay(Color.beansComment.opacity(0.12))
                    }
                }
                .padding(.vertical, 6)
                .background {
                                        BeansGlass(shape: RoundedRectangle(cornerRadius: 22, style: .continuous))
                }
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .beansCardShadow(radius: 8, y: 3)
            }
        }
    }

    /// 波点模式整体内容：云端歌单（自建 / 收藏 / 我喜欢）+ 本地红心兜底
    private var bodianSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            SectionHeader(
                title: "我的波点歌单",
                trailing: bodianAuth.isLoggedIn ? "\(bodianPlaylists.count) 个" : nil
            )
            if !bodianAuth.isLoggedIn {
                EmptyStateView(icon: "qrcode", text: "扫码登录波点音乐后即可同步云端歌单")
            } else if bodianLoading {
                LoadingStateView()
            } else if bodianPlaylists.isEmpty {
                EmptyStateView(icon: "music.note.list", text: "暂未同步到波点歌单，下拉刷新试试")
            } else {
                VStack(spacing: 0) {
                    ForEach(orderedBodianPlaylists, id: \.uniqueKey) { playlist in
                        Button {
                            openRoute(LibraryRoute.playlist(playlist))
                        } label: {
                            HStack(spacing: 12) {
                                CoverImage(url: playlist.coverURL, size: 56, cornerRadius: 12)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(playlist.name)
                                        .font(BeansFont.appFont(15, .medium))
                                        .foregroundStyle(Color.beansLabel)
                                        .lineLimit(1)
                                    Text(beansSongCountText(playlist.trackCount))
                                        .font(BeansFont.appFont(12))
                                        .foregroundStyle(Color.beansComment)
                                }
                                Spacer(minLength: 8)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Color.beansComment.opacity(0.6))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        Divider().overlay(Color.beansComment.opacity(0.12))
                    }
                }
                .padding(.vertical, 6)
                .background {
                    BeansGlass(shape: RoundedRectangle(cornerRadius: 22, style: .continuous))
                }
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .beansCardShadow(radius: 8, y: 3)
            }

            SectionHeader(
                title: "波点红心收藏",
                trailing: favorites.bodianFavoriteSongs.isEmpty ? nil : "\(favorites.bodianFavoriteSongs.count) 首"
            )
            if favorites.bodianFavoriteSongs.isEmpty {
                EmptyStateView(icon: "heart", text: "还没有波点收藏\n在波点歌曲上点 ♡ 后会出现在这里")
            } else {
                VStack(spacing: 0) {
                    ForEach(favorites.bodianFavoriteSongs, id: \.identityKey) { song in
                        SongCell(song: song, suppressNativeCleanRowGlass: isNativeClean) {
                            if let index = favorites.bodianFavoriteSongs.firstIndex(of: song) {
                                player.play(songs: favorites.bodianFavoriteSongs, startAt: index)
                            }
                        }
                        Divider().overlay(Color.beansComment.opacity(0.15))
                    }
                }
                .padding(.vertical, 6)
                .background {
                    BeansGlass(shape: RoundedRectangle(cornerRadius: 22, style: .continuous))
                }
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
        }
    }

    private var kugouPlaylistsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "我的酷狗歌单", trailing: kugouAuth.isLoggedIn ? "\(kugouPlaylists.count) 个" : nil)
            if !kugouAuth.isLoggedIn {
                EmptyStateView(icon: "music.note.list", text: "登录酷狗音乐后即可同步云端歌单")
            } else if kugouLoading {
                LoadingStateView()
            } else if kugouPlaylists.isEmpty {
                EmptyStateView(icon: "music.note.list", text: "暂未同步到酷狗歌单，下拉刷新试试")
            } else {
                VStack(spacing: 0) {
                    ForEach(orderedKugouPlaylists) { playlist in
                        Button {
                            openRoute(LibraryRoute.playlist(playlist))
                        } label: {
                            HStack(spacing: 12) {
                                CoverImage(url: playlist.coverURL, size: 56, cornerRadius: 12)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(playlist.name)
                                        .font(BeansFont.appFont(15, .medium))
                                        .foregroundStyle(Color.beansLabel)
                                        .lineLimit(1)
                                    Text(beansSongCountText(playlist.trackCount))
                                        .font(BeansFont.appFont(12))
                                        .foregroundStyle(Color.beansComment)
                                }
                                Spacer(minLength: 8)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Color.beansComment.opacity(0.6))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        Divider().overlay(Color.beansComment.opacity(0.12))
                    }
                }
                .padding(.vertical, 6)
                .background {
                    BeansGlass(shape: RoundedRectangle(cornerRadius: 22, style: .continuous))
                }
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .beansCardShadow(radius: 8, y: 3)
            }
        }
    }

    // MARK: - 歌单新建 / 删除

    private func loadQQPlaylists(force: Bool = false) async {
        guard qqAuth.isLoggedIn else {
            qqPlaylists = []
            qqLoading = false
            return
        }
        let cache = SyncedPlaylistCache.shared
        if qqPlaylists.isEmpty,
           let cached = cache.cachedPlaylists(source: .qq, accountID: qqCacheAccountID) {
            qqPlaylists = cached.playlists
            qqSavedAt = cached.savedAt
        }
        // 持久化缓存仍新鲜时直接展示；下拉刷新会跳过缓存。
        if !force, !qqPlaylists.isEmpty, Date().timeIntervalSince(qqSavedAt) < cache.playlistTTL { return }
        qqLoading = qqPlaylists.isEmpty
        let list = (try? await QQMusicAPI.shared.userPlaylists(uin: qqAuth.uin)) ?? []
        if !list.isEmpty {
            qqPlaylists = list
            cache.savePlaylists(list, source: .qq, accountID: qqCacheAccountID)
        }
        await favorites.syncQQFromCloud()
        if !list.isEmpty { qqSavedAt = Date() }
        qqLoading = false
        // 封面兜底：歌单封面缺失时默认取第一首歌曲封面（列表先展示，封面后台补齐）
        if !list.isEmpty { await fillQQPlaylistCovers(list) }
        if !qqPlaylists.isEmpty {
            cache.savePlaylists(qqPlaylists, source: .qq, accountID: qqCacheAccountID)
        }
    }

    private func loadKugouPlaylists(force: Bool = false) async {
        guard kugouAuth.isLoggedIn else {
            kugouPlaylists = []
            kugouLoading = false
            return
        }
        let cache = SyncedPlaylistCache.shared
        if kugouPlaylists.isEmpty,
           let cached = cache.cachedPlaylists(source: .kugou, accountID: kugouCacheAccountID) {
            kugouPlaylists = cached.playlists
            kugouSavedAt = cached.savedAt
        }
        if !force, !kugouPlaylists.isEmpty, Date().timeIntervalSince(kugouSavedAt) < cache.playlistTTL { return }
        kugouLoading = kugouPlaylists.isEmpty
        do {
            let list = try await KugouMusicAPI.shared.userPlaylists()
            if !list.isEmpty {
                kugouPlaylists = list
                kugouSavedAt = Date()
                cache.savePlaylists(list, source: .kugou, accountID: kugouCacheAccountID)
            }
        } catch {
            BeansLogger.shared.log("酷狗歌单同步失败：\(error.localizedDescription)", level: .error)
            if kugouPlaylists.isEmpty { kugouPlaylists = [] }
        }
        kugouLoading = false
    }

    private func loadBodianPlaylists(force: Bool = false) async {
        guard bodianAuth.isLoggedIn else {
            bodianPlaylists = []
            bodianLoading = false
            return
        }
        let cache = SyncedPlaylistCache.shared
        if bodianPlaylists.isEmpty,
           let cached = cache.cachedPlaylists(source: .bodian, accountID: bodianCacheAccountID) {
            bodianPlaylists = cached.playlists
            bodianSavedAt = cached.savedAt
        }
        if !force, !bodianPlaylists.isEmpty, Date().timeIntervalSince(bodianSavedAt) < cache.playlistTTL { return }
        bodianLoading = bodianPlaylists.isEmpty
        do {
            let list = try await BodianMusicAPI.shared.userPlaylists()
            if !list.isEmpty {
                bodianPlaylists = list
                bodianSavedAt = Date()
                cache.savePlaylists(list, source: .bodian, accountID: bodianCacheAccountID)
            }
            // 歌单拿到后再同步一次「我喜欢」，红心收藏也能跨设备
            await favorites.syncBodianFromCloud()
        } catch {
            BeansLogger.shared.log("波点歌单同步失败：\(error.localizedDescription)", level: .error)
        }
        bodianLoading = false
    }

    private func loadKuwoPlaylists(force: Bool = false) async {
        guard kuwoAuth.isLoggedIn else {
            kuwoPlaylists = []
            kuwoLoading = false
            return
        }
        let cache = SyncedPlaylistCache.shared
        if kuwoPlaylists.isEmpty,
           let cached = cache.cachedPlaylists(source: .kuwo, accountID: kuwoCacheAccountID) {
            kuwoPlaylists = cached.playlists
            kuwoSavedAt = cached.savedAt
        }
        if !force, !kuwoPlaylists.isEmpty, Date().timeIntervalSince(kuwoSavedAt) < cache.playlistTTL { return }
        kuwoLoading = kuwoPlaylists.isEmpty
        // 登录时 WebView 已经抓到过歌单，先用它兜底；接口能通再覆盖
        if kuwoPlaylists.isEmpty, !kuwoAuth.playlists.isEmpty {
            kuwoPlaylists = kuwoAuth.playlists
        }
        do {
            let list = try await KuwoMusicAPI.shared.fetchMyPlaylists()
            if !list.isEmpty {
                kuwoPlaylists = list
                kuwoSavedAt = Date()
                kuwoAuth.savePlaylists(list)
                cache.savePlaylists(list, source: .kuwo, accountID: kuwoCacheAccountID)
            }
        } catch {
            BeansLogger.shared.log("酷我歌单同步失败：\(error.localizedDescription)", level: .warn)
        }
        kuwoLoading = false
    }

    private func loadMiguPlaylists(force: Bool = false) async {
        guard miguAuth.isLoggedIn else {
            miguPlaylists = []
            miguLoading = false
            return
        }
        let cache = SyncedPlaylistCache.shared
        if miguPlaylists.isEmpty,
           let cached = cache.cachedPlaylists(source: .migu, accountID: miguCacheAccountID) {
            miguPlaylists = cached.playlists
            miguSavedAt = cached.savedAt
        }
        if !force, !miguPlaylists.isEmpty, Date().timeIntervalSince(miguSavedAt) < cache.playlistTTL { return }
        miguLoading = miguPlaylists.isEmpty
        if miguPlaylists.isEmpty, !miguAuth.playlists.isEmpty {
            miguPlaylists = miguAuth.playlists
        }
        let list = await MiguWebPlaylistLoader.load(cookie: miguAuth.cookieHeader)
        if !list.isEmpty {
            miguPlaylists = list
            miguSavedAt = Date()
            miguAuth.savePlaylists(list)
            cache.savePlaylists(list, source: .migu, accountID: miguCacheAccountID)
        }
        miguLoading = false
    }

    private func fillQQPlaylistCovers(_ list: [Playlist]) async {
        let missing = list.filter { $0.coverURL == nil }
        guard !missing.isEmpty else { return }
        var covers: [Int: URL] = [:]
        await withTaskGroup(of: (Int, URL?).self) { group in
            for playlist in missing {
                group.addTask {
                    let cover = try? await QQMusicAPI.shared.firstSongCover(listID: playlist.id)
                    return (playlist.id, cover)
                }
            }
            for await (id, url) in group {
                if let url { covers[id] = url }
            }
        }
        for i in qqPlaylists.indices where qqPlaylists[i].coverURL == nil {
            if let url = covers[qqPlaylists[i].id] { qqPlaylists[i].coverURL = url }
        }
    }

    private func createPlaylist() {
        let name = newPlaylistName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            ToastCenter.shared.show("请输入歌单名称")
            return
        }
        switch source {
        case .netease:
            guard auth.isLoggedIn else {
                ToastCenter.shared.show("请先登录后再创建歌单")
                return
            }
            Task {
                do {
                    _ = try await NetEaseAPI.shared.createPlaylist(name: name)
                    ToastCenter.shared.show("歌单「\(name)」已创建")
                    newPlaylistName = ""
                    await auth.loadLibrary()
                } catch {
                    ToastCenter.shared.show("创建失败：\(error.localizedDescription)")
                }
            }
        case .qq:
            guard qqAuth.isLoggedIn else {
                ToastCenter.shared.show("请先登录 QQ 音乐后再创建歌单")
                return
            }
            Task {
                do {
                    let ok = try await QQMusicAPI.shared.createPlaylist(name: name)
                    if ok {
                        ToastCenter.shared.show("歌单「\(name)」已创建")
                        newPlaylistName = ""
                        await loadQQPlaylists(force: true)
                    } else {
                        ToastCenter.shared.show("创建失败，请确认已登录 QQ 音乐")
                    }
                } catch {
                    ToastCenter.shared.show("创建失败：\(error.localizedDescription)")
                }
            }
        case .kugou:
            ToastCenter.shared.show("酷狗歌单暂不支持新建")
        case .migu:
            ToastCenter.shared.show("咪咕暂不支持新建歌单")
        case .bodian:
            ToastCenter.shared.show("波点歌单暂不支持新建")
        case .kuwo:
            ToastCenter.shared.show("酷我歌单请到酷我 App 或网页版新建")
        }
    }

    private func requestDelete(_ playlist: Playlist) {
        pendingDelete = playlist
        showDeleteConfirm = true
    }

    private func confirmDeletePlaylist() {
        guard let playlist = pendingDelete else { return }
        // 歌单区现在混排所有平台，按歌单自身来源走对应接口，不能用当前选中的平台
        switch playlist.source {
        case .netease:
            Task {
                do {
                    let ok = try await NetEaseAPI.shared.deletePlaylist(id: playlist.id)
                    if ok {
                        ToastCenter.shared.show("已删除歌单「\(playlist.name)」")
                        await auth.loadLibrary()
                    } else {
                        ToastCenter.shared.show("删除失败，请稍后再试")
                    }
                } catch {
                    ToastCenter.shared.show("删除失败：\(error.localizedDescription)")
                }
            }
        case .qq:
            Task {
                do {
                    let ok = try await QQMusicAPI.shared.deletePlaylist(dirid: playlist.id)
                    if ok {
                        ToastCenter.shared.show("已删除歌单「\(playlist.name)」")
                        await loadQQPlaylists(force: true)
                    } else {
                        ToastCenter.shared.show("删除失败，请确认已登录 QQ 音乐")
                    }
                } catch {
                    ToastCenter.shared.show("删除失败：\(error.localizedDescription)")
                }
            }
        case .kugou:
            ToastCenter.shared.show("酷狗歌单暂不支持删除")
        case .migu:
            ToastCenter.shared.show("咪咕暂不支持删除歌单")
        case .bodian:
            ToastCenter.shared.show("波点歌单暂不支持删除")
        case .kuwo:
            ToastCenter.shared.show("酷我歌单请到酷我 App 或网页版删除")
        case .qishui:
            ToastCenter.shared.show("汽水歌单请到汽水音乐 App 删除")
        }
    }

    private func playFromHistory(_ song: Song) {
        if let index = player.history.firstIndex(of: song) {
            player.play(songs: player.history, startAt: index)
        }
    }
}

