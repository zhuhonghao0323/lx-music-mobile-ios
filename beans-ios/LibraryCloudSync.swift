import SwiftUI

// MARK: - 曲库云同步

/// 一次同步要覆盖的平台数据
struct LibraryCloudSyncSource {
    let source: SongSource
    let accountID: String
    let playlists: [Playlist]

    var displayName: String {
        switch source {
        case .netease: return "网易云音乐"
        case .qq: return "QQ音乐"
        case .kugou: return "酷狗音乐"
        case .migu: return "咪咕音乐"
        case .bodian: return "波点音乐"
        }
    }
}

/// 同步结果摘要（持久化，下次打开还能看到上次同步情况）
struct LibraryCloudSyncSummary: Codable, Equatable {
    var date: Date
    var playlists: Int
    var songs: Int
    var covers: Int
    var failures: [String]
    var seconds: Double

    var dateText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter.string(from: date)
    }

    var durationText: String {
        if seconds < 60 { return String(format: "%.0f 秒", seconds) }
        return String(format: "%.0f 分 %.0f 秒", seconds / 60, seconds.truncatingRemainder(dividingBy: 60))
    }
}

final class LibraryCloudSyncStore: ObservableObject {
    static let shared = LibraryCloudSyncStore()

    @Published private(set) var isSyncing = false
    @Published private(set) var progressText = ""
    @Published private(set) var donePlaylists = 0
    @Published private(set) var plannedPlaylists = 0
    @Published private(set) var songCount = 0
    @Published private(set) var coverCount = 0
    @Published private(set) var summary: LibraryCloudSyncSummary?
    /// 所有已缓存歌单的歌曲汇总（去重后），供音乐库「全部歌曲」使用
    @Published private(set) var cachedSongs: [Song] = []
    @Published private(set) var cancelled = false

    private let summaryKey = "beans.library.cloudSync.summary"
    private var cancelRequested = false

    private init() {
        if let data = UserDefaults.standard.data(forKey: summaryKey),
           let saved = try? JSONDecoder().decode(LibraryCloudSyncSummary.self, from: data) {
            summary = saved
        }
    }

    var progress: Double {
        guard plannedPlaylists > 0 else { return 0 }
        return min(1, Double(donePlaylists) / Double(plannedPlaylists))
    }

    @MainActor
    func cancel() {
        guard isSyncing else { return }
        cancelRequested = true
        progressText = "正在停止…"
    }

    /// 全量同步：逐个歌单拉歌曲 → 落盘 → 预下载封面缩略图
    @MainActor
    func sync(sources: [LibraryCloudSyncSource]) async {
        guard !isSyncing else { return }
        let total = sources.reduce(0) { $0 + $1.playlists.count }
        guard total > 0 else {
            summary = LibraryCloudSyncSummary(
                date: Date(), playlists: 0, songs: 0, covers: 0,
                failures: ["没有可同步的歌单，请先登录对应平台"], seconds: 0
            )
            return
        }

        isSyncing = true
        cancelRequested = false
        cancelled = false
        donePlaylists = 0
        plannedPlaylists = total
        songCount = 0
        coverCount = 0
        progressText = "准备同步…"
        let started = Date()
        var failures: [String] = []
        var coverURLs = Set<String>()
        var pendingCovers: [URL] = []

        for group in sources {
            for playlist in group.playlists {
                if cancelRequested { break }
                progressText = "\(group.displayName) · \(playlist.name)"
                do {
                    let songs = try await fetchSongs(playlist)
                    if !songs.isEmpty {
                        SyncedPlaylistCache.shared.saveSongs(songs, playlist: playlist, accountID: group.accountID, pinned: true)
                        songCount += songs.count
                        for song in songs {
                            guard let url = song.coverURL, coverURLs.insert(url.absoluteString).inserted else { continue }
                            pendingCovers.append(url)
                        }
                    }
                    if let cover = playlist.coverURL, coverURLs.insert(cover.absoluteString).inserted {
                        pendingCovers.append(cover)
                    }
                } catch {
                    failures.append("\(playlist.name)：\(error.localizedDescription)")
                }
                donePlaylists += 1

                // 每同步完一个歌单就顺手把封面缓存掉，进度与结果都能对上
                if !pendingCovers.isEmpty {
                    let batch = pendingCovers
                    pendingCovers.removeAll(keepingCapacity: true)
                    await prewarmCovers(batch)
                }
            }
            if cancelRequested { break }
        }

        if !pendingCovers.isEmpty {
            await prewarmCovers(pendingCovers)
        }
        if cancelRequested { cancelled = true }

        let summary = LibraryCloudSyncSummary(
            date: Date(),
            playlists: donePlaylists,
            songs: songCount,
            covers: coverCount,
            failures: Array(failures.prefix(6)),
            seconds: Date().timeIntervalSince(started)
        )
        self.summary = summary
        if let data = try? JSONEncoder().encode(summary) {
            UserDefaults.standard.set(data, forKey: summaryKey)
        }
        await rebuildFromCache()
        progressText = cancelled ? "已停止" : "同步完成"
        isSyncing = false
    }

    /// 从本地缓存重建「全部歌曲」索引（不联网）。
    /// 直接读缓存里所有歌单，不依赖当前平台是否已加载歌单列表。
    @MainActor
    func rebuildFromCache() async {
        let all = SyncedPlaylistCache.shared.allCachedSongs()
        let merged = LibrarySongAggregator.merge([all])
        cachedSongs = merged
        BeansLogger.shared.log(
            "曲库同步：本地缓存汇总 \(merged.count) 首（\(SyncedPlaylistCache.shared.cachedSongEntryCount) 个歌单）",
            level: .debug
        )
    }

    private func fetchSongs(_ playlist: Playlist) async throws -> [Song] {
        switch playlist.source {
        case .kugou:
            return try await KugouMusicAPI.shared.playlistSongs(listID: playlist.id, externalID: playlist.externalID)
        case .qq:
            return try await QQMusicAPI.shared.playlistSongs(listID: playlist.id)
        case .bodian:
            return try await BodianMusicAPI.shared.playlistTracks(playlistID: playlist.externalID ?? String(playlist.id))
        case .netease:
            return try await NetEaseAPI.shared.playlistTracks(id: playlist.id)
        case .migu:
            return []
        }
    }

    /// 封面预热：4 路并发，避免一次开几十个请求
    @MainActor
    private func prewarmCovers(_ urls: [URL]) async {
        let maxConcurrent = 4
        var index = 0
        while index < urls.count {
            if cancelRequested { return }
            let end = min(index + maxConcurrent, urls.count)
            let slice = Array(urls[index..<end])
            let results = await withTaskGroup(of: Bool.self) { group -> [Bool] in
                for url in slice {
                    group.addTask {
                        await CoverThumbCache.shared.prewarm(url: url, maxPixel: 320)
                    }
                }
                var values: [Bool] = []
                for await value in group { values.append(value) }
                return values
            }
            coverCount += results.filter { $0 }.count
            index = end
        }
    }
}

// MARK: - 同步面板

struct LibraryCloudSyncSheet: View {
    let sources: [LibraryCloudSyncSource]

    @ObservedObject private var store = LibraryCloudSyncStore.shared
    @EnvironmentObject private var theme: ThemeStore
    @Environment(\.dismiss) private var dismiss

    private var totalPlaylists: Int {
        sources.reduce(0) { $0 + $1.playlists.count }
    }

    var body: some View {
        BeansNavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    headerCard
                    if store.isSyncing || store.summary != nil {
                        resultCard
                    }
                    platformCard
                    Text("同步会把每个歌单的歌曲写入本机缓存，并把这些歌曲的封面缩略图一并下载。之后打开歌单或列表都直接读本地，不再重复请求网络；只有再次点开歌曲详情或手动同步时才会更新。")
                        .font(BeansFont.appFont(12))
                        .foregroundStyle(Color.beansComment)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 4)
                }
                .padding(16)
                .padding(.bottom, 24)
            }
            .background {
                GlassBackdrop(customColor: theme.backgroundSyncAll ? theme.customBackground : nil)
            }
            .navigationTitle("曲库云同步")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.beansAmber.opacity(0.14))
                        .frame(width: 46, height: 46)
                    Image(systemName: "icloud.and.arrow.down")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color.beansAmber)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("把云端歌单存到本机")
                        .font(BeansFont.appFont(15, .semibold))
                        .foregroundStyle(Color.beansLabel)
                    Text(totalPlaylists > 0 ? "共 \(totalPlaylists) 个歌单待同步" : "当前平台没有可同步的歌单")
                        .font(BeansFont.appFont(12))
                        .foregroundStyle(Color.beansComment)
                }
                Spacer(minLength: 0)
            }

            if store.isSyncing {
                VStack(alignment: .leading, spacing: 8) {
                    ProgressView(value: store.progress)
                        .tint(Color.beansAmber)
                    HStack {
                        Text(store.progressText)
                            .font(BeansFont.appFont(12, .medium))
                            .foregroundStyle(Color.beansLabel)
                            .lineLimit(1)
                        Spacer()
                        Text("\(store.donePlaylists)/\(store.plannedPlaylists)")
                            .font(BeansFont.appFont(12, .semibold, .monospaced))
                            .foregroundStyle(Color.beansAmber)
                    }
                    HStack(spacing: 14) {
                        statChip(icon: "music.note", text: "\(store.songCount) 首")
                        statChip(icon: "photo", text: "\(store.coverCount) 张封面")
                    }
                }
                Button {
                    BeansHaptics.tap()
                    store.cancel()
                } label: {
                    Text("停止同步")
                        .font(BeansFont.appFont(13, .semibold))
                        .foregroundStyle(Color.beansAmber)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.beansAmber.opacity(0.12), in: Capsule())
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    BeansHaptics.tap()
                    Task { await store.sync(sources: sources) }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.down.circle.fill")
                        Text(totalPlaylists > 0 ? "开始同步" : "暂无可同步歌单")
                    }
                    .font(BeansFont.appFont(14, .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.beansAmber, in: Capsule())
                }
                .buttonStyle(GlassPressButtonStyle(scale: 0.97))
                .disabled(totalPlaylists == 0)
                .opacity(totalPlaylists == 0 ? 0.6 : 1)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { BeansGlass(shape: RoundedRectangle(cornerRadius: 22, style: .continuous)) }
    }

    @ViewBuilder
    private var resultCard: some View {
        if let summary = store.summary {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(store.isSyncing ? "同步中…" : (store.cancelled ? "已停止" : "同步结果"))
                        .font(BeansFont.appFont(14, .bold))
                        .foregroundStyle(Color.beansLabel)
                    Spacer()
                    Text(summary.dateText)
                        .font(BeansFont.appFont(11))
                        .foregroundStyle(Color.beansComment)
                }
                HStack(spacing: 8) {
                    resultCell(value: "\(summary.playlists)", label: "歌单")
                    resultCell(value: "\(summary.songs)", label: "歌曲")
                    resultCell(value: "\(summary.covers)", label: "封面")
                    resultCell(value: summary.durationText, label: "用时")
                }
                if !summary.failures.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("以下歌单同步失败，可稍后重试：")
                            .font(BeansFont.appFont(11, .medium))
                            .foregroundStyle(Color.beansComment)
                        ForEach(summary.failures, id: \.self) { item in
                            Text("· \(item)")
                                .font(BeansFont.appFont(11))
                                .foregroundStyle(Color.red.opacity(0.85))
                                .lineLimit(2)
                        }
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background { BeansGlass(shape: RoundedRectangle(cornerRadius: 22, style: .continuous)) }
        }
    }

    private var platformCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("同步范围")
                .font(BeansFont.appFont(13, .bold))
                .foregroundStyle(Color.beansLabel)
            ForEach(sources, id: \.source) { group in
                HStack(spacing: 10) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.beansAmber)
                        .frame(width: 26, height: 26)
                        .background(Color.beansAmber.opacity(0.12), in: Circle())
                    Text(group.displayName)
                        .font(BeansFont.appFont(13))
                        .foregroundStyle(Color.beansLabel)
                    Spacer()
                    Text(group.playlists.isEmpty ? "未登录 / 无歌单" : "\(group.playlists.count) 个歌单")
                        .font(BeansFont.appFont(12))
                        .foregroundStyle(Color.beansComment)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { BeansSurface(shape: RoundedRectangle(cornerRadius: 22, style: .continuous)) }
    }

    private func statChip(icon: String, text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
            Text(text)
                .font(BeansFont.appFont(11, .medium))
        }
        .foregroundStyle(Color.beansComment)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(Color.primary.opacity(0.05), in: Capsule())
    }

    private func resultCell(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(BeansFont.appFont(15, .bold, .rounded))
                .foregroundStyle(Color.beansLabel)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(BeansFont.appFont(10))
                .foregroundStyle(Color.beansComment)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
