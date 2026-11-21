import Foundation
import CryptoKit

/// 持久化缓存云端歌单列表和歌单歌曲。
/// 网络请求失败或切回音乐库时，先展示上次成功结果，再在后台刷新。
///
/// 性能要点：歌曲**按歌单分文件**落在 Application Support/BeansSyncedSongs/ 下，
/// 另有轻量索引记录「歌单 → 歌曲数 / 保存时间 / pinned」。
/// 这样同步 100 个歌单时，每次只写当前歌单（O(单歌单大小)），
/// 而不是像旧实现那样把整个曲库重新 JSON 编码一遍写进 UserDefaults（O(全库)，越同步越慢）。
final class SyncedPlaylistCache {
    static let shared = SyncedPlaylistCache()

    struct PlaylistEntry: Codable {
        let playlists: [Playlist]
        let savedAt: Date
    }

    struct SongEntry: Codable {
        let songs: [Song]
        let savedAt: Date
        /// 手动云同步写入的条目：不参与 TTL 过期，只有下次手动同步才会覆盖
        var pinned: Bool?
    }

    /// 轻量索引项：不装载歌曲本体，只记数量和来源，供列表 / 计数 / 新鲜度判断使用
    struct SongMeta: Codable {
        let key: String
        let count: Int
        let savedAt: Date
        var pinned: Bool?
        var playlist: Playlist?
    }

    private let defaults = UserDefaults.standard
    private let playlistsKey = "beans.syncedPlaylistCache.playlists.v1"
    private let legacySongsKey = "beans.syncedPlaylistCache.songs.v1"
    private let metaKey = "beans.syncedPlaylistCache.songMeta.v2"
    private let migratedKey = "beans.syncedPlaylistCache.migrated.v2"

    private let lock = NSLock()
    private let writeQueue = DispatchQueue(label: "Beans.SyncedPlaylistCache.write", qos: .utility)
    private let songDirectory: URL

    private var playlistEntries: [String: PlaylistEntry]
    private var songMeta: [String: SongMeta]
    /// 已解码的歌单歌曲；只留最近用到的若干个歌单，避免上千歌单常驻内存
    private var songMemory: [String: SongEntry] = [:]
    private var songMemoryOrder: [String] = []
    private let songMemoryLimit = 20

    /// 歌单列表缓存 15 分钟，歌曲详情缓存 30 分钟。
    let playlistTTL: TimeInterval = 15 * 60
    let songTTL: TimeInterval = 30 * 60

    private init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        songDirectory = base.appendingPathComponent("BeansSyncedSongs", isDirectory: true)
        try? FileManager.default.createDirectory(at: songDirectory, withIntermediateDirectories: true)

        playlistEntries = defaults.data(forKey: playlistsKey)
            .flatMap { try? JSONDecoder().decode([String: PlaylistEntry].self, from: $0) } ?? [:]
        songMeta = defaults.data(forKey: metaKey)
            .flatMap { try? JSONDecoder().decode([String: SongMeta].self, from: $0) } ?? [:]

        migrateLegacySongsIfNeeded()
    }

    // MARK: - 歌单列表

    func cachedPlaylists(source: SongSource, accountID: String) -> PlaylistEntry? {
        lock.lock()
        defer { lock.unlock() }
        return playlistEntries[cacheKey(source: source, accountID: accountID)]
    }

    func savePlaylists(_ playlists: [Playlist], source: SongSource, accountID: String) {
        guard !playlists.isEmpty else { return }
        lock.lock()
        playlistEntries[cacheKey(source: source, accountID: accountID)] = PlaylistEntry(
            playlists: playlists,
            savedAt: Date()
        )
        let snapshot = playlistEntries
        lock.unlock()
        persistAsync(snapshot, key: playlistsKey)
    }

    // MARK: - 歌单歌曲

    func cachedSongs(playlist: Playlist, accountID: String) -> SongEntry? {
        let key = cacheKey(source: playlist.source, accountID: "\(accountID)|\(playlist.id)")
        lock.lock()
        if let hit = songMemory[key] {
            lock.unlock()
            return hit
        }
        let hasMeta = songMeta[key] != nil
        lock.unlock()
        guard hasMeta else { return nil }

        guard let data = try? Data(contentsOf: fileURL(for: key)),
              let entry = try? JSONDecoder().decode(SongEntry.self, from: data) else {
            return nil
        }
        lock.lock()
        rememberInMemory(key, entry: entry)
        lock.unlock()
        return entry
    }

    /// 只更新内存索引，磁盘写入交给串行队列；单歌单一次，不会随曲库变大而变慢
    func saveSongs(_ songs: [Song], playlist: Playlist, accountID: String, pinned: Bool = false) {
        guard !songs.isEmpty else { return }
        let key = cacheKey(source: playlist.source, accountID: "\(accountID)|\(playlist.id)")
        let entry = SongEntry(songs: songs, savedAt: Date(), pinned: pinned)

        lock.lock()
        rememberInMemory(key, entry: entry)
        songMeta[key] = SongMeta(
            key: key,
            count: songs.count,
            savedAt: entry.savedAt,
            pinned: pinned,
            playlist: playlist
        )
        lock.unlock()

        writeQueue.async { [songDirectory] in
            guard let data = try? JSONEncoder().encode(entry) else { return }
            let url = songDirectory.appendingPathComponent(Self.fileName(for: key))
            try? data.write(to: url, options: .atomic)
        }
        persistMeta()
    }

    func isFresh(_ entry: PlaylistEntry, now: Date = Date()) -> Bool {
        now.timeIntervalSince(entry.savedAt) < playlistTTL
    }
    func isFresh(_ entry: SongEntry, now: Date = Date()) -> Bool {
        if entry.pinned == true { return true }
        return now.timeIntervalSince(entry.savedAt) < songTTL
    }
    func isFresh(_ meta: SongMeta, now: Date = Date()) -> Bool {
        if meta.pinned == true { return true }
        return now.timeIntervalSince(meta.savedAt) < songTTL
    }

    /// 某个歌单的缓存摘要（歌曲数、时间）
    func meta(for playlist: Playlist, accountID: String) -> SongMeta? {
        let key = cacheKey(source: playlist.source, accountID: "\(accountID)|\(playlist.id)")
        lock.lock()
        defer { lock.unlock() }
        return songMeta[key]
    }

    /// 全部已缓存歌单的摘要（含歌单信息），用于「全部歌单」在未联网时也能列出来
    func allMetas() -> [SongMeta] {
        lock.lock()
        defer { lock.unlock() }
        return Array(songMeta.values)
    }

    /// 所有已缓存歌单的歌曲（不分平台 / 账号），供音乐库「全部歌曲」汇总。
    /// 分文件并行读取，避免在主线程一口气解码几十 MB。
    func allCachedSongs() async -> [Song] {
        let metas: [SongMeta] = {
            lock.lock()
            defer { lock.unlock() }
            return Array(songMeta.values)
        }()
        guard !metas.isEmpty else { return [] }

        return await withTaskGroup(of: [Song].self) { group in
            var result: [Song] = []
            result.reserveCapacity(metas.reduce(0) { $0 + $1.count })
            var index = 0
            let batch = 4
            let directory = songDirectory
            let memoryHit: [String: SongEntry] = {
                lock.lock()
                defer { lock.unlock() }
                return songMemory
            }()

            while index < metas.count {
                let end = min(index + batch, metas.count)
                for meta in metas[index..<end] {
                    if let hit = memoryHit[meta.key] {
                        result.append(contentsOf: hit.songs)
                        continue
                    }
                    let key = meta.key
                    group.addTask {
                        let url = directory.appendingPathComponent(Self.fileName(for: key))
                        guard let data = try? Data(contentsOf: url),
                              let entry = try? JSONDecoder().decode(SongEntry.self, from: data) else {
                            return []
                        }
                        return entry.songs
                    }
                }
                for await songs in group {
                    result.append(contentsOf: songs)
                }
                index = end
            }
            return result
        }
    }

    /// 已缓存歌单数量
    var cachedSongEntryCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return songMeta.count
    }

    /// 已缓存歌曲总数
    var cachedSongTotal: Int {
        lock.lock()
        defer { lock.unlock() }
        return songMeta.values.reduce(0) { $0 + $1.count }
    }

    func clear(source: SongSource, accountID: String) {
        lock.lock()
        let playlistKey = cacheKey(source: source, accountID: accountID)
        playlistEntries.removeValue(forKey: playlistKey)
        let songPrefix = cacheKey(source: source, accountID: "\(accountID)|")
        let removedKeys = songMeta.keys.filter { $0.hasPrefix(songPrefix) }
        for key in removedKeys {
            songMeta.removeValue(forKey: key)
            songMemory.removeValue(forKey: key)
        }
        let playlistSnapshot = playlistEntries
        let metaSnapshot = songMeta
        lock.unlock()

        persistAsync(playlistSnapshot, key: playlistsKey)
        persistAsync(metaSnapshot, key: metaKey)
        writeQueue.async { [songDirectory] in
            for key in removedKeys {
                let url = songDirectory.appendingPathComponent(Self.fileName(for: key))
                try? FileManager.default.removeItem(at: url)
            }
        }
    }

    // MARK: - 内部

    private func cacheKey(source: SongSource, accountID: String) -> String {
        let normalizedAccount = accountID.trimmingCharacters(in: .whitespacesAndNewlines)
        return "\(source.rawValue)|\(normalizedAccount.isEmpty ? "default" : normalizedAccount)"
    }

    private func fileURL(for key: String) -> URL {
        songDirectory.appendingPathComponent(Self.fileName(for: key))
    }

    /// 文件名用 key 的 SHA256，避免中文 / 竖线 / 斜杠进文件名
    private static func fileName(for key: String) -> String {
        let digest = SHA256.hash(data: Data(key.utf8))
        return digest.prefix(16).map { String(format: "%02x", $0) }.joined() + ".json"
    }

    /// 调用前需持有 lock
    private func rememberInMemory(_ key: String, entry: SongEntry) {
        songMemory[key] = entry
        songMemoryOrder.removeAll { $0 == key }
        songMemoryOrder.append(key)
        while songMemoryOrder.count > songMemoryLimit {
            let evict = songMemoryOrder.removeFirst()
            songMemory.removeValue(forKey: evict)
        }
    }

    private func persistMeta() {
        lock.lock()
        let snapshot = songMeta
        lock.unlock()
        persistAsync(snapshot, key: metaKey)
    }

    private func persistAsync<T: Encodable>(_ value: T, key: String) {
        writeQueue.async { [defaults] in
            guard let data = try? JSONEncoder().encode(value) else { return }
            defaults.set(data, forKey: key)
        }
    }

    /// 把旧版本存在 UserDefaults 里的一整包歌曲拆成单歌单文件；只做一次。
    private func migrateLegacySongsIfNeeded() {
        guard !defaults.bool(forKey: migratedKey) else { return }
        defaults.set(true, forKey: migratedKey)

        guard let data = defaults.data(forKey: legacySongsKey),
              let legacy = try? JSONDecoder().decode([String: SongEntry].self, from: data),
              !legacy.isEmpty else {
            defaults.removeObject(forKey: legacySongsKey)
            return
        }

        for (key, entry) in legacy {
            songMeta[key] = SongMeta(
                key: key,
                count: entry.songs.count,
                savedAt: entry.savedAt,
                pinned: entry.pinned,
                playlist: nil
            )
            let encoded = try? JSONEncoder().encode(entry)
            let url = songDirectory.appendingPathComponent(Self.fileName(for: key))
            writeQueue.async {
                if let encoded { try? encoded.write(to: url, options: .atomic) }
            }
        }
        defaults.removeObject(forKey: legacySongsKey)
        persistMeta()
    }
}
