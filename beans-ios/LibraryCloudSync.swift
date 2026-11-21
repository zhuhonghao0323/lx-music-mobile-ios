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

    /// 平均每个歌单的耗时，用来直观看同步效率
    var speedText: String {
        guard playlists > 0, seconds > 0 else { return "—" }
        return String(format: "%.2f 秒/歌单", seconds / Double(playlists))
    }
}

/// 单个歌单的同步产物（只带可跨并发域的值，避免整首歌对象在任务间来回传）
private struct SyncJobResult: Sendable {
    let name: String
    let count: Int
    let covers: [URL]
    let failure: String?
}

/// 跨并发域的安全标志：同步任务在多个 task 里轮询「是否要停」
private final class SyncCancelFlag {
    private let lock = NSLock()
    private var value = false

    var isSet: Bool {
        lock.lock()
        defer { lock.unlock() }
        return value
    }

    func set() {
        lock.lock()
        value = true
        lock.unlock()
    }

    func reset() {
        lock.lock()
        value = false
        lock.unlock()
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
    private let cancelFlag = SyncCancelFlag()

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
        cancelFlag.set()
        progressText = "正在停止…"
    }

    /// 全量同步：歌单之间并发拉取（3 路），每个歌单落盘只写自己那一个文件。
    /// 封面只在后台缓存「歌单封面」一张（不是每首歌的封面），不阻塞歌曲信息。
    @MainActor
    func sync(sources: [LibraryCloudSyncSource]) async {
        guard !isSyncing else { return }

        var jobs: [(platform: String, playlist: Playlist, accountID: String)] = []
        for group in sources {
            for playlist in group.playlists {
                jobs.append((group.displayName, playlist, group.accountID))
            }
        }
        guard !jobs.isEmpty else {
            summary = LibraryCloudSyncSummary(
                date: Date(), playlists: 0, songs: 0, covers: 0,
                failures: ["没有可同步的歌单，请先登录对应平台"], seconds: 0
            )
            return
        }

        isSyncing = true
        cancelFlag.reset()
        cancelled = false
        donePlaylists = 0
        plannedPlaylists = jobs.count
        songCount = 0
        coverCount = 0
        progressText = "准备同步…"
        let started = Date()

        var failures: [String] = []
        var coverURLs = Set<String>()
        var pendingCoverURLs: [URL] = []

        let maxConcurrent = 3
        var cursor = 0

        await withTaskGroup(of: SyncJobResult.self) { group in
            let warmup = min(maxConcurrent, jobs.count)
            for _ in 0..<warmup {
                let job = jobs[cursor]
                cursor += 1
                group.addTask {
                    await Self.perform(job: job.playlist, accountID: job.accountID)
                }
            }

            while let result = await group.next() {
                guard !cancelFlag.isSet else { continue }
                donePlaylists += 1
                songCount += result.count
                progressText = result.count > 0
                    ? "\(result.name) · \(result.count) 首"
                    : result.name
                if let failure = result.failure {
                    failures.append(failure)
                }
                // 只缓存歌单封面（perform 已只返回歌单封面），后台处理，不阻塞歌曲信息
                for url in result.covers where coverURLs.insert(url.absoluteString).inserted {
                    pendingCoverURLs.append(url)
                }
                if cursor < jobs.count, !cancelFlag.isSet {
                    let job = jobs[cursor]
                    cursor += 1
                    group.addTask {
                        await Self.perform(job: job.playlist, accountID: job.accountID)
                    }
                }
            }
        }

        if cancelFlag.isSet { cancelled = true }
        if !pendingCoverURLs.isEmpty {
            startBackgroundCoverWarm(pendingCoverURLs)
        }

        let snapshot = LibraryCloudSyncSummary(
            date: Date(),
            playlists: donePlaylists,
            songs: songCount,
            covers: coverCount,
            failures: Array(failures.prefix(6)),
            seconds: Date().timeIntervalSince(started)
        )
        summary = snapshot
        if let data = try? JSONEncoder().encode(snapshot) {
            UserDefaults.standard.set(data, forKey: summaryKey)
        }
        await rebuildFromCache()
        progressText = cancelled ? "已停止" : "同步完成"
        isSyncing = false
    }

    /// 拉一个歌单：网络 → 落盘（只写这一个歌单的文件）→ 返回统计
    private static func perform(job: Playlist, accountID: String) async -> SyncJobResult {
        do {
            let songs = try await fetchSongs(job)
            guard !songs.isEmpty else {
                return SyncJobResult(name: job.name, count: 0, covers: [], failure: nil)
            }
            SyncedPlaylistCache.shared.saveSongs(
                songs,
                playlist: job,
                accountID: accountID,
                pinned: true
            )
            // 只缓存歌单封面这一张，不逐首下载歌曲封面
            var covers: [URL] = []
            if let cover = job.coverURL { covers.append(cover) }
            return SyncJobResult(name: job.name, count: songs.count, covers: covers, failure: nil)
        } catch {
            return SyncJobResult(
                name: job.name,
                count: 0,
                covers: [],
                failure: "\(job.name)：\(error.localizedDescription)"
            )
        }
    }

    private static func fetchSongs(_ playlist: Playlist) async throws -> [Song] {
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

    /// 后台补封面：低优先级、6 路并发，用户此时已经能正常浏览歌曲了
    @MainActor
    private func startBackgroundCoverWarm(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        Task.detached(priority: .utility) { [weak self] in
            var covered = 0
            var index = 0
            let batch = 6
            while index < urls.count {
                let slice = Array(urls[index..<min(index + batch, urls.count)])
                let hits = await withTaskGroup(of: Bool.self) { group -> Int in
                    for url in slice {
                        group.addTask {
                            await CoverThumbCache.shared.prewarm(url: url, maxPixel: 320)
                        }
                    }
                    var count = 0
                    for await ok in group where ok { count += 1 }
                    return count
                }
                covered += hits
                index += batch
            }
            let total = covered
            guard total > 0 else { return }
            await MainActor.run { self?.coverCount += total }
        }
    }

    /// 从本地缓存重建「全部歌曲」索引（不联网）。
    @MainActor
    func rebuildFromCache() async {
        let all = await SyncedPlaylistCache.shared.allCachedSongs()
        let merged = await Task.detached(priority: .userInitiated) {
            LibrarySongAggregator.merge([all])
        }.value
        cachedSongs = merged
        BeansLogger.shared.log(
            "曲库同步：本地缓存汇总 \(merged.count) 首（\(SyncedPlaylistCache.shared.cachedSongEntryCount) 个歌单）",
            level: .debug
        )
    }
}

// MARK: - 同步面板

struct LibraryCloudSyncSheet: View {
    let sources: [LibraryCloudSyncSource]

    @ObservedObject private var store = LibraryCloudSyncStore.shared
    @EnvironmentObject private var theme: ThemeStore
    @Environment(\.dismiss) private var dismiss

    /// 勾选参与同步的平台
    @State private var selectedPlatforms: Set<SongSource> = []
    /// 勾选的具体歌单，key = "\(source)-\(playlist.id)"
    @State private var selectedPlaylistKeys: Set<String> = []
    /// 展开的平台
    @State private var expandedPlatforms: Set<SongSource> = []
    @State private var didInitSelection = false

    private func key(_ source: SongSource, _ playlist: Playlist) -> String {
        "\(source.rawValue)-\(playlist.id)"
    }

    /// 选中的歌单（按平台分组）
    private var selectedSources: [LibraryCloudSyncSource] {
        sources.compactMap { group in
            guard selectedPlatforms.contains(group.source) else { return nil }
            let picked = group.playlists.filter { selectedPlaylistKeys.contains(key(group.source, $0)) }
            return picked.isEmpty ? nil : LibraryCloudSyncSource(
                source: group.source, accountID: group.accountID, playlists: picked
            )
        }
    }

    private var selectedPlaylistCount: Int {
        selectedSources.reduce(0) { $0 + $1.playlists.count }
    }

    private var selectedSongEstimate: Int {
        selectedSources.reduce(0) { partial, group in
            partial + group.playlists.reduce(0) { $0 + $1.trackCount }
        }
    }

    private var allPlaylistKeys: Set<String> {
        var set: Set<String> = []
        for group in sources {
            for p in group.playlists { set.insert(key(group.source, p)) }
        }
        return set
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
                    Text("同步只保存歌曲信息（歌名、歌手、专辑、封面地址、音质 hash），不下载音频文件；封面仅缓存每个歌单的封面图。歌曲按歌单分文件保存，歌单再多也不会越同步越慢。可勾选平台和具体歌单，只同步你需要的部分。")
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
            .onAppear {
                guard !didInitSelection else { return }
                didInitSelection = true
                // 默认全选所有「有歌单」的平台及其歌单
                for group in sources where !group.playlists.isEmpty {
                    selectedPlatforms.insert(group.source)
                    for p in group.playlists { selectedPlaylistKeys.insert(key(group.source, p)) }
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
                    Text(selectedPlaylistCount > 0
                         ? "已选 \(selectedPlaylistCount) 个歌单" + (selectedSongEstimate > 0 ? " · 约 \(selectedSongEstimate) 首" : "")
                         : "请勾选下方要同步的平台和歌单")
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
                        statChip(icon: "bolt.horizontal", text: "3 路并发")
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
                    Task { await store.sync(sources: selectedSources) }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.down.circle.fill")
                        Text(selectedPlaylistCount > 0 ? "开始同步（\(selectedPlaylistCount) 个歌单）" : "请先勾选歌单")
                    }
                    .font(BeansFont.appFont(14, .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.beansAmber, in: Capsule())
                }
                .buttonStyle(GlassPressButtonStyle(scale: 0.97))
                .disabled(selectedPlaylistCount == 0)
                .opacity(selectedPlaylistCount == 0 ? 0.6 : 1)
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
                if !store.isSyncing {
                    Text("平均 \(summary.speedText)")
                        .font(BeansFont.appFont(11))
                        .foregroundStyle(Color.beansComment)
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
            HStack {
                Text("同步范围")
                    .font(BeansFont.appFont(13, .bold))
                    .foregroundStyle(Color.beansLabel)
                Spacer()
                Button {
                    BeansHaptics.tap()
                    let allSelected = selectedPlaylistCount == allPlaylistKeys.count && !allPlaylistKeys.isEmpty
                    if allSelected {
                        selectedPlaylistKeys.removeAll()
                        selectedPlatforms.removeAll()
                    } else {
                        selectedPlaylistKeys = allPlaylistKeys
                        selectedPlatforms = Set(sources.filter { !$0.playlists.isEmpty }.map { $0.source })
                    }
                } label: {
                    Text(selectedPlaylistCount == allPlaylistKeys.count && !allPlaylistKeys.isEmpty ? "取消全选" : "全选")
                        .font(BeansFont.appFont(12, .semibold))
                        .foregroundStyle(Color.beansAmber)
                }
                .buttonStyle(.plain)
            }

            ForEach(sources, id: \.source) { group in
                platformSection(group)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { BeansSurface(shape: RoundedRectangle(cornerRadius: 22, style: .continuous)) }
    }

    @ViewBuilder
    private func platformSection(_ group: LibraryCloudSyncSource) -> some View {
        let allSelected = !group.playlists.isEmpty && group.playlists.allSatisfy { selectedPlaylistKeys.contains(key(group.source, $0)) }
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                // 平台勾选
                Button {
                    BeansHaptics.tap()
                    let keys = group.playlists.map { key(group.source, $0) }
                    if allSelected {
                        selectedPlatforms.remove(group.source)
                        selectedPlaylistKeys.subtract(keys)
                    } else {
                        selectedPlatforms.insert(group.source)
                        selectedPlaylistKeys.formUnion(keys)
                    }
                } label: {
                    Image(systemName: allSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20))
                        .foregroundStyle(allSelected ? Color.beansAmber : Color.beansComment.opacity(0.5))
                }
                .buttonStyle(.plain)

                Image(systemName: "music.note.list")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.beansAmber)
                    .frame(width: 26, height: 26)
                    .background(Color.beansAmber.opacity(0.12), in: Circle())

                Button {
                    BeansHaptics.tap()
                    if expandedPlatforms.contains(group.source) {
                        expandedPlatforms.remove(group.source)
                    } else {
                        expandedPlatforms.insert(group.source)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(group.displayName)
                            .font(BeansFont.appFont(13, .semibold))
                            .foregroundStyle(Color.beansLabel)
                        if group.playlists.isEmpty {
                            Text("未登录 / 无歌单")
                                .font(BeansFont.appFont(11))
                                .foregroundStyle(Color.beansComment)
                        } else {
                            Text("\(group.playlists.filter { selectedPlaylistKeys.contains(key(group.source, $0)) }.count)/\(group.playlists.count)")
                                .font(BeansFont.appFont(11, .medium))
                                .foregroundStyle(Color.beansComment)
                        }
                        Spacer()
                        if !group.playlists.isEmpty {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Color.beansComment)
                                .rotationEffect(.degrees(expandedPlatforms.contains(group.source) ? 90 : 0))
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            if expandedPlatforms.contains(group.source) && !group.playlists.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(group.playlists) { playlist in
                        Button {
                            BeansHaptics.tap()
                            let k = key(group.source, playlist)
                            if selectedPlaylistKeys.contains(k) {
                                selectedPlaylistKeys.remove(k)
                                if !group.playlists.contains(where: { selectedPlaylistKeys.contains(key(group.source, $0)) }) {
                                    selectedPlatforms.remove(group.source)
                                }
                            } else {
                                selectedPlaylistKeys.insert(k)
                                selectedPlatforms.insert(group.source)
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: selectedPlaylistKeys.contains(key(group.source, playlist)) ? "checkmark.square.fill" : "square")
                                    .font(.system(size: 15))
                                    .foregroundStyle(selectedPlaylistKeys.contains(key(group.source, playlist)) ? Color.beansAmber : Color.beansComment.opacity(0.5))
                                CoverImage(url: playlist.coverURL, size: 30, cornerRadius: 6)
                                Text(playlist.name)
                                    .font(BeansFont.appFont(12))
                                    .foregroundStyle(Color.beansLabel)
                                    .lineLimit(1)
                                Spacer(minLength: 0)
                                Text("\(playlist.trackCount)")
                                    .font(BeansFont.appFont(11))
                                    .foregroundStyle(Color.beansComment)
                            }
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.leading, 66)
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 4)
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
