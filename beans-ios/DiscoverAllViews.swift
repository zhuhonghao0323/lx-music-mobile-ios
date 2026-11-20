import SwiftUI

// MARK: - 平台品牌图标

/// 平台 logo：有官方图片资源时用图片，没有时用主题色圆角图标兜底。
struct PlatformBrandLogo: View {
    let provider: SearchProvider
    var size: CGFloat = 42

    var body: some View {
        Group {
            if let imageName = provider.brandImageName {
                Image(imageName)
                    .resizable()
                    .scaledToFit()
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
                        .fill(provider.tint)
                    Image(systemName: provider.icon)
                        .font(.system(size: size * 0.46, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.26, style: .continuous))
        .accessibilityHidden(true)
    }
}


// MARK: - 全部排行榜

/// 排行榜「全部」页：把当前平台的所有榜单摊平展示，顶部可切换平台。
struct AllChartsView: View {
    var onOpen: (DiscoverRoute) -> Void

    @ObservedObject private var platformPrefs = PlatformPreferenceStore.shared
    @AppStorage("beans.homeSource") private var homeSourceRaw = SearchProvider.netease.rawValue
    @AppStorage("beans.uiStyle") private var uiStyleRaw = BeansUIStyle.liquid.rawValue

    @State private var neteaseCharts: [TopList] = []
    @State private var qqCharts: [QQTopInfo] = []
    @State private var kugouCharts: [KugouTopInfo] = []
    @State private var loading = false
    @State private var errorText: String?
    @State private var loadedSources: Set<String> = []

    /// 咪咕无公开榜单/歌单接口，这里只列出能提供内容的平台
    private var providers: [SearchProvider] {
        platformPrefs.enabledSearchProviders.filter { $0.supportsHomeFeed }
    }
    private var source: SearchProvider {
        guard let saved = SearchProvider(rawValue: homeSourceRaw), providers.contains(saved) else {
            return providers.first ?? .netease
        }
        return saved
    }
    private var isNativeClean: Bool { BeansUIStyle(rawValue: uiStyleRaw) == .nativeClean }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                platformChips
                if loading && chartCount == 0 {
                    LoadingStateView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                } else if let errorText, chartCount == 0 {
                    ErrorStateView(message: errorText) {
                        Task { await load(force: true) }
                    }
                } else if chartCount == 0 {
                    EmptyStateView(icon: "chart.bar", text: "该平台暂时没有榜单")
                        .padding(.top, 40)
                } else {
                    chartList
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 160)
            .frame(maxWidth: 860)
            .frame(maxWidth: .infinity)
        }
        .background { GlassBackdrop() }
        .navigationTitle("全部排行榜")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: source) { await load(force: false) }
        .refreshable { await load(force: true) }
    }

    private var chartCount: Int {
        switch source {
        case .netease: return neteaseCharts.count
        case .qq: return qqCharts.count
        case .kugou: return kugouCharts.count
        case .migu: return 0
        }
    }

    private var platformChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(providers) { provider in
                    Button {
                        BeansHaptics.tap()
                        homeSourceRaw = provider.rawValue
                    } label: {
                        HStack(spacing: 6) {
                            if let imageName = provider.brandImageName {
                                Image(imageName)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 14, height: 14)
                            } else {
                                Image(systemName: provider.icon)
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            Text(LocalizedStringKey(provider.rawValue))
                                .font(BeansFont.appFont(13, .semibold))
                        }
                        .foregroundStyle(source == provider ? Color.white : Color.beansComment)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background {
                            if source == provider {
                                Capsule().fill(provider.tint)
                            } else {
                                BeansSurface(shape: Capsule())
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }

    @ViewBuilder
    private var chartList: some View {
        VStack(spacing: 0) {
            switch source {
            case .netease:
                ForEach(Array(neteaseCharts.enumerated()), id: \.offset) { index, chart in
                    row(index: index, name: chart.name, subtitle: chart.updateFrequency, coverURL: chart.coverURL) {
                        onOpen(.topList(chart))
                    }
                    if index < neteaseCharts.count - 1 {
                        divider
                    }
                }
            case .qq:
                ForEach(Array(qqCharts.enumerated()), id: \.offset) { index, chart in
                    row(index: index, name: chart.name, subtitle: chart.subTitle, coverURL: chart.coverURL) {
                        onOpen(.qqTopList(chart))
                    }
                    if index < qqCharts.count - 1 {
                        divider
                    }
                }
            case .kugou:
                ForEach(Array(kugouCharts.enumerated()), id: \.offset) { index, chart in
                    row(index: index, name: chart.name, subtitle: chart.updateFrequency, coverURL: chart.coverURL) {
                        onOpen(.kugouTopList(chart))
                    }
                    if index < kugouCharts.count - 1 {
                        divider
                    }
                }
            case .migu:
                EmptyView()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background {
            if isNativeClean {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.primary.opacity(0.04))
            } else {
                BeansGlass(shape: RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var divider: some View {
        Divider().overlay(Color.beansComment.opacity(0.12))
    }

    private func row(
        index: Int,
        name: String,
        subtitle: String,
        coverURL: URL?,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            BeansHaptics.tap()
            action()
        } label: {
            HStack(spacing: 12) {
                Text("\(index + 1)")
                    .font(BeansFont.appFont(15, .bold, .rounded))
                    .foregroundStyle(index < 3 ? Color.beansAmber : Color.beansComment)
                    .frame(width: 24)
                CoverImage(url: coverURL, size: 52, cornerRadius: 12)
                VStack(alignment: .leading, spacing: 3) {
                    Text(name)
                        .font(BeansFont.appFont(15, .semibold))
                        .foregroundStyle(Color.beansLabel)
                        .lineLimit(1)
                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(BeansFont.appFont(12))
                            .foregroundStyle(Color.beansComment)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.beansComment.opacity(0.6))
            }
            .padding(.vertical, 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @MainActor
    private func load(force: Bool) async {
        let target = source
        if !force, loadedSources.contains(target.rawValue) { return }
        loading = true
        errorText = nil
        do {
            switch target {
            case .netease:
                if force || neteaseCharts.isEmpty {
                    neteaseCharts = try await NetEaseAPI.shared.topLists()
                }
            case .qq:
                if force || qqCharts.isEmpty {
                    qqCharts = try await QQMusicAPI.shared.topLists()
                }
            case .kugou:
                if force || kugouCharts.isEmpty {
                    kugouCharts = try await KugouMusicAPI.shared.topLists(limit: 50)
                }
            case .migu:
                // 咪咕暂未开放榜单接口
                break
            }
            loadedSources.insert(target.rawValue)
        } catch {
            errorText = error.localizedDescription
        }
        loading = false
    }
}

// MARK: - 全部歌单

/// 歌单广场「全部」页：分类 + 排序 + 收藏，网易云走官方分类接口。
struct PlaylistSquareView: View {
    var onOpen: (DiscoverRoute) -> Void

    @ObservedObject private var platformPrefs = PlatformPreferenceStore.shared
    @ObservedObject private var favorites = FavoritePlaylistStore.shared
    @AppStorage("beans.homeSource") private var homeSourceRaw = SearchProvider.netease.rawValue
    @AppStorage("beans.uiStyle") private var uiStyleRaw = BeansUIStyle.liquid.rawValue

    @State private var playlists: [Playlist] = []
    @State private var categories: [String] = []
    @State private var selectedCategory = "全部"
    @State private var sort: SortOption = .hot
    @State private var limit = 30
    @State private var loading = false
    @State private var errorText: String?

    enum SortOption: String, CaseIterable, Identifiable {
        case hot
        case new

        var id: String { rawValue }
        var title: String {
            switch self {
            case .hot: return "最热"
            case .new: return "最新"
            }
        }
    }

    /// 咪咕无公开榜单/歌单接口，这里只列出能提供内容的平台
    private var providers: [SearchProvider] {
        platformPrefs.enabledSearchProviders.filter { $0.supportsHomeFeed }
    }
    private var source: SearchProvider {
        guard let saved = SearchProvider(rawValue: homeSourceRaw), providers.contains(saved) else {
            return providers.first ?? .netease
        }
        return saved
    }
    private var isNativeClean: Bool { BeansUIStyle(rawValue: uiStyleRaw) == .nativeClean }

    var body: some View {
        GeometryReader { proxy in
            let side = max(132, (proxy.size.width - 32 - 12) / 2)
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    platformChips
                    if source == .netease {
                        categoryChips
                        sortChips
                    }
                    if loading && playlists.isEmpty {
                        LoadingStateView()
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                    } else if let errorText, playlists.isEmpty {
                        ErrorStateView(message: errorText) {
                            Task { await load(reset: true) }
                        }
                    } else if playlists.isEmpty {
                        EmptyStateView(icon: "music.note.list", text: "没有取到歌单")
                            .padding(.top, 40)
                    } else {
                        grid(side: side)
                        loadMoreButton
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 160)
                .frame(maxWidth: 860)
                .frame(maxWidth: .infinity)
            }
        }
        .background { GlassBackdrop() }
        .navigationTitle("全部歌单")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: taskKey) { await load(reset: true) }
        .refreshable { await load(reset: true) }
    }

    private var taskKey: String { "\(source.rawValue)|\(selectedCategory)|\(sort.rawValue)" }

    private var platformChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(providers) { provider in
                    Button {
                        BeansHaptics.tap()
                        if source != provider {
                            playlists = []
                            selectedCategory = "全部"
                            limit = 30
                            homeSourceRaw = provider.rawValue
                        }
                    } label: {
                        HStack(spacing: 6) {
                            if let imageName = provider.brandImageName {
                                Image(imageName)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 14, height: 14)
                            } else {
                                Image(systemName: provider.icon)
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            Text(LocalizedStringKey(provider.rawValue))
                                .font(BeansFont.appFont(13, .semibold))
                        }
                        .foregroundStyle(source == provider ? Color.white : Color.beansComment)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background {
                            if source == provider {
                                Capsule().fill(provider.tint)
                            } else {
                                BeansSurface(shape: Capsule())
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(categories, id: \.self) { category in
                    Button {
                        BeansHaptics.tap()
                        guard selectedCategory != category else { return }
                        selectedCategory = category
                        limit = 30
                    } label: {
                        Text(LocalizedStringKey(category))
                            .font(BeansFont.appFont(12, .semibold))
                            .foregroundStyle(selectedCategory == category ? Color.white : Color.beansLabel)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background {
                                if selectedCategory == category {
                                    Capsule().fill(Color.beansAmber)
                                } else {
                                    BeansSurface(shape: Capsule())
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var sortChips: some View {
        HStack(spacing: 8) {
            ForEach(SortOption.allCases) { option in
                Button {
                    BeansHaptics.tap()
                    guard sort != option else { return }
                    sort = option
                    limit = 30
                } label: {
                    Text(option.title)
                        .font(BeansFont.appFont(12, .semibold))
                        .foregroundStyle(sort == option ? Color.white : Color.beansLabel)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background {
                            if sort == option {
                                Capsule().fill(Color.beansAmber)
                            } else {
                                BeansSurface(shape: Capsule())
                            }
                        }
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
    }

    private func grid(side: CGFloat) -> some View {
        LazyVGrid(
            columns: [GridItem(.fixed(side), spacing: 12), GridItem(.fixed(side), spacing: 12)],
            alignment: .leading,
            spacing: 18
        ) {
            ForEach(Array(playlists.enumerated()), id: \.offset) { _, playlist in
                playlistCard(playlist, side: side)
            }
        }
    }

    private func playlistCard(_ playlist: Playlist, side: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                Button {
                    BeansHaptics.tap()
                    onOpen(.playlist(playlist))
                } label: {
                    CoverImage(url: playlist.coverURL, size: side, cornerRadius: 16)
                }
                .buttonStyle(GlassPressButtonStyle(scale: 0.97))

                Button {
                    BeansHaptics.select()
                    let liked = favorites.toggle(playlist)
                    ToastCenter.shared.show(liked ? "已收藏歌单" : "已取消收藏")
                } label: {
                    Image(systemName: favorites.contains(playlist) ? "heart.fill" : "heart")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(favorites.contains(playlist) ? Color.beansAmber : Color.white)
                        .frame(width: 30, height: 30)
                        .background(.black.opacity(0.32), in: Circle())
                }
                .buttonStyle(.plain)
                .padding(8)
                .accessibilityLabel(favorites.contains(playlist) ? "取消收藏歌单" : "收藏歌单")
            }
            Button {
                BeansHaptics.tap()
                onOpen(.playlist(playlist))
            } label: {
                VStack(alignment: .leading, spacing: 3) {
                    Text(playlist.name)
                        .font(BeansFont.appFont(14, .semibold))
                        .foregroundStyle(Color.beansLabel)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .frame(width: side, alignment: .leading)
                    if playlist.trackCount > 0 {
                        Text(beansSongCountText(playlist.trackCount))
                            .font(BeansFont.appFont(11))
                            .foregroundStyle(Color.beansComment)
                    }
                }
            }
            .buttonStyle(.plain)
        }
        .frame(width: side, alignment: .leading)
    }

    @ViewBuilder
    private var loadMoreButton: some View {
        if playlists.count >= limit - 2 {
            Button {
                BeansHaptics.tap()
                limit += 30
                Task { await load(reset: false) }
            } label: {
                HStack(spacing: 6) {
                    if loading {
                        ProgressView().scaleEffect(0.7)
                    } else {
                        Image(systemName: "arrow.down.circle")
                    }
                    Text("加载更多")
                }
                .font(BeansFont.appFont(13, .semibold))
                .foregroundStyle(Color.beansAmber)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(loading)
        }
    }

    @MainActor
    private func load(reset: Bool) async {
        if reset {
            loading = true
            errorText = nil
        } else {
            loading = true
        }
        if source == .netease, categories.isEmpty {
            let list = await NetEaseAPI.shared.playlistCatlist()
            let trimmed = Array(list.prefix(40))
            await MainActor.run {
                categories = ["全部"] + trimmed
            }
        }
        do {
            let result: [Playlist]
            switch source {
            case .netease:
                result = try await NetEaseAPI.shared.playlistSquare(
                    cat: selectedCategory,
                    order: sort == .hot ? "hot" : "new",
                    limit: limit
                )
            case .qq:
                result = try await QQMusicAPI.shared.hotPlaylists(limit: limit)
            case .kugou:
                result = try await KugouMusicAPI.shared.recommendPlaylists(limit: limit)
            case .migu:
                result = []
            }
            playlists = result
            errorText = nil
        } catch {
            if playlists.isEmpty { errorText = error.localizedDescription }
        }
        loading = false
    }
}

// MARK: - 我的歌单

/// 主页「我的歌单」与「我的歌单」页共用的条目：本地自建歌单 + 收藏歌单。
struct MyPlaylistEntry: Identifiable, Hashable {
    let id: String
    let name: String
    let coverURL: URL?
    let subtitle: String
    let route: DiscoverRoute
    let isLocal: Bool

    static func all(local: [LocalPlaylist], favorites: [Playlist]) -> [MyPlaylistEntry] {
        let localItems = local.map { playlist in
            MyPlaylistEntry(
                id: "local-\(playlist.id.uuidString)",
                name: playlist.name,
                coverURL: playlist.songs.first?.coverURL,
                subtitle: "本机 · \(playlist.songs.count) 首",
                route: .localPlaylist(playlist.id),
                isLocal: true
            )
        }
        let favoriteItems = favorites.map { playlist in
            MyPlaylistEntry(
                id: "\(playlist.source.rawValue)-\(playlist.id)",
                name: playlist.name,
                coverURL: playlist.coverURL,
                subtitle: playlist.trackCount > 0
                    ? "\(FavoritePlaylistsView.providerTitle(playlist.source)) · \(playlist.trackCount) 首"
                    : FavoritePlaylistsView.providerTitle(playlist.source),
                route: .playlist(playlist),
                isLocal: false
            )
        }
        return localItems + favoriteItems
    }
}

/// 我的歌单列表页：本地自建歌单 + 收藏的广场歌单。
struct FavoritePlaylistsView: View {
    var onOpen: (DiscoverRoute) -> Void

    @ObservedObject private var favorites = FavoritePlaylistStore.shared
    @ObservedObject private var localLibrary = LocalLibraryStore.shared
    @AppStorage("beans.uiStyle") private var uiStyleRaw = BeansUIStyle.liquid.rawValue

    private var isNativeClean: Bool { BeansUIStyle(rawValue: uiStyleRaw) == .nativeClean }

    private var entries: [MyPlaylistEntry] {
        MyPlaylistEntry.all(local: localLibrary.playlists, favorites: favorites.playlists)
    }

    static func providerTitle(_ source: SongSource) -> String {
        switch source {
        case .netease: return "网易云音乐"
        case .qq: return "QQ音乐"
        case .kugou: return "酷狗音乐"
        case .migu: return "咪咕音乐"
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if entries.isEmpty {
                    EmptyStateView(
                        icon: "heart",
                        text: "还没有歌单\n在歌单广场点 ♡ 收藏，或在音乐库新建本地歌单"
                    )
                    .padding(.top, 60)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                            row(entry)
                            if index < entries.count - 1 {
                                Divider().overlay(Color.beansComment.opacity(0.12))
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background {
                        if isNativeClean {
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(Color.primary.opacity(0.04))
                        } else {
                            BeansGlass(shape: RoundedRectangle(cornerRadius: 22, style: .continuous))
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 160)
            .frame(maxWidth: 860)
            .frame(maxWidth: .infinity)
        }
        .background { GlassBackdrop() }
        .navigationTitle("我的歌单")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ entry: MyPlaylistEntry) -> some View {
        HStack(spacing: 12) {
            Button {
                BeansHaptics.tap()
                onOpen(entry.route)
            } label: {
                HStack(spacing: 12) {
                    CoverImage(url: entry.coverURL, size: 52, cornerRadius: 12)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(entry.name)
                            .font(BeansFont.appFont(15, .semibold))
                            .foregroundStyle(Color.beansLabel)
                            .lineLimit(1)
                        Text(entry.subtitle)
                            .font(BeansFont.appFont(11))
                            .foregroundStyle(Color.beansComment)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 8)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if !entry.isLocal, case let .playlist(playlist) = entry.route {
                Button {
                    BeansHaptics.select()
                    favorites.remove(id: playlist.id, source: playlist.source)
                    ToastCenter.shared.show("已取消收藏")
                } label: {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.beansAmber)
                        .frame(width: 34, height: 34)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 9)
    }
}
