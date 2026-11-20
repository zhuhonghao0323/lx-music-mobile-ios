import Foundation

enum PlaylistImportError: LocalizedError {
    case invalidLink
    case unsupportedPlatform(String)
    case emptyPlaylist

    var errorDescription: String? {
        switch self {
        case .invalidLink:
            return "没有识别出歌单链接或歌单 id，请粘贴完整的歌单分享链接"
        case .unsupportedPlatform(let name):
            return "\(name)暂不支持导入歌单"
        case .emptyPlaylist:
            return "这个歌单没有取到歌曲，可能是私密歌单或需要登录该平台"
        }
    }
}

struct PlaylistImportPayload {
    let playlist: Playlist
    /// 平台侧歌单标识（酷狗可能是 gcid）
    let sourceID: String
    let songs: [Song]
}

private extension SongSource {
    var displayName: String {
        switch self {
        case .netease: return "网易云音乐"
        case .qq: return "QQ音乐"
        case .kugou: return "酷狗音乐"
        case .migu: return "咪咕音乐"
        case .bodian: return "波点音乐"
        }
    }
}

/// 导入歌单的解析与抓取。
/// 参考原版 LX Music 的 `getListDetail / getListDetailAll`：
/// 输入歌单链接或 id → 拿到歌单元信息 + 全量歌曲，落到本地后可以随时更新。
enum PlaylistImportService {
    /// 从粘贴的文本里解析出平台 + 歌单 id。纯数字时使用当前选中的平台。
    static func parse(_ rawText: String, preferred: SongSource) -> (source: SongSource, sourceID: String)? {
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        let lower = text.lowercased()

        // 酷狗：优先 gcid，其次 specialid / listid
        if lower.contains("kugou.com") {
            if let gcid = firstMatch(#"gcid_[0-9a-zA-Z]+"#, in: text) {
                return (.kugou, gcid)
            }
            if let id = firstMatch(#"(?:special/single/|specialid=|listid=|listid/|plist/list/|/list/)(\d+)"#, in: text, group: 1) {
                return (.kugou, id)
            }
        }
        // 网易云
        if lower.contains("163.com") || lower.contains("music.163") {
            if let id = firstMatch(#"[?&#]id=(\d+)"#, in: text, group: 1)
                ?? firstMatch(#"/playlist/(\d+)"#, in: text, group: 1) {
                return (.netease, id)
            }
        }
        // QQ 音乐
        if lower.contains("qq.com") {
            if let id = firstMatch(#"/playlist/(\d+)"#, in: text, group: 1)
                ?? firstMatch(#"disstid=(\d+)"#, in: text, group: 1) {
                return (.qq, id)
            }
        }
        // 波点 / 酷我：分享页把歌单 id 放在 id= 参数里，优先取它，避免抓到别的数字
        if lower.contains("bodian") || lower.contains("kuwo.cn") {
            if let id = firstMatch(#"[?&]id=(\d+)"#, in: text, group: 1)
                ?? firstMatch(#"/(\d{6,})(?:\.html|$)"#, in: text, group: 1)
                ?? firstMatch(#"(\d{3,})"#, in: text, group: 1) {
                return (.bodian, id)
            }
        }
        // 纯数字：按当前平台解释
        if let id = firstMatch(#"^(\d{3,})$"#, in: text, group: 1) {
            return (preferred, id)
        }
        return nil
    }

    static func fetch(text: String, preferred: SongSource) async throws -> PlaylistImportPayload {
        guard let parsed = parse(text, preferred: preferred) else { throw PlaylistImportError.invalidLink }
        return try await fetch(source: parsed.source, sourceID: parsed.sourceID)
    }

    /// 从已知的歌单（歌单广场 / 排行榜 / 搜索结果）导入
    static func fetch(playlist: Playlist) async throws -> PlaylistImportPayload {
        let sourceID = playlist.externalID ?? String(playlist.id)
        let songs = dedupe(try await songs(source: playlist.source, sourceID: sourceID, fallbackID: playlist.id))
        guard !songs.isEmpty else { throw PlaylistImportError.emptyPlaylist }
        return PlaylistImportPayload(playlist: playlist, sourceID: sourceID, songs: songs)
    }

    static func fetch(source: SongSource, sourceID: String) async throws -> PlaylistImportPayload {
        guard source != .migu else { throw PlaylistImportError.unsupportedPlatform(source.displayName) }
        let numericID = Int(sourceID) ?? 0
        var playlist: Playlist?
        switch source {
        case .netease:
            if numericID > 0 {
                playlist = try? await NetEaseAPI.shared.playlistDetail(id: numericID)
            }
        case .qq:
            if numericID > 0 {
                playlist = try? await QQMusicAPI.shared.playlistDetail(listID: numericID)
            }
        case .kugou:
            playlist = try? await KugouMusicAPI.shared.playlistDetail(sourceID: sourceID)
        case .bodian:
            playlist = nil
        case .migu:
            throw PlaylistImportError.unsupportedPlatform(source.displayName)
        }
        let songs = dedupe(try await songs(source: source, sourceID: sourceID, fallbackID: numericID))
        guard !songs.isEmpty else { throw PlaylistImportError.emptyPlaylist }
        let resolved = playlist ?? Playlist(
            id: ImportedPlaylist.stableID(ImportedPlaylist.makeKey(source: source, sourceID: sourceID)),
            name: "\(source.displayName)歌单 \(sourceID.suffix(6))",
            coverURL: songs.first?.coverURL,
            trackCount: songs.count,
            source: source,
            externalID: sourceID
        )
        // 元信息缺失曲目数时用实际抓到的数量补齐
        let fixed = Playlist(
            id: resolved.id,
            name: resolved.name,
            coverURL: resolved.coverURL ?? songs.first?.coverURL,
            trackCount: resolved.trackCount > 0 ? resolved.trackCount : songs.count,
            source: source,
            externalID: sourceID
        )
        return PlaylistImportPayload(playlist: fixed, sourceID: sourceID, songs: songs)
    }

    private static func songs(source: SongSource, sourceID: String, fallbackID: Int) async throws -> [Song] {
        switch source {
        case .netease:
            let id = Int(sourceID) ?? fallbackID
            guard id > 0 else { return [] }
            return try await NetEaseAPI.shared.playlistTracks(id: id)
        case .qq:
            let id = Int(sourceID) ?? fallbackID
            guard id > 0 else { return [] }
            return try await QQMusicAPI.shared.playlistSongs(listID: id)
        case .kugou:
            let listID = Int(sourceID) ?? fallbackID
            return try await KugouMusicAPI.shared.playlistSongs(
                listID: listID,
                externalID: sourceID.hasPrefix("gcid_") || sourceID.contains("collection_") ? sourceID : nil
            )
        case .bodian:
            return try await BodianMusicAPI.shared.playlistTracks(playlistID: sourceID)
        case .migu:
            throw PlaylistImportError.unsupportedPlatform(source.displayName)
        }
    }

    /// 歌单里偶尔有重复曲目，列表用 identityKey 做 id，必须先去重
    private static func dedupe(_ songs: [Song]) -> [Song] {
        var seen = Set<String>()
        return songs.filter { seen.insert($0.identityKey).inserted }
    }

    // MARK: - 正则工具

    private static func firstMatch(_ pattern: String, in text: String, group: Int = 0) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              group < match.numberOfRanges,
              let matchRange = Range(match.range(at: group), in: text) else { return nil }
        return String(text[matchRange])
    }
}
