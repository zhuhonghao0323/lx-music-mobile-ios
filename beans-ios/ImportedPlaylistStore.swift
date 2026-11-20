import Foundation

/// 「导入歌单」条目。
///
/// 对应原版 LX Music 的「打开歌单 / 收藏歌单」：把一个平台歌单（链接或 id）
/// 连歌曲一起落到本地，之后可以随时更新。它和「账号同步歌单」并列，
/// 是音乐库里每个平台的第二类歌单——不依赖账号，内容存在本机。
struct ImportedPlaylist: Identifiable, Codable, Hashable {
    /// "\(source)|\(sourceID)"
    let key: String
    var name: String
    var sourceRaw: String
    /// 平台侧歌单标识：网易云 / QQ 是数字 id，酷狗是 gcid 或 specialid，波点是歌单 id
    var sourceID: String
    var coverURL: URL?
    var trackCount: Int
    var songs: [Song]
    var addedAt: Date
    var updatedAt: Date

    var id: String { key }

    var source: SongSource { SongSource(rawValue: sourceRaw) ?? .netease }

    static func makeKey(source: SongSource, sourceID: String) -> String {
        "\(source.rawValue)|\(sourceID)"
    }

    /// 稳定的数字 id：Swift 的 hashValue 每次启动都会变，不能用来做缓存/路由标识
    static func stableID(_ key: String) -> Int {
        var hash: UInt64 = 5381
        for byte in key.utf8 {
            hash = (hash &* 33) &+ UInt64(byte)
        }
        return Int(hash % 9_000_000) + 1_000_000
    }

    /// 打开详情页时用的 Playlist（外部 id 一起带出去，详情页仍走平台接口）
    var playlist: Playlist {
        Playlist(
            id: Int(sourceID) ?? Self.stableID(key),
            name: name,
            coverURL: coverURL,
            trackCount: trackCount,
            source: source,
            externalID: sourceID
        )
    }

    var updatedAtText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter.string(from: updatedAt)
    }
}

/// 导入歌单的本地仓库（JSON 落盘，避免上万首歌塞进 UserDefaults）
final class ImportedPlaylistStore: ObservableObject {
    static let shared = ImportedPlaylistStore()

    @Published private(set) var items: [ImportedPlaylist] = []

    private let queue = DispatchQueue(label: "Beans.ImportedPlaylistStore", qos: .utility)
    private let fileURL: URL

    private init() {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("BeansData", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("imported-playlists.json")
        load()
    }

    func playlists(for source: SongSource) -> [ImportedPlaylist] {
        items.filter { $0.source == source }
    }

    func contains(source: SongSource, sourceID: String) -> ImportedPlaylist? {
        let key = ImportedPlaylist.makeKey(source: source, sourceID: sourceID)
        return items.first { $0.key == key }
    }

    func item(for playlist: Playlist) -> ImportedPlaylist? {
        items.first { $0.key == ImportedPlaylist.makeKey(source: playlist.source, sourceID: playlist.externalID ?? String(playlist.id)) }
    }

    /// 新增或覆盖（导入同一个歌单视为更新）
    func upsert(
        name: String,
        source: SongSource,
        sourceID: String,
        coverURL: URL?,
        trackCount: Int,
        songs: [Song]
    ) {
        let key = ImportedPlaylist.makeKey(source: source, sourceID: sourceID)
        let now = Date()
        if let index = items.firstIndex(where: { $0.key == key }) {
            items[index].name = name
            items[index].coverURL = coverURL ?? items[index].coverURL
            items[index].trackCount = trackCount > 0 ? trackCount : songs.count
            items[index].songs = songs
            items[index].updatedAt = now
        } else {
            items.insert(
                ImportedPlaylist(
                    key: key,
                    name: name,
                    sourceRaw: source.rawValue,
                    sourceID: sourceID,
                    coverURL: coverURL,
                    trackCount: trackCount > 0 ? trackCount : songs.count,
                    songs: songs,
                    addedAt: now,
                    updatedAt: now
                ),
                at: 0
            )
        }
        persist()
    }

    func updateSongs(_ songs: [Song], key: String) {
        guard let index = items.firstIndex(where: { $0.key == key }) else { return }
        items[index].songs = songs
        items[index].trackCount = songs.count
        items[index].updatedAt = Date()
        persist()
    }

    func rename(key: String, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let index = items.firstIndex(where: { $0.key == key }) else { return }
        items[index].name = trimmed
        persist()
    }

    func remove(key: String) {
        items.removeAll { $0.key == key }
        persist()
    }

    // MARK: - 持久化

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let list = try? JSONDecoder().decode([ImportedPlaylist].self, from: data) else { return }
        items = list
    }

    private func persist() {
        let snapshot = items
        let url = fileURL
        queue.async {
            guard let data = try? JSONEncoder().encode(snapshot) else { return }
            try? data.write(to: url, options: .atomic)
        }
    }
}
