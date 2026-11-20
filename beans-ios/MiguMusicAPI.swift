import Foundation

/// 咪咕音乐接口。
///
/// 只依赖公开的 content 接口：
/// - 搜索：`/v1.0/content/search_all.do`（歌曲 / 歌手 / 专辑一次返回）
/// - 播放地址：`MIGUM2.0/v2.0/content/listen-url`（需要 copyrightId + contentId + channel）
/// - 歌词：搜索结果里的 `lyricUrl` 直链（LRC 文本）
final class MiguMusicAPI {
    static let shared = MiguMusicAPI()

    private let session: URLSession
    private let channel = "0146951"

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 25
        session = URLSession(configuration: config)
    }

    // MARK: - 搜索

    func searchSongs(keyword: String, limit: Int = 40, page: Int = 1) async throws -> [Song] {
        let json = try await searchJSON(keyword: keyword, limit: limit, page: page,
                                        switchTypes: ["song": 1])
        return Self.songs(from: json)
    }

    func searchArtists(keyword: String, limit: Int = 30) async throws -> [Artist] {
        let json = try await searchJSON(keyword: keyword, limit: limit, page: 1,
                                        switchTypes: ["singer": 1])
        let list = Self.resultArray(json, key: "singerResultData")
        return list.compactMap { item -> Artist? in
            guard let id = Self.string(item["id"]), !id.isEmpty else { return nil }
            let name = Self.string(item["name"]) ?? ""
            guard !name.isEmpty else { return nil }
            return Artist(id: id, name: name, coverURL: nil, source: .migu)
        }
    }

    func searchAlbums(keyword: String, limit: Int = 30) async throws -> [Album] {
        let json = try await searchJSON(keyword: keyword, limit: limit, page: 1,
                                        switchTypes: ["album": 1])
        let list = Self.resultArray(json, key: "albumResultData")
        return list.compactMap { item -> Album? in
            guard let id = Self.string(item["id"]), !id.isEmpty else { return nil }
            let name = Self.string(item["name"]) ?? ""
            guard !name.isEmpty else { return nil }
            let artist = Self.string(item["singer"]) ?? ""
            let cover = Self.imageURL(from: item["imgItems"])
            return Album(id: id, name: name, artistName: artist, coverURL: cover, source: .migu)
        }
    }

    /// 专辑曲目：咪咕没有公开的专辑详情接口，用「专辑名 + 歌手」搜索后按专辑名过滤。
    func albumSongs(albumName: String, artistName: String, limit: Int = 60) async throws -> [Song] {
        var keyword = albumName
        if !artistName.isEmpty { keyword += " " + artistName }
        let songs = try await searchSongs(keyword: keyword, limit: limit)
        let target = albumName.trimmingCharacters(in: .whitespacesAndNewlines)
        let matched = songs.filter {
            $0.album.trimmingCharacters(in: .whitespacesAndNewlines) == target
        }
        return matched.isEmpty ? songs : matched
    }

    /// 歌手热歌：同样用搜索兜底，按歌手名过滤。
    func artistSongs(artistName: String, limit: Int = 60) async throws -> [Song] {
        let songs = try await searchSongs(keyword: artistName, limit: limit)
        let matched = songs.filter { $0.artists.contains(artistName) }
        return matched.isEmpty ? songs : matched
    }

    // MARK: - 播放地址

    /// toneFlag：PQ=标准/HQ=320k/SQ=无损/ZQ=24bit
    func songURL(copyrightId: String, contentId: String, quality: BeansAudioQuality) async throws -> String? {
        for tone in Self.toneFlags(for: quality) {
            guard var components = URLComponents(string: "https://app.c.nf.migu.cn/MIGUM2.0/v2.0/content/listen-url") else {
                return nil
            }
            components.queryItems = [
                URLQueryItem(name: "netType", value: "00"),
                URLQueryItem(name: "resourceType", value: "2"),
                URLQueryItem(name: "songId", value: copyrightId),
                URLQueryItem(name: "contentId", value: contentId),
                URLQueryItem(name: "toneFlag", value: tone),
                URLQueryItem(name: "channel", value: channel)
            ]
            guard let url = components.url else { return nil }
            guard let data = try? await request(url),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let payload = json["data"] as? [String: Any],
                  let playURL = Self.string(payload["url"]),
                  playURL.hasPrefix("http") else {
                continue
            }
            return playURL
        }
        return nil
    }

    // MARK: - 歌词

    /// lyricUrl 直接返回 LRC 文本
    func lyric(urlString: String?) async -> String? {
        guard let urlString, !urlString.isEmpty, let url = URL(string: urlString) else { return nil }
        guard let data = try? await request(url),
              let text = String(data: data, encoding: .utf8), !text.isEmpty else { return nil }
        return text
    }

    // MARK: - 内部

    private func searchJSON(
        keyword: String,
        limit: Int,
        page: Int,
        switchTypes: [String: Int]
    ) async throws -> [String: Any] {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [:] }
        var types: [String: Int] = ["song": 0, "album": 0, "singer": 0, "playlist": 0]
        for (key, value) in switchTypes { types[key] = value }
        let switchText = (try? JSONSerialization.data(withJSONObject: types))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "{\"song\":1}"

        guard var components = URLComponents(string: "https://c.musicapp.migu.cn/v1.0/content/search_all.do") else {
            throw NetEaseError.unknown("咪咕搜索地址无效")
        }
        components.queryItems = [
            URLQueryItem(name: "text", value: trimmed),
            URLQueryItem(name: "pageNo", value: String(max(1, page))),
            URLQueryItem(name: "pageSize", value: String(max(1, min(limit, 100)))),
            URLQueryItem(name: "searchSwitch", value: switchText)
        ]
        guard let url = components.url else { throw NetEaseError.unknown("咪咕搜索地址无效") }
        let data = try await request(url)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NetEaseError.decoding("咪咕搜索数据格式异常")
        }
        return json
    }

    private func request(_ url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue("okhttp/3.12.13", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(channel, forHTTPHeaderField: "channel")
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw NetEaseError.unknown("咪咕接口 HTTP \(http.statusCode)")
        }
        return data
    }

    private static func resultArray(_ json: [String: Any], key: String) -> [[String: Any]] {
        (json[key] as? [String: Any])?["result"] as? [[String: Any]] ?? []
    }

    private static func songs(from json: [String: Any]) -> [Song] {
        resultArray(json, key: "songResultData").compactMap { item in
            guard let copyrightId = string(item["copyrightId"]), !copyrightId.isEmpty else { return nil }
            let contentIdText = string(item["contentId"]) ?? ""
            // id 用 contentId（咪咕全局唯一），没有时退回 songId
            let rawID = contentIdText.isEmpty ? (string(item["id"]) ?? "") : contentIdText
            guard let numericID = Int(rawID) else { return nil }
            let name = string(item["name"]) ?? ""
            guard !name.isEmpty else { return nil }
            let singers = (item["singers"] as? [[String: Any]])?.compactMap { string($0["name"]) } ?? []
            let albumDict = (item["albums"] as? [[String: Any]])?.first
            let albumName = albumDict.flatMap { string($0["name"]) } ?? ""
            let cover = imageURL(from: item["imgItems"])
            let vip = (string(item["vipType"]) ?? "").isEmpty == false
            let charged = (string(item["chargeAuditions"]) ?? "0") != "0"
            return Song(
                id: numericID,
                name: name,
                artists: singers.joined(separator: " / "),
                album: albumName,
                coverURL: cover,
                duration: 0,
                source: .migu,
                miguCopyrightId: copyrightId,
                fee: (vip || charged) ? 1 : 0
            )
        }
    }

    private static func imageURL(from raw: Any?) -> URL? {
        let items = raw as? [[String: Any]] ?? []
        for item in items {
            if let text = string(item["img"]), text.hasPrefix("http") {
                return URL(string: text)
            }
        }
        if let text = raw as? String, text.hasPrefix("http") { return URL(string: text) }
        return nil
    }

    private static func string(_ value: Any?) -> String? {
        if let text = value as? String { return text }
        if let number = value as? NSNumber { return number.stringValue }
        return nil
    }

    static func toneFlags(for quality: BeansAudioQuality) -> [String] {
        switch quality {
        case .standard: return ["PQ", "HQ"]
        case .higher: return ["HQ", "PQ"]
        case .exhigh: return ["HQ", "SQ", "PQ"]
        case .lossless: return ["SQ", "HQ", "PQ"]
        case .hires: return ["ZQ", "SQ", "HQ", "PQ"]
        }
    }
}
