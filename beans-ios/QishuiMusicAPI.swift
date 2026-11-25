import Foundation

enum QishuiError: LocalizedError {
    case notLoggedIn
    case business(Int, String)
    case invalidResponse
    case previewOnly
    case signerUnavailable
    case unavailable

    var errorDescription: String? {
        switch self {
        case .notLoggedIn:
            return "汽水音乐未登录，请先在账号管理里粘贴网页 Cookie"
        case .business(let code, let message):
            return "汽水音乐请求被拒绝（\(code)）\(message.isEmpty ? "" : "：\(message)")"
        case .invalidResponse:
            return "汽水音乐返回了无法识别的数据，请稍后重试"
        case .previewOnly:
            return "汽水音乐只返回了试听片段，无法播放完整歌曲"
        case .signerUnavailable:
            return "汽水音乐搜索需要签名服务：请在账号设置里填写签名地址"
        case .unavailable:
            return "汽水音乐没有返回可用音频"
        }
    }

    /// 平台明确拒绝但换一个音源可能还能播，交给解锁逻辑处理
    var invitesUnblock: Bool {
        switch self {
        case .previewOnly, .unavailable: return true
        default: return false
        }
    }
}

/// 汽水音乐（抖音系）原生接口。
///
/// 免签名可用的能力：推荐歌单（`/luna/discover/mix`）、歌单详情与曲目
///（`/luna/pc/playlist/detail`，游标分页）、曲目详情与逐字歌词（`/luna/h5/seo_track`）、
/// 账号资料与账号歌单（带 Cookie 的 `/luna/pc/me*`）。
///
/// 搜索与 App 完整播放流由上游用 `X-Helios` / `X-Medusa` 签名保护，没有本地算法。
/// 这里不内置任何第三方签名地址：签名服务由用户自行填写，未填写时搜索直接给出明确错误，
/// Cookie 永远不会发到外部签名服务器。
final class QishuiMusicAPI {
    static let shared = QishuiMusicAPI()

    private let session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 45
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: configuration)
    }()

    private static let appHost = "https://beta-luna.douyin.com"
    private static let pcHost = "https://api.qishui.com"
    private static let androidUA = "Luna/19.1.0 Android"
    private static let pcUA = "LunaPC/3.3.0(359450208)"
    private static let browserUA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36"

    private static let signerURLKey = "beans.qishui.signerURL"
    private static let signerTokenKey = "beans.qishui.signerToken"

    /// 可选签名服务（兼容 SodaM 的 `/sign` 协议）。留空表示不启用搜索与 App 播放流。
    var signerURL: String {
        get { UserDefaults.standard.string(forKey: Self.signerURLKey) ?? "" }
        set { UserDefaults.standard.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: Self.signerURLKey) }
    }

    var signerToken: String {
        get { UserDefaults.standard.string(forKey: Self.signerTokenKey) ?? "" }
        set { UserDefaults.standard.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: Self.signerTokenKey) }
    }

    var hasSigner: Bool {
        guard let url = URL(string: signerURL), let scheme = url.scheme?.lowercased(), !signerURL.isEmpty else { return false }
        return scheme == "https" || scheme == "http"
    }

    // MARK: - 请求

    private func send(
        host: String,
        path: String,
        query: [String: String] = [:],
        payload: [String: Any]? = nil,
        cookie: String? = nil,
        userAgent: String? = nil
    ) async throws -> [String: Any] {
        var parameters = query
        parameters["aid"] = parameters["aid"] ?? "386088"
        guard var components = URLComponents(string: host + path) else { throw QishuiError.invalidResponse }
        components.queryItems = parameters.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        guard let url = components.url else { throw QishuiError.invalidResponse }

        var request = URLRequest(url: url)
        request.setValue(userAgent ?? Self.androidUA, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let cookieHeader = cookie ?? QishuiMusicAuth.shared.cookieHeader
        if !cookieHeader.isEmpty {
            request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
        }
        if let payload {
            request.httpMethod = "POST"
            request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw QishuiError.invalidResponse }
        if http.statusCode == 401 || http.statusCode == 403 { throw QishuiError.notLoggedIn }
        guard (200..<300).contains(http.statusCode), !data.isEmpty else {
            throw QishuiError.business(http.statusCode, "")
        }
        guard let body = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw QishuiError.invalidResponse
        }
        try Self.validate(body)
        return body
    }

    static func validate(_ body: [String: Any]) throws {
        for name in ["status_code", "error_code"] {
            if let code = body[name], number(code) != 0 {
                let message = string(body["status_msg"] ?? body["message"] ?? body["error_msg"])
                throw QishuiError.business(Int(number(code)), message)
            }
        }
        if let data = body["data"] as? [String: Any], let code = data["error_code"], number(code) != 0 {
            throw QishuiError.business(Int(number(code)), string(data["message"]))
        }
    }

    // MARK: - 浏览

    /// 推荐歌单：`POST /luna/discover/mix`，匿名可用，一次给一批 `discover_playlist` 区块。
    func discoverPlaylists(limit: Int = 24) async throws -> [Playlist] {
        let target = max(1, min(limit, 60))
        var result: [Playlist] = []
        var seen = Set<String>()
        var cursor = ""
        var rounds = 0
        while result.count < target, rounds < 4 {
            rounds += 1
            var payload: [String: Any] = ["count": target]
            if !cursor.isEmpty { payload["cursor"] = cursor }
            let body = try await send(
                host: Self.appHost,
                path: "/luna/discover/mix",
                query: ["device_platform": "android"],
                payload: payload
            )
            let blocks = body["inner_block"] as? [[String: Any]] ?? []
            for block in blocks {
                for resource in block["resources"] as? [[String: Any]] ?? [] {
                    guard let object = (resource["entity"] as? [String: Any])?["playlist"] as? [String: Any],
                          let playlist = Self.mapPlaylist(object),
                          let key = playlist.externalID,
                          seen.insert(key).inserted else { continue }
                    result.append(playlist)
                }
            }
            let next = Self.string(body["next_cursor"] ?? body["cursor"])
            guard Self.bool(body["has_more"]), !next.isEmpty, next != cursor else { break }
            cursor = next
        }
        BeansLogger.shared.log("汽水推荐歌单：返回 \(result.count) 个", level: result.isEmpty ? .warn : .debug)
        return Array(result.prefix(target))
    }

    /// 歌单详情 + 全部曲目。游标分页，只认「next_cursor 为空」为结束，
    /// 不按本次条数推算，避免服务端改 pagesize 后漏歌。
    func playlistDetail(playlistID: String) async throws -> (playlist: Playlist, songs: [Song]) {
        var cursor = ""
        var visited = Set<String>()
        var meta: [String: Any] = [:]
        var songs: [Song] = []
        var seen = Set<String>()
        var trackCount = 0
        while true {
            let body = try await send(
                host: Self.pcHost,
                path: "/luna/pc/playlist/detail",
                query: [
                    "playlist_id": playlistID,
                    "cursor": cursor,
                    "count": "50",
                    "app_name": "luna_pc",
                    "device_platform": "windows",
                    "version_code": "30030000",
                ],
                userAgent: Self.pcUA
            )
            let data = body["data"] as? [String: Any] ?? body
            if meta.isEmpty, let object = data["playlist"] as? [String: Any] { meta = object }
            if trackCount == 0 {
                trackCount = Int(Self.number(meta["count_tracks"] ?? meta["track_count"]))
            }
            for resource in data["media_resources"] as? [[String: Any]] ?? [] {
                guard let song = Self.mapResource(resource), seen.insert(song.identityKey).inserted else { continue }
                songs.append(song)
            }
            let next = Self.string(data["next_cursor"] ?? body["next_cursor"])
            // has_more 有时缺失但 next_cursor 还在，所以以游标为准
            guard !next.isEmpty, next != cursor, visited.insert(next).inserted, visited.count < 200 else { break }
            cursor = next
        }
        if meta["id"] == nil { meta["id"] = playlistID }
        let playlist = Self.mapPlaylist(meta, fallbackID: playlistID, trackCount: max(trackCount, songs.count))
        BeansLogger.shared.log(
            "汽水歌单：id=\(playlistID) 接口 \(trackCount) 首 解析 \(songs.count) 首",
            level: songs.isEmpty ? .warn : .debug
        )
        return (playlist, songs)
    }

    func playlistSongs(playlistID: String) async throws -> [Song] {
        try await playlistDetail(playlistID: playlistID).songs
    }

    /// 账号歌单：需要 Cookie。`/luna/pc/me/playlist` 返回 `playlists` 数组 + 游标。
    func userPlaylists() async throws -> [Playlist] {
        guard QishuiMusicAuth.shared.isLoggedIn else { throw QishuiError.notLoggedIn }
        var cursor = ""
        var visited = Set<String>()
        var result: [Playlist] = []
        var seen = Set<String>()
        while true {
            let body = try await send(
                host: Self.pcHost,
                path: "/luna/pc/me/playlist",
                query: ["cursor": cursor, "count": "50", "version_code": "30020100"],
                userAgent: Self.pcUA
            )
            for item in body["playlists"] as? [[String: Any]] ?? [] {
                guard let playlist = Self.mapPlaylist(item), let key = playlist.externalID,
                      seen.insert(key).inserted else { continue }
                result.append(playlist)
            }
            let next = Self.string(body["next_cursor"])
            guard Self.bool(body["has_more"]), !next.isEmpty, next != cursor, visited.insert(next).inserted else { break }
            cursor = next
        }
        BeansLogger.shared.log("汽水账号歌单：返回 \(result.count) 个", level: result.isEmpty ? .warn : .debug)
        return result
    }

    /// 账号资料：昵称 / 头像 / 会员。登录后调用一次即可。
    @discardableResult
    func refreshProfile() async -> Bool {
        let auth = QishuiMusicAuth.shared
        guard auth.isLoggedIn else { return false }
        guard let body = try? await send(
            host: Self.pcHost,
            path: "/luna/pc/me",
            query: [:],
            userAgent: Self.pcUA
        ) else { return false }
        let info = body["my_info"] as? [String: Any] ?? body["user"] as? [String: Any] ?? body
        let userId = Self.string(info["id"] ?? info["user_id"])
        let nickname = Self.string(info["nickname"] ?? info["name"] ?? info["user_name"])
        let avatar = Self.profileAvatar(info)
        var vip: String?
        if let flag = info["is_vip"] {
            vip = Self.bool(flag) ? "VIP" : nil
        }
        await MainActor.run {
            auth.updateProfile(nickname: nickname, avatar: avatar, userId: userId, vip: vip)
        }
        return !userId.isEmpty || !nickname.isEmpty
    }

    private static func profileAvatar(_ info: [String: Any]) -> String {
        let direct = string(info["avatar_url"] ?? info["avatar"] ?? info["avatar_large"])
        if !direct.isEmpty { return direct }
        if let object = info["avatar_thumb"] as? [String: Any] {
            return imageURL(object)
        }
        return ""
    }

    // MARK: - 搜索（需要签名服务）

    func searchSongs(keyword: String, limit: Int = 30) async throws -> [Song] {
        try await search(keyword: keyword, entity: "track", limit: limit).compactMap(Self.mapTrack)
    }

    func searchPlaylists(keyword: String, limit: Int = 20) async throws -> [Playlist] {
        try await search(keyword: keyword, entity: "playlist", limit: limit).compactMap { Self.mapPlaylist($0) }
    }

    private func search(keyword: String, entity: String, limit: Int) async throws -> [[String: Any]] {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        guard hasSigner else { throw QishuiError.signerUnavailable }
        var cursor = ""
        var visited = Set<String>()
        var objects: [[String: Any]] = []
        var seen = Set<String>()
        let type = entity
        while objects.count < limit {
            let body = try await signedRequest(
                path: "/luna/pc/search/\(type)",
                parameters: ["q": trimmed, "cursor": cursor, "count": "20"]
            )
            let groups = body["result_groups"] as? [[String: Any]] ?? []
            for group in groups {
                for resource in group["data"] as? [[String: Any]] ?? [] {
                    let object: [String: Any]?
                    if type == "track" {
                        object = Self.mapTrackEntity(resource)
                    } else {
                        let entityObject = resource["entity"] as? [String: Any] ?? resource
                        object = entityObject[type] as? [String: Any]
                    }
                    guard let object else { continue }
                    let id = Self.string(object["id"])
                    guard !id.isEmpty, seen.insert(id).inserted else { continue }
                    objects.append(object)
                }
            }
            let pagination = groups.first { Self.bool($0["has_more"]) } ?? groups.first
            let next = Self.string(pagination?["next_cursor"] ?? body["next_cursor"])
            guard Self.bool(pagination?["has_more"] ?? body["has_more"]), !next.isEmpty,
                  next != cursor, visited.insert(next).inserted, visited.count < 40 else { break }
            cursor = next
        }
        return Array(objects.prefix(limit))
    }

    /// 签名请求：签名服务只接收 URL / 方法 / 原始 body / 请求头，用于计算
    /// `X-Helios`、`X-Medusa`；Cookie 由本机随请求直接发给汽水，不经过签名服务。
    private func signedRequest(path: String, parameters: [String: String], payload: [String: Any]? = nil) async throws -> [String: Any] {
        guard hasSigner, let endpoint = URL(string: signerURL) else { throw QishuiError.signerUnavailable }
        let timestamp = Int64(Date().timeIntervalSince1970 * 1000)
        let device = String(timestamp)
        var query: [String: String] = [
            "aid": "386088", "app_name": "luna_pc", "region": "cn", "geo_region": "cn", "os_region": "cn",
            "sim_region": "", "device_id": device, "cdid": "", "iid": String(timestamp + 1),
            "version_name": "3.3.0", "version_code": "30030000", "channel": "official", "build_mode": "master",
            "network_carrier": "", "ac": "wifi", "tz_name": "Asia/Shanghai", "resolution": "",
            "device_platform": "windows", "device_type": "Windows", "os_version": "Windows 11",
            "fp": device,
        ]
        for (key, value) in parameters { query[key] = value }
        guard var components = URLComponents(string: Self.pcHost + path) else { throw QishuiError.invalidResponse }
        components.queryItems = query.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        guard let url = components.url else { throw QishuiError.invalidResponse }

        let bytes = try payload.map { try JSONSerialization.data(withJSONObject: $0, options: [.sortedKeys, .withoutEscapingSlashes]) }
        let method = bytes == nil ? "GET" : "POST"
        var headers = [
            "User-Agent": Self.pcUA,
            "x-luna-background-type": "foreground",
            "x-luna-is-background-req": "0",
            "x-luna-is-local-user": "1",
        ]
        let cookie = QishuiMusicAuth.shared.cookieHeader
        if !cookie.isEmpty { headers["Cookie"] = cookie }
        if let bytes {
            headers["Content-Type"] = "application/json; charset=utf-8"
        }

        var signRequest = URLRequest(url: endpoint)
        signRequest.httpMethod = "POST"
        signRequest.timeoutInterval = 12
        signRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let token = signerToken
        if !token.isEmpty { signRequest.setValue("Bearer " + token, forHTTPHeaderField: "Authorization") }
        // 只把「待签名内容」发出去：不含 Cookie，避免账号凭证落到第三方
        signRequest.httpBody = try JSONSerialization.data(withJSONObject: [
            "url": url.absoluteString,
            "method": method,
            "body": bytes.map { String(decoding: $0, as: UTF8.self) } ?? "",
            "headers": headers.filter { $0.key.lowercased() != "cookie" },
            "ts_ms": timestamp,
        ])

        let (signedData, signedResponse) = try await session.data(for: signRequest)
        guard let status = (signedResponse as? HTTPURLResponse)?.statusCode, (200..<300).contains(status),
              let signature = try? JSONSerialization.jsonObject(with: signedData) as? [String: Any],
              Self.bool(signature["ok"] ?? true) else { throw QishuiError.signerUnavailable }
        let returned = (signature["headers"] as? [String: Any] ?? [:]).merging(signature) { first, _ in first }
        for key in ["x-helios", "x-medusa"] {
            guard let value = returned.first(where: { $0.key.lowercased() == key })?.value as? String,
                  !value.isEmpty, !value.contains(where: \.isNewline) else { throw QishuiError.signerUnavailable }
            headers[key] = value
        }
        if let msToken = signature["ms_token"] as? String, !msToken.isEmpty {
            components.queryItems?.append(URLQueryItem(name: "msToken", value: msToken))
        }
        if let aBogus = signature["a_bogus"] as? String, !aBogus.isEmpty {
            components.queryItems?.append(URLQueryItem(name: "a_bogus", value: aBogus))
        }
        guard let finalURL = components.url else { throw QishuiError.invalidResponse }

        var request = URLRequest(url: finalURL)
        request.httpMethod = method
        request.httpBody = bytes
        for (key, value) in headers { request.setValue(value, forHTTPHeaderField: key) }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode), !data.isEmpty,
              let body = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw QishuiError.signerUnavailable
        }
        try Self.validate(body)
        return body
    }

    // MARK: - 歌词与播放

    /// 曲目详情（含逐字歌词与播放地址）。匿名可用，登录后带 Cookie 才能拿到完整音频。
    func seoTrack(trackID: String) async throws -> [String: Any] {
        try await send(
            host: Self.appHost,
            path: "/luna/h5/seo_track",
            query: ["track_id": trackID, "device_platform": "web"],
            cookie: QishuiMusicAuth.shared.cookieHeader,
            userAgent: Self.browserUA
        )
    }

    /// 歌词：汽水给的是 KRC（`[60,1470]<0,350,0>不…`），转成行级 LRC 交给现有解析器。
    func lyric(trackID: String) async throws -> String {
        let body = try await seoTrack(trackID: trackID)
        let lyric = body["lyric"] as? [String: Any] ?? [:]
        let content = Self.string(lyric["content"])
        guard !content.isEmpty else { throw QishuiError.unavailable }
        let type = Self.string(lyric["type"]).lowercased()
        if type.contains("krc") || content.contains("<") {
            return Self.lrc(fromKRC: content)
        }
        return content
    }

    static func lrc(fromKRC content: String) -> String {
        var lines: [String] = []
        for raw in content.components(separatedBy: "\n") {
            let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard line.hasPrefix("["), let close = line.firstIndex(of: "]") else { continue }
            let head = String(line[line.index(after: line.startIndex)..<close])
            guard let startMS = Int(head.split(separator: ",").first ?? "") else { continue }
            var text = String(line[line.index(after: close)...])
            // 去掉逐字标签 <起始,时长,音高>
            while let left = text.firstIndex(of: "<"), let right = text.firstIndex(of: ">"), left < right {
                text.removeSubrange(left...right)
            }
            text = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }
            let total = max(0, startMS)
            let minutes = total / 60_000
            let seconds = (total % 60_000) / 1_000
            let centis = (total % 1_000) / 10
            lines.append(String(format: "[%02d:%02d.%02d]%@", minutes, seconds, centis, text))
        }
        return lines.joined(separator: "\n")
    }

    /// 播放地址。只接受完整长度的流；只有试听片段时明确报错，不伪造成功。
    func songURL(trackID: String) async throws -> String? {
        let body = try await seoTrack(trackID: trackID)
        let seo = body["seo_track"] as? [String: Any]
        let track = seo?["track"] as? [String: Any] ?? body["track"] as? [String: Any] ?? [:]
        let player = body["track_player"] as? [String: Any] ?? seo?["track_player"] as? [String: Any] ?? [:]
        let fullMS = Self.number(track["duration"])
        guard fullMS > 0 else { throw QishuiError.unavailable }
        let expiry = Self.number(player["expire_at"])
        if expiry > 0, expiry < Date().timeIntervalSince1970 { throw QishuiError.unavailable }
        guard var model: Any = player["video_model"] else { throw QishuiError.unavailable }
        // video_model 是 JSON 字符串，且可能嵌套多层
        for _ in 0..<3 {
            guard let text = model as? String, let data = text.data(using: .utf8) else { break }
            guard let parsed = try? JSONSerialization.jsonObject(with: data) else { break }
            model = parsed
        }

        let range = track["playable_range"] as? [String: Any] ?? [:]
        let playableMS = Self.number(range["duration"])
        let restricted = Self.number(range["start"]) != 0 || (playableMS > 0 && playableMS < fullMS - 1000)

        struct Stream {
            let url: String
            let bitrate: Double
            let durationMS: Double
        }
        var streams: [Stream] = []
        func collect(_ node: Any?, depth: Int) {
            guard depth < 10 else { return }
            if let list = node as? [Any] {
                for item in list { collect(item, depth: depth + 1) }
                return
            }
            guard let entry = node as? [String: Any] else { return }
            let meta = entry["video_meta"] as? [String: Any] ?? [:]
            let duration = Self.number(entry["video_duration"] ?? entry["duration"] ?? meta["duration"])
            let ms = duration > 0 ? (duration > 1000 ? duration : duration * 1000) : 0
            let url = ["main_url", "main_play_url", "MainPlayUrl", "url", "backup_url"]
                .lazy.map({ Self.string(entry[$0]) }).first { !$0.isEmpty } ?? ""
            if !url.isEmpty {
                let bitrate = Self.number(entry["bitrate"] ?? meta["bitrate"] ?? meta["real_bitrate"])
                streams.append(Stream(url: url, bitrate: bitrate, durationMS: ms))
            }
            for child in entry.values { collect(child, depth: depth + 1) }
        }
        collect(model, depth: 0)
        guard !streams.isEmpty else { throw QishuiError.unavailable }

        let complete = streams.filter { $0.durationMS <= 0 || $0.durationMS >= fullMS - 1000 }
        if restricted || complete.isEmpty {
            // 明确说明只给试听，交给「换音源」逻辑处理，不假装播放成功
            throw QishuiError.previewOnly
        }
        let best = complete.max { $0.bitrate < $1.bitrate } ?? complete[0]
        BeansLogger.shared.log(
            "汽水播放地址：track=\(trackID) 完整流 \(complete.count)/\(streams.count) 档 选中 \(Int(best.bitrate/1000))kbps",
            level: .debug
        )
        return best.url
    }

    // MARK: - 解析

    static func mapResource(_ resource: [String: Any]) -> Song? {
        guard let track = mapTrackEntity(resource) else { return nil }
        return mapTrack(track)
    }

    static func mapTrackEntity(_ resource: [String: Any]) -> [String: Any]? {
        let entity = resource["entity"] as? [String: Any] ?? resource
        if let wrapper = entity["track_wrapper"] as? [String: Any], let track = wrapper["track"] as? [String: Any] {
            return track
        }
        if let track = entity["track"] as? [String: Any] { return track }
        // 搜索结果有时直接给 track 本体
        if entity["duration"] != nil, entity["id"] != nil { return entity }
        return nil
    }

    static func mapTrack(_ object: [String: Any]) -> Song? {
        let trackID = string(object["id"] ?? object["track_id"] ?? object["media_id"])
        guard !trackID.isEmpty else { return nil }
        let name = string(object["name"] ?? object["title"])
        let artists = (object["artists"] as? [[String: Any]] ?? object["singer"] as? [[String: Any]] ?? [])
            .compactMap { string($0["name"] ?? $0["artist_name"]) }
            .filter { !$0.isEmpty }
            .joined(separator: " / ")
        let albumObject = object["album"] as? [String: Any] ?? [:]
        let album = string(albumObject["name"] ?? albumObject["title"])
        let cover = imageURL(albumObject["url_cover"] ?? object["url_cover"] ?? object["cover"] ?? albumObject["cover"])
        let durationMS = number(object["duration"] ?? object["duration_ms"] ?? object["dt"])
        // 汽水只对「需要会员」的曲目给 playable_range，先按有无受限区间判断
        let range = object["playable_range"] as? [String: Any] ?? [:]
        let fee = number(range["duration"]) > 0 || number(range["start"]) > 0 ? 1 : 0
        return Song(
            id: stableID("qishui-" + trackID),
            name: name.isEmpty ? "汽水音乐" : name,
            artists: artists,
            album: album,
            coverURL: URL(string: cover),
            duration: durationMS > 0 ? durationMS / 1000 : 0,
            source: .qishui,
            qishuiTrackID: trackID,
            fee: fee
        )
    }

    static func mapPlaylist(_ object: [String: Any], fallbackID: String = "", trackCount: Int = 0) -> Playlist? {
        var identifier = string(object["id"] ?? object["playlist_id"] ?? object["mixture_id"])
        if identifier.isEmpty { identifier = fallbackID }
        guard !identifier.isEmpty else { return nil }
        let name = string(object["public_title"] ?? object["title"] ?? object["name"]).trimmingCharacters(in: .whitespacesAndNewlines)
        let cover = imageURL(object["url_cover"] ?? object["cover_url"] ?? object["cover"] ?? object["url_thumb"])
        let count = Int(number(object["count_tracks"] ?? object["track_count"] ?? object["count"]))
        let numericID = Int(identifier) ?? stableID("qishui-playlist-" + identifier)
        return Playlist(
            id: numericID,
            name: name.isEmpty ? "汽水歌单" : name,
            coverURL: URL(string: cover),
            trackCount: count > 0 ? count : trackCount,
            source: .qishui,
            externalID: identifier
        )
    }

    static func imageURL(_ value: Any?) -> String {
        if let text = value as? String { return text }
        guard let object = value as? [String: Any] else {
            return (value as? [String])?.first ?? ""
        }
        let uri = string(object["uri"])
        let template = string(object["template_prefix"])
        if !uri.isEmpty, !template.isEmpty, !uri.contains("://") {
            return "https://p3-luna.douyinpic.com/img/\(uri)~\(template)-resize:960:960.png"
        }
        if let urls = object["urls"] as? [String], let first = urls.first(where: { !$0.isEmpty }) {
            if uri.isEmpty { return first }
            if first.contains(uri) || !first.hasSuffix("/") { return first }
            return first + uri
        }
        return string(object["url"] ?? object["uri"])
    }

    static func stableID(_ text: String) -> Int {
        var hash: UInt32 = 2_166_136_261
        for byte in text.utf8 {
            hash = (hash ^ UInt32(byte)) &* 16_777_619
        }
        return Int(hash & 0x7FFF_FFFF) + 1
    }

    static func string(_ value: Any?) -> String {
        if let text = value as? String { return text }
        if let number = value as? NSNumber { return number.stringValue }
        return ""
    }

    static func number(_ value: Any?) -> Double {
        if let number = value as? NSNumber { return number.doubleValue }
        if let text = value as? String { return Double(text) ?? 0 }
        return 0
    }

    static func bool(_ value: Any?) -> Bool {
        if let value = value as? Bool { return value }
        if let number = value as? NSNumber { return number.boolValue }
        let text = string(value).lowercased()
        return text == "1" || text == "true" || text == "yes"
    }
}
