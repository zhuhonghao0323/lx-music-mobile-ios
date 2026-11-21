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
        case .kuwo: return "酷我音乐"
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

        // 酷狗：优先概念版分享参数 / gcid，其次 specialid / listid
        if lower.contains("kugou.com") {
            // 概念版分享页参数：global_specialid=collection_3_xxxx_2_0（用户自建 / 收藏的云歌单）
            if let collect = firstMatch(#"global_specialid=([^&\s]+)"#, in: text, group: 1),
               !collect.isEmpty, collect != "0" {
                return (.kugou, collect)
            }
            if let gcid = firstMatch(#"gcid_[0-9a-zA-Z]+"#, in: text) {
                return (.kugou, gcid)
            }
            if let gcid = firstMatch(#"[?&]gcid=([^&\s]+)"#, in: text, group: 1), !gcid.isEmpty {
                return (.kugou, gcid)
            }
            if let id = firstMatch(#"(?:special/single/|specialid=|listid=|listid/|plist/list/|/list/)(\d+)"#, in: text, group: 1) {
                return (.kugou, id)
            }
            // 概念版短链（t1.kugou.com/xxxx / t.kugou.com/xxxx）：真实 id 需要跟随 302 才能拿到，
            // 这里先打标记，交给 fetch 阶段异步解析。
            if let short = firstMatch(#"https?://t\d*\.kugou\.com/[A-Za-z0-9]+"#, in: text) {
                return (.kugou, "short#" + short)
            }
        }
        // 直接粘贴 global_specialid 的值（不带域名）
        if lower.contains("collection_") || lower.contains("gcid_"),
           let token = firstMatch(#"(?:collection_|gcid_)[0-9a-zA-Z_]+"#, in: text) {
            return (.kugou, token)
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
        if lower.contains("kuwo.cn") && !lower.contains("bodian") {
            if let id = Self.kuwoPlaylistID(from: text) {
                return (.kuwo, id)
            }
        }
        if lower.contains("bodian") {
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

    /// 从酷我分享文案里取歌单 id：支持 playlist_detail/123、id=123、纯数字
    static func kuwoPlaylistID(from text: String) -> String? {
        if let id = firstMatch(#"(?:playlist_detail/|playlist/|id=|pid=)(\d{6,})"#, in: text, group: 1) {
            return id
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.allSatisfy({ $0.isNumber }), trimmed.count >= 6 { return trimmed }
        return nil
    }

    static func fetch(text: String, preferred: SongSource) async throws -> PlaylistImportPayload {
        guard let parsed = parse(text, preferred: preferred) else { throw PlaylistImportError.invalidLink }
        // 酷狗概念版短链：跟随 302 拿到真正的歌单标识（多为 collection_… 云歌单）
        if parsed.sourceID.hasPrefix("short#") {
            let url = String(parsed.sourceID.dropFirst("short#".count))
            guard let resolved = await resolveKugouShortLink(url) else { throw PlaylistImportError.invalidLink }
            BeansLogger.shared.log("酷狗短链解析：\(url) → \(resolved)", level: .info)
            return try await fetch(source: .kugou, sourceID: resolved)
        }
        return try await fetch(source: parsed.source, sourceID: parsed.sourceID)
    }

    /// 跟随酷狗短链重定向，从最终地址里取出歌单标识。
    /// 概念版分享链接形如 `https://t1.kugou.com/xxxx`，
    /// 会跳到 `activity.kugou.com/share/...?specialid=0&global_specialid=collection_3_xxx_2_0`。
    private static func resolveKugouShortLink(_ raw: String) async -> String? {
        guard let url = URL(string: raw) else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
            forHTTPHeaderField: "User-Agent"
        )
        guard let (_, response) = try? await URLSession.shared.data(for: request) else { return nil }
        // URLSession 默认自动跟随 302，response.url 就是落地页
        let finalURL = response.url?.absoluteString ?? raw
        if let id = extractKugouID(from: finalURL) { return id }
        // 少数情况会落到一个中转页，需要读页面里的跳转参数
        if let (data, _) = try? await URLSession.shared.data(for: request),
           let html = String(data: data, encoding: .utf8),
           let id = extractKugouID(from: html) {
            return id
        }
        return nil
    }

    /// 从 URL / 页面文本里提取酷狗歌单标识，优先级：云歌单 > gcid > specialid > listid
    private static func extractKugouID(from text: String) -> String? {
        if let value = firstMatch(#"global_specialid=([^&\s"'<>]+)"#, in: text, group: 1),
           !value.isEmpty, value != "0" {
            return value
        }
        if let value = firstMatch(#"gcid_[0-9a-zA-Z]+"#, in: text) {
            return value
        }
        if let value = firstMatch(#"[?&]gcid=([^&\s"'<>]+)"#, in: text, group: 1), !value.isEmpty {
            return value
        }
        if let value = firstMatch(#"specialid=(\d+)"#, in: text, group: 1), value != "0" {
            return value
        }
        if let value = firstMatch(#"(?:listid|list_id)[=/](\d+)"#, in: text, group: 1) {
            return value
        }
        return nil
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
        case .kuwo:
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
        case .kuwo:
            return try await KuwoMusicAPI.shared.playlistTracks(id: sourceID)
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
