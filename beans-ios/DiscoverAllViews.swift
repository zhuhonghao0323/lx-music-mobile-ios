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

/// 聚合模式下统一的榜单条目：把三个平台的榜单结构抹平，方便混排展示。
struct ChartEntry: Identifiable {
    let id: String
    let name: String
    let subtitle: String
    let coverURL: URL?
    let route: DiscoverRoute
}

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

    /// 「全部」排在最前，其后是各启用平台；不提供排行榜的平台（咪咕、波点）不列出。
    private var providers: [SearchProvider] {
        let feedProviders = platformPrefs.enabledSearchProviders.filter { $0.supportsCharts }
        return [.all] + feedProviders
    }
    private var source: SearchProvider {
        guard let saved = SearchProvider(rawValue: homeSourceRaw), providers.contains(saved) else {
            return providers.first ?? .netease
        }
        return saved
    }
    private var isNativeClean: Bool { BeansUIStyle(rawValue: uiStyleRaw) == .nativeClean }

    /// 「全部」模式下的榜单分组（只有拿到数据的平台才出现）
    private var chartGroups: [(provider: SearchProvider, items: [ChartEntry])] {
        var groups: [(SearchProvider, [ChartEntry])] = []
        if !neteaseCharts.isEmpty {
            groups.append((.netease, neteaseCharts.map { chart in
                ChartEntry(
                    id: "netease-\(chart.id)",
                    name: chart.name,
                    subtitle: chart.updateFrequency,
                    coverURL: chart.coverURL,
                    route: .topList(chart)
                )
            }))
        }
        if !qqCharts.isEmpty {
            groups.append((.qq, qqCharts.map { chart in
                ChartEntry(
                    id: "qq-\(chart.id)",
                    name: chart.name,
                    subtitle: chart.subTitle,
                    coverURL: chart.coverURL,
                    route: .qqTopList(chart)
                )
            }))
        }
        if !kugouCharts.isEmpty {
            groups.append((.kugou, kugouCharts.map { chart in
                ChartEntry(
                    id: "kugou-\(chart.id)",
                    name: chart.name,
                    subtitle: chart.updateFrequency,
                    coverURL: chart.coverURL,
                    route: .kugouTopList(chart)
                )
            }))
        }
        return groups
    }

    /// 聚合模式下摊平后的榜单条目（用于空态/计数）
    private var allChartEntries: [ChartEntry] {
        chartGroups.flatMap(\.items)
    }

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
        case .migu, .bodian: return 0
        case .all: return allChartEntries.count
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
            case .migu, .bodian:
                EmptyView()
            case .all:
                ForEach(Array(chartGroups.enumerated()), id: \.offset) { _, group in
                    HStack(spacing: 8) {
                        PlatformBrandLogo(provider: group.provider, size: 18)
                        Text(LocalizedStringKey(group.provider.rawValue))
                            .font(BeansFont.appFont(13, .bold))
                            .foregroundStyle(Color.beansComment)
                        Spacer(minLength: 0)
                    }
                    .padding(.top, 12)
                    .padding(.bottom, 2)
                    ForEach(Array(group.items.enumerated()), id: \.element.id) { index, entry in
                        row(index: index, name: entry.name, subtitle: entry.subtitle, coverURL: entry.coverURL) {
                            onOpen(entry.route)
                        }
                        divider
                    }
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
            case .migu, .bodian:
                // 咪咕 / 波点暂未开放榜单接口
                break
            case .all:
                if force {
                    neteaseCharts = (try? await NetEaseAPI.shared.topLists()) ?? neteaseCharts
                    qqCharts = (try? await QQMusicAPI.shared.topLists()) ?? qqCharts
                    kugouCharts = (try? await KugouMusicAPI.shared.topLists(limit: 50)) ?? kugouCharts
                } else {
                    if neteaseCharts.isEmpty {
                        neteaseCharts = (try? await NetEaseAPI.shared.topLists()) ?? []
                    }
                    if qqCharts.isEmpty {
                        qqCharts = (try? await QQMusicAPI.shared.topLists()) ?? []
                    }
                    if kugouCharts.isEmpty {
                        kugouCharts = (try? await KugouMusicAPI.shared.topLists(limit: 50)) ?? []
                    }
                }
            }
            loadedSources.insert(target.rawValue)
        } catch {
            errorText = error.localizedDescription
        }
        loading = false
    }
}

// MARK: - 全部歌单

/// 歌单广场「全部」页：3 列封面网格 + 推荐/最热/最新 排序 + 分类筛选弹窗（热门 / 主题 / 场景 多选）。
struct PlaylistSquareView: View {
    var onOpen: (DiscoverRoute) -> Void

    @EnvironmentObject private var theme: ThemeStore
    @ObservedObject private var platformPrefs = PlatformPreferenceStore.shared
    @ObservedObject private var favorites = FavoritePlaylistStore.shared
    @AppStorage("beans.homeSource") private var homeSourceRaw = SearchProvider.netease.rawValue
    @AppStorage("beans.uiStyle") private var uiStyleRaw = BeansUIStyle.liquid.rawValue

    @State private var playlists: [Playlist] = []
    @State private var categories: [NetEasePlaylistCategory] = []
    @State private var selectedCategories: Set<String> = []
    @State private var sort: SortOption = .recommend
    @State private var limit = 30
    @State private var loading = false
    @State private var errorText: String?
    @State private var showFilter = false
    /// 筛选弹窗内的临时选择：点「确定」才写回 selectedCategories
    @State private var draftCategories: Set<String> = []

    enum SortOption: String, CaseIterable, Identifiable {
        case recommend
        case hot
        case new

        var id: String { rawValue }
        var title: String {
            switch self {
            case .recommend: return "推荐"
            case .hot: return "最热"
            case .new: return "最新"
            }
        }
    }

    /// 「全部」总在第一项，其后是能提供歌单的启用平台
    private var providers: [SearchProvider] {
        let feedProviders = platformPrefs.enabledSearchProviders.filter { $0.supportsPlaylistSquare }
        return [.all] + feedProviders
    }

    private var source: SearchProvider {
        guard let saved = SearchProvider(rawValue: homeSourceRaw), providers.contains(saved) else {
            return providers.first ?? .netease
        }
        return saved
    }

    private var isNativeClean: Bool { BeansUIStyle(rawValue: uiStyleRaw) == .nativeClean }

    // MARK: - 分类分组

    /// 内置兜底：接口没返回时仍能筛选
    private static let fallbackHot = ["全部", "华语", "流行", "摇滚", "民谣", "电子", "说唱", "轻音乐", "粤语", "欧美", "韩语", "日语"]
    private static let fallbackTheme = ["古风", "影视原声", "ACG", "动漫", "游戏", "爵士", "古典", "乡村", "金属", "后摇"]
    private static let fallbackScene = ["学习", "工作", "运动", "通勤", "夜晚", "清晨", "咖啡厅", "旅行", "派对", "怀旧", "治愈", "放松"]

    private var hotOptions: [String] {
        let names = Set(categories.map(\.name))
        let curated = Self.fallbackHot.filter { $0 != "全部" && (names.isEmpty || names.contains($0)) }
        return curated.isEmpty ? Self.fallbackHot.filter { $0 != "全部" } : curated
    }

    private var themeOptions: [String] {
        let api = categories.filter { [1, 3, 4].contains($0.groupIndex) }.map(\.name)
        return api.isEmpty ? Self.fallbackTheme : Self.dedupe(api)
    }

    private var sceneOptions: [String] {
        let api = categories.filter { $0.groupIndex == 2 }.map(\.name)
        return api.isEmpty ? Self.fallbackScene : Self.dedupe(api)
    }

    private static func dedupe(_ list: [String]) -> [String] {
        var seen = Set<String>()
        return list.filter { seen.insert($0).inserted }
    }

    private var activeFilterCount: Int { selectedCategories.count }

    var body: some View {
        GeometryReader { proxy in
            let spacing: CGFloat = 10
            let side = max(84, (proxy.size.width - 32 - spacing * 2) / 3)
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    platformChips
                    sortBar
                    if activeFilterCount > 0 {
                        selectedCategoryChips
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
                        EmptyStateView(icon: "music.note.list", text: "没有取到歌单\n换个分类或排序再试试")
                            .padding(.top, 40)
                    } else {
                        grid(side: side, spacing: spacing)
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
        .sheet(isPresented: $showFilter) {
            PlaylistCategoryFilterSheet(
                hot: hotOptions,
                theme: themeOptions,
                scene: sceneOptions,
                selection: $draftCategories,
                showsNeteaseHint: source != .netease
            ) { applied in
                selectedCategories = applied
                limit = 30
            }
            .environmentObject(theme)
        }
    }

    private var taskKey: String {
        "\(source.rawValue)|\(sort.rawValue)|\(selectedCategories.sorted().joined(separator: ","))"
    }

    // MARK: - 顶部

    private var platformChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(providers) { provider in
                    Button {
                        BeansHaptics.tap()
                        if source != provider {
                            playlists = []
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

    /// 排序 tab（推荐 / 最热 / 最新）+ 右侧筛选入口
    private var sortBar: some View {
        HStack(alignment: .center, spacing: 18) {
            ForEach(SortOption.allCases) { option in
                Button {
                    BeansHaptics.tap()
                    guard sort != option else { return }
                    sort = option
                    limit = 30
                } label: {
                    VStack(spacing: 5) {
                        Text(option.title)
                            .font(BeansFont.appFont(sort == option ? 17 : 15, sort == option ? .bold : .medium))
                            .foregroundStyle(sort == option ? Color.beansLabel : Color.beansComment)
                        Capsule()
                            .fill(sort == option ? Color.beansAmber : .clear)
                            .frame(width: 18, height: 3)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
            Button {
                BeansHaptics.tap()
                draftCategories = selectedCategories
                showFilter = true
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 12, weight: .semibold))
                    if activeFilterCount > 0 {
                        Text("\(activeFilterCount)")
                            .font(BeansFont.appFont(11, .bold))
                    }
                }
                .foregroundStyle(activeFilterCount > 0 ? Color.white : Color.beansLabel)
                .padding(.horizontal, activeFilterCount > 0 ? 9 : 10)
                .padding(.vertical, 7)
                .background {
                    if activeFilterCount > 0 {
                        Capsule().fill(Color.beansAmber)
                    } else {
                        BeansSurface(shape: Capsule())
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("筛选歌单分类")
        }
        .padding(.top, 2)
    }

    private var selectedCategoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(selectedCategories.sorted(), id: \.self) { name in
                    Button {
                        BeansHaptics.tap()
                        selectedCategories.remove(name)
                        limit = 30
                    } label: {
                        HStack(spacing: 4) {
                            Text(LocalizedStringKey(name))
                                .font(BeansFont.appFont(12, .semibold))
                            Image(systemName: "xmark")
                                .font(.system(size: 8, weight: .bold))
                        }
                        .foregroundStyle(Color.beansAmber)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 6)
                        .background { BeansSurface(shape: Capsule()) }
                    }
                    .buttonStyle(.plain)
                }
                Button {
                    BeansHaptics.select()
                    selectedCategories = []
                    limit = 30
                } label: {
                    Text("清空")
                        .font(BeansFont.appFont(12, .semibold))
                        .foregroundStyle(Color.beansComment)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 1)
        }
    }

    // MARK: - 网格

    private func grid(side: CGFloat, spacing: CGFloat) -> some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: spacing),
                GridItem(.flexible(), spacing: spacing),
                GridItem(.flexible(), spacing: spacing)
            ],
            alignment: .leading,
            spacing: 16
        ) {
            ForEach(Array(playlists.enumerated()), id: \.offset) { _, playlist in
                playlistCard(playlist, side: side)
            }
        }
    }

    private func playlistCard(_ playlist: Playlist, side: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topTrailing) {
                Button {
                    BeansHaptics.tap()
                    onOpen(.playlist(playlist))
                } label: {
                    ZStack(alignment: .bottomTrailing) {
                        CoverImage(url: playlist.coverURL, size: side, cornerRadius: 12)
                        if playlist.trackCount > 0 {
                            HStack(spacing: 3) {
                                Image(systemName: "headphones")
                                    .font(.system(size: 8, weight: .bold))
                                Text(playlist.trackCount > 9999 ? "\(playlist.trackCount / 10000)万" : "\(playlist.trackCount)")
                                    .font(.system(size: 9, weight: .semibold))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2.5)
                            .background(.black.opacity(0.42), in: Capsule())
                            .padding(5)
                        }
                    }
                }
                .buttonStyle(GlassPressButtonStyle(scale: 0.97))

                VStack(spacing: 4) {
                    if source == .all {
                        PlatformBrandLogo(provider: SearchProvider(songSource: playlist.source), size: 16)
                            .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
                    }
                    Button {
                        BeansHaptics.select()
                        let liked = favorites.toggle(playlist)
                        ToastCenter.shared.show(liked ? "已收藏歌单" : "已取消收藏")
                    } label: {
                        Image(systemName: favorites.contains(playlist) ? "heart.fill" : "heart")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(favorites.contains(playlist) ? Color.beansAmber : Color.white)
                            .frame(width: 24, height: 24)
                            .background(.black.opacity(0.32), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(favorites.contains(playlist) ? "取消收藏歌单" : "收藏歌单")
                }
                .padding(5)
            }
            Button {
                BeansHaptics.tap()
                onOpen(.playlist(playlist))
            } label: {
                Text(playlist.name)
                    .font(BeansFont.appFont(12, .medium))
                    .foregroundStyle(Color.beansLabel)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(width: side, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
        .frame(width: side, alignment: .leading)
    }

    @ViewBuilder
    private var loadMoreButton: some View {
        if playlists.count >= limit - 3 {
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

    // MARK: - 数据

    @MainActor
    private func load(reset: Bool) async {
        if reset {
            loading = true
            errorText = nil
        } else {
            loading = true
        }
        await loadCategoriesIfNeeded()
        do {
            let result = try await fetchPlaylists()
            playlists = result
            errorText = nil
        } catch {
            if playlists.isEmpty { errorText = error.localizedDescription }
        }
        loading = false
    }

    @MainActor
    private func loadCategoriesIfNeeded() async {
        guard source == .netease || source == .all else { return }
        guard categories.isEmpty else { return }
        let list = await NetEaseAPI.shared.playlistCatlistGrouped()
        if !list.isEmpty { categories = list }
    }

    private var requestedCategories: [String] {
        selectedCategories.isEmpty ? ["全部"] : selectedCategories.sorted()
    }

    private func fetchPlaylists() async throws -> [Playlist] {
        switch source {
        case .netease:
            return try await fetchNetease(limit: limit)
        case .qq:
            return try await QQMusicAPI.shared.hotPlaylists(limit: limit)
        case .kugou:
            return try await KugouMusicAPI.shared.recommendPlaylists(limit: limit)
        case .migu:
            return []
        case .bodian:
            return try await BodianMusicAPI.shared.recommendPlaylists(limit: limit)
        case .all:
            return await fetchAllPlatforms()
        }
    }

    private func fetchNetease(limit: Int) async throws -> [Playlist] {
        try await Self.neteaseSquare(categories: requestedCategories, sort: sort, limit: limit)
    }

    private static func neteaseSquare(categories cats: [String], sort: SortOption, limit: Int) async throws -> [Playlist] {
        if sort == .recommend, cats.count <= 1 {
            return try await NetEaseAPI.shared.highQualityPlaylists(cat: cats.first ?? "全部", limit: limit)
        }
        let perCategory = max(10, limit / max(cats.count, 1))
        var merged: [Playlist] = []
        for cat in cats {
            guard let part = try? await NetEaseAPI.shared.playlistSquare(
                cat: cat,
                order: sort == .new ? "new" : "hot",
                limit: perCategory
            ) else { continue }
            merged.append(contentsOf: part)
        }
        if merged.isEmpty, let fallback = try? await NetEaseAPI.shared.highQualityPlaylists(cat: "全部", limit: limit) {
            return fallback
        }
        return Self.dedupe(merged)
    }

    /// 「全部平台」：各平台并行取一份，再按平台轮转交错，避免整屏都是同一个平台
    private func fetchAllPlatforms() async -> [Playlist] {
        let cats = requestedCategories
        let order = sort
        let cap = limit
        var groups: [[Playlist]] = []
        await withTaskGroup(of: (Int, [Playlist]).self) { group in
            group.addTask {
                (0, (try? await Self.neteaseSquare(categories: cats, sort: order, limit: cap)) ?? [])
            }
            group.addTask {
                (1, (try? await QQMusicAPI.shared.hotPlaylists(limit: cap)) ?? [])
            }
            group.addTask {
                (2, (try? await KugouMusicAPI.shared.recommendPlaylists(limit: cap)) ?? [])
            }
            group.addTask {
                (3, (try? await BodianMusicAPI.shared.recommendPlaylists(limit: cap)) ?? [])
            }
            var buckets: [Int: [Playlist]] = [:]
            for await (index, list) in group {
                buckets[index] = list
            }
            groups = (0..<4).map { buckets[$0] ?? [] }
        }
        return Self.dedupe(Self.interleave(groups))
    }

    private static func interleave(_ groups: [[Playlist]]) -> [Playlist] {
        var queues = groups.filter { !$0.isEmpty }
        var result: [Playlist] = []
        while !queues.isEmpty {
            var next: [[Playlist]] = []
            for queue in queues {
                if let head = queue.first {
                    result.append(head)
                    if queue.count > 1 { next.append(Array(queue.dropFirst())) }
                }
            }
            queues = next
        }
        return result
    }

    private static func dedupe(_ list: [Playlist]) -> [Playlist] {
        var seen = Set<String>()
        return list.filter { seen.insert($0.uniqueKey).inserted }
    }
}

// MARK: - 分类筛选弹窗

/// 歌单分类多选弹窗：热门 / 主题 / 场景 三组标签云，底部重置与确定。
struct PlaylistCategoryFilterSheet: View {
    let hot: [String]
    let theme: [String]
    let scene: [String]
    @Binding var selection: Set<String>
    var showsNeteaseHint: Bool = false
    /// 点「确定」时把选择交回调用方
    var onApply: (Set<String>) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss

    private let columns = [GridItem(.adaptive(minimum: 68), spacing: 8)]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("筛选分类")
                    .font(BeansFont.appFont(17, .bold))
                    .foregroundStyle(Color.beansLabel)
                Spacer()
                Button {
                    BeansHaptics.tap()
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.beansComment)
                        .frame(width: 30, height: 30)
                        .background { BeansSurface(shape: Circle()) }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 10)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if showsNeteaseHint {
                        Text("分类筛选目前只对网易云音乐生效，其它平台按排序展示")
                            .font(BeansFont.appFont(11))
                            .foregroundStyle(Color.beansComment)
                    }
                    group(title: "热门", options: hot.filter { $0 != "全部" })
                    group(title: "主题", options: theme)
                    group(title: "场景", options: scene)
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 20)
            }

            HStack(spacing: 12) {
                Button {
                    BeansHaptics.select()
                    selection = []
                } label: {
                    Text("重置")
                        .font(BeansFont.appFont(15, .semibold))
                        .foregroundStyle(Color.beansLabel)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background { BeansSurface(shape: Capsule()) }
                }
                .buttonStyle(.plain)

                Button {
                    BeansHaptics.select()
                    onApply(selection)
                    dismiss()
                } label: {
                    Text(selection.isEmpty ? "全部歌单" : "确定（\(selection.count)）")
                        .font(BeansFont.appFont(15, .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background { Capsule().fill(Color.beansAmber) }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 22)
            .padding(.top, 8)
            .background(.ultraThinMaterial)
        }
        .background { GlassBackdrop() }
    }

    private func group(title: String, options: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(BeansFont.appFont(13, .bold))
                .foregroundStyle(Color.beansComment)
            LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                ForEach(options, id: \.self) { option in
                    let selected = selection.contains(option)
                    Button {
                        BeansHaptics.tap()
                        if selected {
                            selection.remove(option)
                        } else {
                            selection.insert(option)
                        }
                    } label: {
                        Text(LocalizedStringKey(option))
                            .font(BeansFont.appFont(12, selected ? .semibold : .regular))
                            .foregroundStyle(selected ? Color.white : Color.beansLabel)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background {
                                if selected {
                                    Capsule().fill(Color.beansAmber)
                                } else {
                                    BeansSurface(shape: Capsule())
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
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
        case .bodian: return "波点音乐"
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
