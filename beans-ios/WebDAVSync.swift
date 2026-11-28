import Foundation
import UIKit
import Combine
import Security

// MARK: - 协议常量
//
// 同步是「单文件 + 整体合并」：
//   <远程目录>/beans-sync.json
// 每次同步：GET 远端 → 本地快照 → 按实体 updatedAt 做 LWW 合并 → PUT 合并结果 → 应用到本地。
// 文档格式详见 doc/webdav-sync.md，桌面端可直接按同一份 JSON 读写。

enum WebDAVSyncSchema {
    static let version = "beans.sync.v1"
    static let fileName = "beans-sync.json"
}

// MARK: - 同步文档

struct SyncDocument: Codable {
    var schema: String = WebDAVSyncSchema.version
    var revision: Int = 0
    /// 毫秒时间戳
    var updatedAt: Int64 = 0
    var deviceId: String = ""
    var deviceName: String = ""
    var playlists: [SyncPlaylist] = []
    var tombstones: [SyncTombstone] = []
    var playback: SyncPlayback?
    var devices: [String: SyncDevice] = [:]
}

struct SyncPlaylist: Codable {
    var id: String
    var name: String
    var createdAt: Int64
    var updatedAt: Int64
    var songs: [Song]
}

struct SyncTombstone: Codable {
    var id: String
    var deletedAt: Int64
}

struct SyncPlayback: Codable {
    var song: Song?
    var position: Double
    var duration: Double
    var isPlaying: Bool
    var playMode: String
    var updatedAt: Int64
    var deviceId: String
}

struct SyncDevice: Codable {
    var name: String
    var lastSyncAt: Int64
}

// MARK: - 本地元数据

private struct PlaylistMeta: Codable {
    var updatedAt: Int64
    var hash: String
}

// MARK: - 错误

enum WebDAVSyncError: LocalizedError {
    case notConfigured
    case invalidURL
    case unauthorized
    case http(Int)
    case conflict
    case invalidDocument

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "请先填写 WebDAV 地址与账号"
        case .invalidURL: return "服务器地址格式不正确（需要 http:// 或 https:// 开头）"
        case .unauthorized: return "账号或密码不正确（401）"
        case .http(let code): return "服务器返回 HTTP \(code)"
        case .conflict: return "远端文件在执行期间被修改，请重试"
        case .invalidDocument: return "远端同步文件格式无法识别"
        }
    }
}

// MARK: - WebDAV 客户端

struct WebDAVClient {
    let baseURL: URL
    let username: String
    let password: String
    let directory: String

    private var authorization: String? {
        guard !username.isEmpty else { return nil }
        let raw = "\(username):\(password)"
        return "Basic " + Data(raw.utf8).base64EncodedString()
    }

    private var fileName: String { WebDAVSyncSchema.fileName }

    func fileURL() -> URL {
        var url = baseURL
        for component in directory.split(separator: "/") {
            url.appendPathComponent(String(component))
        }
        url.appendPathComponent(fileName)
        return url
    }

    /// 逐级创建远程目录；已存在时服务器通常返回 405
    func ensureDirectory() async throws {
        var url = baseURL
        for component in directory.split(separator: "/") {
            url.appendPathComponent(String(component))
            let status = try await send("MKCOL", url: url).status
            if (200...299).contains(status) || status == 405 { continue }
            if status == 401 { throw WebDAVSyncError.unauthorized }
            // 403 常见于「目录已存在但无写权限」，继续尝试会让 PUT 给出更准确的错误
            if status == 403 { continue }
            throw WebDAVSyncError.http(status)
        }
    }

    /// 连通性检查：对根地址发 PROPFIND
    func ping() async throws {
        let status = try await send("PROPFIND", url: baseURL, headers: ["Depth": "0"]).status
        if status == 401 { throw WebDAVSyncError.unauthorized }
        guard status == 207 || (200...299).contains(status) else { throw WebDAVSyncError.http(status) }
    }

    func fetch() async throws -> (data: Data?, etag: String?) {
        let response = try await send("GET", url: fileURL())
        if response.status == 404 { return (nil, nil) }
        if response.status == 401 { throw WebDAVSyncError.unauthorized }
        guard (200..<300).contains(response.status) else { throw WebDAVSyncError.http(response.status) }
        let etag = response.headers["Etag"] as? String ?? response.headers["ETag"] as? String
        return (response.body, etag)
    }

    func put(_ data: Data, etag: String?) async throws {
        var headers = ["Content-Type": "application/json; charset=utf-8"]
        if let etag, !etag.isEmpty { headers["If-Match"] = etag }
        let response = try await send("PUT", url: fileURL(), headers: headers, body: data)
        if response.status == 412 { throw WebDAVSyncError.conflict }
        if response.status == 401 { throw WebDAVSyncError.unauthorized }
        guard (200..<300).contains(response.status) else { throw WebDAVSyncError.http(response.status) }
    }

    private struct Response {
        let status: Int
        let body: Data?
        let headers: [AnyHashable: Any]
    }

    private func send(
        _ method: String,
        url: URL,
        headers: [String: String] = [:],
        body: Data? = nil
    ) async throws -> Response {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 30
        if let authorization {
            request.setValue(authorization, forHTTPHeaderField: "Authorization")
        }
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        request.httpBody = body ?? (["MKCOL", "PROPFIND", "PUT"].contains(method) ? Data() : nil)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw WebDAVSyncError.http(0) }
        return Response(status: http.statusCode, body: data, headers: http.allHeaderFields)
    }
}

// MARK: - 同步中心

@MainActor
final class WebDAVSyncStore: ObservableObject {
    static let shared = WebDAVSyncStore()

    // 配置
    @Published var baseURL: String { didSet { defaults.set(baseURL, forKey: Keys.baseURL) } }
    @Published var username: String { didSet { defaults.set(username, forKey: Keys.username) } }
    @Published var directory: String { didSet { defaults.set(directory, forKey: Keys.directory) } }
    @Published var autoSync: Bool { didSet { defaults.set(autoSync, forKey: Keys.autoSync) } }

    var password: String {
        get { SyncKeychain.get("password") }
        set { SyncKeychain.set(newValue, key: "password") }
    }

    // 状态
    @Published private(set) var isSyncing = false
    @Published private(set) var statusText = ""
    @Published private(set) var lastSyncAt: Date?
    @Published private(set) var remotePlayback: SyncPlayback?
    @Published private(set) var lastError: String?

    private let defaults = UserDefaults.standard
    private var started = false
    private var cancellables = Set<AnyCancellable>()
    private var timer: Timer?
    private var libraryTask: Task<Void, Never>?
    private var playbackTask: Task<Void, Never>?
    private var pendingLibraryChange = false
    private var lastPlaybackSignature = ""
    private var lastPlaybackStamp: Int64 = 0

    private enum Keys {
        static let baseURL = "beans.webdav.baseURL"
        static let username = "beans.webdav.username"
        static let directory = "beans.webdav.directory"
        static let autoSync = "beans.webdav.autoSync"
        static let lastSyncAt = "beans.webdav.lastSyncAt"
        static let deviceId = "beans.webdav.deviceId"
        static let meta = "beans.webdav.playlistMeta"
        static let tombstones = "beans.webdav.tombstones"
        static let pending = "beans.webdav.pending"
    }

    private init() {
        baseURL = defaults.string(forKey: Keys.baseURL) ?? ""
        username = defaults.string(forKey: Keys.username) ?? ""
        directory = defaults.string(forKey: Keys.directory) ?? "/BeansMusic"
        autoSync = defaults.object(forKey: Keys.autoSync) as? Bool ?? false
        if let stamp = defaults.object(forKey: Keys.lastSyncAt) as? Date {
            lastSyncAt = stamp
        }
        if defaults.bool(forKey: Keys.pending) {
            pendingLibraryChange = true
        }
    }

    // MARK: 对外

    var isConfigured: Bool {
        !baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var summary: String {
        guard isConfigured else { return "未配置" }
        if let lastSyncAt {
            return "上次同步 " + Self.relativeFormatter.localizedString(for: lastSyncAt, relativeTo: Date())
        }
        return autoSync ? "已开启自动同步" : "已配置，尚未同步"
    }

    /// App 启动时调用一次
    func start() {
        guard !started else { return }
        started = true
        LocalLibraryStore.shared.$playlists
            .dropFirst()
            .sink { [weak self] _ in
                Task { @MainActor in self?.scheduleLibrarySync() }
            }
            .store(in: &cancellables)

        if let player = PlayerManager.current {
            player.$isPlaying
                .dropFirst()
                .sink { [weak self] _ in
                    Task { @MainActor in self?.schedulePlaybackSync() }
                }
                .store(in: &cancellables)
        }

        timer = Timer.scheduledTimer(withTimeInterval: 90, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.autoSync, PlayerManager.current?.isPlaying == true else { return }
                await self.syncNow(quiet: true)
            }
        }

        if autoSync, isConfigured {
            Task { await syncNow(quiet: true) }
        }
    }

    /// 回到前台：距上次同步超过 1 分钟就拉一次
    func handleForeground() {
        guard autoSync, isConfigured else { return }
        if let lastSyncAt, Date().timeIntervalSince(lastSyncAt) < 60 { return }
        Task { await syncNow(quiet: true) }
    }

    func testConnection() async -> String {
        do {
            let client = try makeClient()
            try await client.ping()
            try await client.ensureDirectory()
            return "连接成功"
        } catch {
            return "连接失败：\(error.localizedDescription)"
        }
    }

    func syncNow(quiet: Bool = false) async {
        guard !isSyncing, isConfigured else { return }
        if !quiet { statusText = "正在同步…" }
        isSyncing = true
        lastError = nil
        defer { isSyncing = false }

        do {
            let client = try makeClient()
            try await client.ensureDirectory()
            let (remoteData, etag) = try await client.fetch()
            let remote = try decode(remoteData)
            let local = makeLocalDocument()
            var merged = merge(local: local, remote: remote)
            merged.revision = max(local.revision, remote.revision) + 1
            merged.updatedAt = Self.nowMs()
            merged.deviceId = Self.deviceId
            merged.deviceName = Self.deviceName
            merged.devices[Self.deviceId] = SyncDevice(name: Self.deviceName, lastSyncAt: merged.updatedAt)

            let payload = try JSONEncoder().encode(merged)
            do {
                try await client.put(payload, etag: etag)
            } catch WebDAVSyncError.conflict {
                // 并发写：重新拉一次再合并
                let (freshData, freshEtag) = try await client.fetch()
                let fresh = try decode(freshData)
                merged = merge(local: local, remote: fresh)
                merged.revision = max(local.revision, fresh.revision) + 1
                merged.updatedAt = Self.nowMs()
                merged.deviceId = Self.deviceId
                merged.deviceName = Self.deviceName
                merged.devices[Self.deviceId] = SyncDevice(name: Self.deviceName, lastSyncAt: merged.updatedAt)
                try await client.put(try JSONEncoder().encode(merged), etag: freshEtag)
            }

            apply(merged)
            pendingLibraryChange = false
            defaults.set(false, forKey: Keys.pending)
            lastSyncAt = Date()
            defaults.set(lastSyncAt, forKey: Keys.lastSyncAt)
            statusText = "已同步 \(merged.playlists.count) 个歌单"
        } catch {
            lastError = error.localizedDescription
            statusText = "同步失败：\(error.localizedDescription)"
        }
    }

    /// 用远端记录继续播放（只在用户点击时调用，不自动跳歌）
    func resumeRemotePlayback() {
        guard let playback = remotePlayback, let song = playback.song, let player = PlayerManager.current else { return }
        player.playSong(song, in: [song])
        let position = playback.position
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            player.seek(to: position)
        }
        BeansHaptics.success()
        ToastCenter.shared.show("已从其他设备继续播放")
    }

    // MARK: 触发

    private func scheduleLibrarySync() {
        pendingLibraryChange = true
        defaults.set(true, forKey: Keys.pending)
        libraryTask?.cancel()
        libraryTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 6_000_000_000)
            guard !Task.isCancelled else { return }
            if autoSync { await syncNow(quiet: true) }
        }
    }

    private func schedulePlaybackSync() {
        playbackTask?.cancel()
        playbackTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }
            if autoSync { await syncNow(quiet: true) }
        }
    }

    // MARK: 本地快照

    private func makeLocalDocument() -> SyncDocument {
        var doc = SyncDocument()
        doc.deviceId = Self.deviceId
        doc.deviceName = Self.deviceName

        var meta = loadMeta()
        var tombstones = loadTombstones()
        let now = Self.nowMs()
        let playlists = LocalLibraryStore.shared.playlists
        let currentIds = Set(playlists.map { $0.id.uuidString })

        var items: [SyncPlaylist] = []
        for playlist in playlists {
            let id = playlist.id.uuidString
            let hash = Self.contentHash(name: playlist.name, songs: playlist.songs)
            var stamp = meta[id]?.updatedAt ?? Int64(playlist.createdAt.timeIntervalSince1970 * 1000)
            if let old = meta[id], old.hash != hash {
                stamp = now
            }
            meta[id] = PlaylistMeta(updatedAt: stamp, hash: hash)
            tombstones.removeValue(forKey: id)
            items.append(
                SyncPlaylist(
                    id: id,
                    name: playlist.name,
                    createdAt: Int64(playlist.createdAt.timeIntervalSince1970 * 1000),
                    updatedAt: stamp,
                    songs: playlist.songs
                )
            )
        }

        // 本地消失 = 删除，留下墓碑，避免被远端旧数据复活
        for id in Array(meta.keys) where !currentIds.contains(id) {
            tombstones[id] = now
            meta.removeValue(forKey: id)
        }

        saveMeta(meta)
        saveTombstones(tombstones)

        doc.playlists = items
        doc.tombstones = tombstones.map { SyncTombstone(id: $0.key, deletedAt: $0.value) }
        doc.playback = makeLocalPlayback()
        return doc
    }

    private func makeLocalPlayback() -> SyncPlayback? {
        guard let player = PlayerManager.current, let song = player.currentSong else { return nil }
        let playing = player.isPlaying
        let signature = "\(song.identityKey)|\(playing)"
        let now = Self.nowMs()
        let stamp: Int64
        if signature != lastPlaybackSignature || playing {
            stamp = now
            lastPlaybackSignature = signature
            lastPlaybackStamp = now
        } else {
            stamp = lastPlaybackStamp
        }
        return SyncPlayback(
            song: song,
            position: player.clock.progress,
            duration: max(player.clock.duration, song.duration),
            isPlaying: playing,
            playMode: player.playMode.rawValue,
            updatedAt: stamp,
            deviceId: Self.deviceId
        )
    }

    // MARK: 合并

    private func merge(local: SyncDocument, remote: SyncDocument) -> SyncDocument {
        var result = SyncDocument()
        result.schema = WebDAVSyncSchema.version
        result.devices = remote.devices
        for (key, value) in local.devices {
            result.devices[key] = value
        }

        var byId: [String: SyncPlaylist] = [:]
        for playlist in remote.playlists { byId[playlist.id] = playlist }
        for playlist in local.playlists {
            if let existing = byId[playlist.id] {
                byId[playlist.id] = playlist.updatedAt >= existing.updatedAt ? playlist : existing
            } else {
                byId[playlist.id] = playlist
            }
        }

        var tombstones: [String: Int64] = [:]
        for item in remote.tombstones {
            tombstones[item.id] = max(tombstones[item.id] ?? 0, item.deletedAt)
        }
        for item in local.tombstones {
            tombstones[item.id] = max(tombstones[item.id] ?? 0, item.deletedAt)
        }
        for (id, deletedAt) in tombstones {
            if let playlist = byId[id], playlist.updatedAt > deletedAt {
                // 删除之后又被编辑过：以编辑为准，撤销墓碑
                tombstones.removeValue(forKey: id)
            } else {
                byId.removeValue(forKey: id)
            }
        }

        result.playlists = byId.values.sorted { $0.createdAt < $1.createdAt }
        result.tombstones = tombstones.map { SyncTombstone(id: $0.key, deletedAt: $0.value) }

        // 播放状态：谁更新听谁的
        switch (local.playback, remote.playback) {
        case let (l?, r?):
            result.playback = l.updatedAt >= r.updatedAt ? l : r
        case let (l?, nil):
            result.playback = l
        case let (nil, r?):
            result.playback = r
        default:
            result.playback = nil
        }
        result.revision = max(local.revision, remote.revision)
        result.updatedAt = Self.nowMs()
        return result
    }

    // MARK: 应用合并结果

    private func apply(_ doc: SyncDocument) {
        let store = LocalLibraryStore.shared
        let current = store.playlists
        var existingById = Dictionary(uniqueKeysWithValues: current.map { ($0.id.uuidString, $0) })

        var next: [LocalPlaylist] = []
        for item in doc.playlists.sorted(by: { $0.createdAt < $1.createdAt }) {
            if var playlist = existingById[item.id] {
                playlist.name = item.name
                playlist.songs = item.songs
                next.append(playlist)
                existingById.removeValue(forKey: item.id)
            } else if let uuid = UUID(uuidString: item.id) {
                next.append(
                    LocalPlaylist(
                        id: uuid,
                        name: item.name,
                        songs: item.songs,
                        createdAt: Date(timeIntervalSince1970: Double(item.createdAt) / 1000)
                    )
                )
            }
        }

        if next != current {
            store.playlists = next
        }

        var meta: [String: PlaylistMeta] = [:]
        for item in doc.playlists {
            meta[item.id] = PlaylistMeta(updatedAt: item.updatedAt, hash: Self.contentHash(name: item.name, songs: item.songs))
        }
        saveMeta(meta)
        var tombstoneMap: [String: Int64] = [:]
        for item in doc.tombstones {
            tombstoneMap[item.id] = max(tombstoneMap[item.id] ?? 0, item.deletedAt)
        }
        saveTombstones(tombstoneMap)

        if let playback = doc.playback, playback.deviceId != Self.deviceId {
            remotePlayback = playback
        } else if let playback = doc.playback, playback.deviceId == Self.deviceId {
            remotePlayback = nil
        }
    }

    // MARK: 配置与工具

    private func makeClient() throws -> WebDAVClient {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw WebDAVSyncError.notConfigured }
        guard let url = URL(string: trimmed), let scheme = url.scheme?.lowercased(),
              scheme == "https" || scheme == "http" else {
            throw WebDAVSyncError.invalidURL
        }
        var normalized = directory.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.isEmpty { normalized = "/BeansMusic" }
        if !normalized.hasPrefix("/") { normalized = "/" + normalized }
        while normalized.count > 1 && normalized.hasSuffix("/") {
            normalized.removeLast()
        }
        return WebDAVClient(baseURL: url, username: username, password: password, directory: normalized)
    }

    private func decode(_ data: Data?) throws -> SyncDocument {
        guard let data, !data.isEmpty else { return SyncDocument() }
        do {
            return try JSONDecoder().decode(SyncDocument.self, from: data)
        } catch {
            throw WebDAVSyncError.invalidDocument
        }
    }

    private func loadMeta() -> [String: PlaylistMeta] {
        guard let data = defaults.data(forKey: Keys.meta),
              let value = try? JSONDecoder().decode([String: PlaylistMeta].self, from: data) else { return [:] }
        return value
    }

    private func saveMeta(_ value: [String: PlaylistMeta]) {
        if let data = try? JSONEncoder().encode(value) {
            defaults.set(data, forKey: Keys.meta)
        }
    }

    private func loadTombstones() -> [String: Int64] {
        guard let data = defaults.data(forKey: Keys.tombstones),
              let value = try? JSONDecoder().decode([String: Int64].self, from: data) else { return [:] }
        return value
    }

    private func saveTombstones(_ value: [String: Int64]) {
        if let data = try? JSONEncoder().encode(value) {
            defaults.set(data, forKey: Keys.tombstones)
        }
    }

    // MARK: 设备与哈希

    static var deviceId: String {
        let defaults = UserDefaults.standard
        if let id = defaults.string(forKey: Keys.deviceId) { return id }
        let id = UUID().uuidString
        defaults.set(id, forKey: Keys.deviceId)
        return id
    }

    static var deviceName: String {
        UIDevice.current.name
    }

    static func nowMs() -> Int64 {
        Int64(Date().timeIntervalSince1970 * 1000)
    }

    /// 稳定内容哈希（FNV-1a）：用来判断歌单是否真的变了，避免每次同步都刷新 updatedAt
    static func contentHash(name: String, songs: [Song]) -> String {
        var hash: UInt64 = 1469598103934665603
        func mix(_ text: String) {
            for byte in text.utf8 {
                hash ^= UInt64(byte)
                hash = hash &* 1099511628211
            }
        }
        mix(name)
        for song in songs {
            mix(song.identityKey)
            mix(song.name)
            mix(song.artists)
        }
        return String(hash, radix: 16)
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.unitsStyle = .short
        return formatter
    }()
}

// MARK: - Keychain

private enum SyncKeychain {
    private static let service = "com.beans.app.webdav"

    static func set(_ value: String, key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
        guard !value.isEmpty, let data = value.data(using: .utf8) else { return }
        var attributes = query
        attributes[kSecValueData as String] = data
        SecItemAdd(attributes as CFDictionary, nil)
    }

    static func get(_ key: String) -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let text = String(data: data, encoding: .utf8) else { return "" }
        return text
    }
}
