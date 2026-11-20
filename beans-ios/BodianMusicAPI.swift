import Foundation

/// 波点音乐（酷我系 / bd-api.kuwo.cn）接口。
///
/// 协议要点（已在本地实测通过）：
/// - 除少数账号接口外都是普通 GET，query 里必须带 `uid`（未登录为 `-1`）和 `token`（未登录为空串）；
/// - 需要签名的接口额外带 `timestamp` 与 `sign`：
///   `sign = md5("kuwotest" + sorted(只保留字母数字的已编码 query) + [md5(body + "kuwotest")] + path)`
/// - 请求头要伪装桌面端（`User-Agent: Dart/3.3 (dart:io)`、`plat: win`、`channel: W1`、`devid/qimei36` 等）；
/// - 未登录播放只能拿 30 秒试听（`checkRight` 返回 status=3 + audition），登录后才给整首。
final class BodianMusicAPI {
    static let shared = BodianMusicAPI()

    struct QRLogin {
        let key: String
        let url: String
    }

    enum LoginState {
        case waiting
        case scanned
        case expired
        case confirmed
    }

    enum BodianError: LocalizedError {
        case network
        case authRequired
        case regionRestricted
        case notPlayable
        /// 已扫码但手机上还没点确认
        case scannedNotConfirmed
        case invalid(String)

        var errorDescription: String? {
            switch self {
            case .network: return "波点音乐网络请求失败"
            case .authRequired: return "需要先扫码登录波点音乐"
            case .regionRestricted: return "该歌曲仅限中国大陆地区播放"
            case .notPlayable: return "波点音乐没有返回可播放地址"
            case .scannedNotConfirmed: return "已扫码，请在手机上点确认"
            case .invalid(let message): return message
            }
        }
    }

    private let apiOrigin = "https://bd-api.kuwo.cn"
    private let lyricOrigin = "https://mlyric.kuwo.cn"
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 25
        session = URLSession(configuration: config)
    }

    // MARK: - 搜索

    func searchSongs(keyword: String, limit: Int = 40, page: Int = 0) async throws -> [Song] {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let size = max(1, min(limit, 100))
        let pn = max(0, page)
        let json = try await call(
            "/api/search/music/list",
            params: ["keyword": trimmed, "correct": "1", "pn": "\(pn)", "rn": "\(size)"]
        )
        return Self.songs(from: json, field: "resultList")
    }

    // MARK: - 歌单

    /// 推荐歌单（首页 / 歌单广场用，匿名可访问）
    func recommendPlaylists(limit: Int = 18) async throws -> [Playlist] {
        let json = try await call("/api/service/finds/playlist", params: [:])
        return Array(Self.playlists(from: json, keys: ["playLists", "playlists", "list", "info"]).prefix(limit))
    }

    /// 歌单歌曲。source：4 普通歌单 / 5 我喜欢 / 6 收藏专辑
    func playlistTracks(playlistID: String, source: Int = 4, limit: Int = 100, page: Int = 1) async throws -> [Song] {
        guard !playlistID.isEmpty else { return [] }
        let size = max(1, min(limit, 100))
        let json = try await call(
            "/api/service/playlist/\(playlistID)/musicList",
            params: ["source": "\(source)", "pn": "\(max(1, page))", "rn": "\(size)"]
        )
        return Self.songs(from: json, field: "list")
    }

    /// 登录后的「我的歌单」：自建 / 我喜欢 / 收藏
    func userPlaylists() async throws -> [Playlist] {
        let auth = BodianMusicAuth.shared
        guard auth.isLoggedIn else { return [] }
        let params = ["userId": auth.uid, "fromUid": auth.uid]
        let created = try? await call("/api/service/playlist/userCreate", params: params)
        let fond = try? await call("/api/service/playlist/fond", params: params)
        let collected = try? await call(
            "/api/service/collect/4/list",
            params: params.merging(["pn": "1", "rn": "100"]) { $1 }
        )

        var result: [Playlist] = []
        var seen = Set<String>()
        func append(_ json: [String: Any]?) {
            guard let json else { return }
            for playlist in Self.playlists(from: json, keys: ["playLists", "playlists", "list", "info"]) {
                guard seen.insert(playlist.uniqueKey).inserted else { continue }
                result.append(playlist)
            }
        }
        // 「我喜欢」在前，随后是自建歌单与收藏
        append(fond)
        append(created)
        append(collected)
        return result
    }

    /// 我喜欢（红心）歌单的 id。波点这里返回的是单个歌单对象，不是数组。
    func likedPlaylistID() async throws -> String? {
        let auth = BodianMusicAuth.shared
        guard auth.isLoggedIn else { return nil }
        let json = try await call("/api/service/playlist/fond", params: ["userId": auth.uid, "fromUid": auth.uid])
        let lists = Self.playlists(from: json, keys: ["playLists", "list", "info"])
        let liked = lists.first { $0.name.contains("喜欢") || $0.name.contains("红心") }
        return (liked ?? lists.first)?.externalID
    }

    func likedSongs(limit: Int = 500) async throws -> [Song] {
        guard let playlistID = try await likedPlaylistID() else { return [] }
        return try await playlistTracks(playlistID: playlistID, source: 5, limit: min(limit, 100))
    }

    // MARK: - 播放地址

    /// 先查播放权限（checkRight），未登录/受限时只给 30 秒试听片段。
    func songURL(id: Int, quality: BeansAudioQuality) async throws -> String? {
        let musicID = String(id)
        let auth = BodianMusicAuth.shared
        // 1. 权限
        let rightBody = "{\"musicId\":\(musicID),\"freeSign\":\"\"}"
        let right = try await call(
            "/api/play/music/v2/checkRight",
            params: ["musicId": musicID, "freeSign": ""],
            body: rightBody,
            signed: true
        )
        let payload = right["data"] as? [String: Any] ?? [:]
        let status = Int(Self.string(payload["status"])) ?? 0
        if status == 3 {
            let audition = payload["audition"] as? [String: Any] ?? [:]
            let url = Self.string(audition["https"] ?? audition["url"])
            if url.hasPrefix("http") {
                BeansLogger.shared.log("波点音乐仅返回试听片段：\(musicID)（未登录或受限）", level: .warn)
                return url
            }
            throw BodianError.authRequired
        }
        if status == 7 {
            throw BodianError.notPlayable
        }
        if payload["status"] == nil {
            throw auth.isLoggedIn ? BodianError.notPlayable : BodianError.authRequired
        }
        // 2. 正式地址
        let format = Self.format(for: quality)
        let body = "{\"devId\":\"\(auth.deviceId)\",\"musicId\":\(musicID),\"format\":\"\(format.format)\",\"br\":\"\(format.br)\",\"freeSign\":\"\"}"
        let json = try await call(
            "/api/play/music/v2/audioUrl",
            params: ["devId": auth.deviceId, "musicId": musicID, "format": format.format, "br": format.br, "freeSign": ""],
            body: body,
            signed: true
        )
        let data = json["data"] as? [String: Any] ?? [:]
        let url = Self.string(data["audioHttpsUrl"] ?? data["audioUrl"])
        return url.hasPrefix("http") ? url : nil
    }

    // MARK: - 歌词

    func lyric(id: Int) async -> String? {
        let query = "type=lyric&req=2&lrcx=1&rid=\(id)&songname=&artist=&corp=kuwo&fromchannel=bodian"
        let encoded = Data(query.utf8).base64EncodedString()
        guard let json = try? await call(
            "/mobi.s",
            params: ["f": "bodian", "q": encoded],
            lyricHost: true
        ) else { return nil }
        guard let data = json["data"] as? [String: Any] else { return nil }
        let content = Self.string(data["content"])
        guard !content.isEmpty,
              let raw = Data(base64Encoded: content),
              let text = String(data: raw, encoding: .utf8) else { return nil }
        // 去掉逐字时间标签后仍是标准 LRC
        return text
            .replacingOccurrences(of: "<-?\\d+,-?\\d+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\[kuwo:[^\\]]*\\]", with: "", options: .regularExpression)
    }

    // MARK: - 扫码登录

    func qrLogin() async throws -> QRLogin {
        let json = try await call("/api/ucenter/login/qrCode", params: [:], signed: true, anonymous: true)
        let data = json["data"] as? [String: Any] ?? [:]
        let key = Self.string(data["qrCode"])
        guard !key.isEmpty else {
            throw BodianError.invalid("波点没有返回二维码标识")
        }
        var comps = URLComponents(string: "https://bodian-oia.kuwo.cn/bodian/download.html")
        comps?.queryItems = [
            URLQueryItem(name: "pageName", value: "login_pc"),
            URLQueryItem(name: "pt", value: "3"),
            URLQueryItem(name: "id", value: key),
        ]
        return QRLogin(key: key, url: comps?.url?.absoluteString ?? "")
    }

    func qrStatus(key: String) async throws -> LoginState {
        let json = try await call(
            "/api/ucenter/login/qrCodeStatus",
            params: ["qrCode": key],
            signed: true,
            anonymous: true
        )
        let data = json["data"] as? [String: Any] ?? [:]
        let status = Int(Self.string(data["status"])) ?? 0
        switch status {
        case 1: return .waiting
        case 2: return .expired
        case 3:
            // 波点的 status=3 只代表「可以换取了」，真正的登录态要再调一次 users/login；
            // 11027 表示手机端还没点确认，回到已扫码状态继续轮询。
            do {
                try await confirmLogin(key: key)
                return .confirmed
            } catch let error as BodianError {
                if case .scannedNotConfirmed = error { return .scanned }
                throw error
            }
        default: return .waiting
        }
    }

    /// 扫码确认后换取 uid / token
    @discardableResult
    func confirmLogin(key: String) async throws -> Bool {
        let json = try await call(
            "/api/ucenter/users/login",
            params: [:],
            body: "{\"authType\":10,\"qrCode\":\"\(key)\"}",
            signed: true,
            anonymous: true,
            method: "POST"
        )
        let data = json["data"] as? [String: Any] ?? [:]
        let user = data["userInfo"] as? [String: Any] ?? data["user"] as? [String: Any] ?? [:]
        let uid = Self.string(data["uid"] ?? data["id"] ?? user["uid"] ?? user["id"])
        let token = Self.string(data["token"])
        guard !uid.isEmpty, !token.isEmpty else {
            throw BodianError.invalid("波点登录返回缺少账号或凭证")
        }
        let nick = Self.string(user["nickname"] ?? user["name"] ?? data["nickname"])
        let avatar = Self.string(user["headImg"] ?? user["avatarUrl"] ?? data["headImg"])
        BodianMusicAuth.shared.saveLogin(uid: uid, token: token, nickname: nick, avatar: avatar)
        return true
    }

    // MARK: - 底层请求

    private func call(
        _ path: String,
        params: [String: String],
        body: String? = nil,
        signed: Bool = false,
        anonymous: Bool = false,
        lyricHost: Bool = false,
        method: String? = nil
    ) async throws -> [String: Any] {
        let auth = BodianMusicAuth.shared
        let useSession = !anonymous && auth.isLoggedIn
        var query = params
        query["uid"] = useSession ? auth.uid : "-1"
        query["token"] = useSession ? auth.token : ""

        let bodyText = body ?? ""
        if signed {
            query["timestamp"] = "\(Int(Date().timeIntervalSince1970 * 1000))"
            query["sign"] = Self.signature(path: path, params: query, body: bodyText)
        }

        let orderedKeys = query.keys.sorted()
        let queryString = orderedKeys
            .map { "\(Self.formEncode($0))=\(Self.formEncode(query[$0] ?? ""))" }
            .joined(separator: "&")
        let origin = lyricHost ? lyricOrigin : apiOrigin
        guard let url = URL(string: origin + path + "?" + queryString) else {
            throw BodianError.invalid("波点请求地址无效")
        }

        var request = URLRequest(url: url)
        request.httpMethod = method ?? "GET"
        for (key, value) in Self.desktopHeaders(deviceId: auth.deviceId) {
            request.setValue(value, forHTTPHeaderField: key)
        }
        if useSession {
            request.setValue(auth.uid, forHTTPHeaderField: "uid")
            request.setValue(auth.token, forHTTPHeaderField: "token")
        }
        if !bodyText.isEmpty {
            request.httpBody = Data(bodyText.utf8)
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            BeansLogger.shared.log("波点请求失败：\(path) \(error.localizedDescription)", level: .warn)
            throw BodianError.network
        }
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw BodianError.network
        }
        let code = Int(Self.string(json["code"])) ?? -1
        if code != 200 {
            let message = Self.string(json["msg"] ?? json["message"])
            if code == 407 { throw BodianError.regionRestricted }
            if code == 11012 { throw BodianError.authRequired }
            if code == 20018 { throw BodianError.notPlayable }
            if code == 11027 { throw BodianError.scannedNotConfirmed }
            BeansLogger.shared.log("波点接口返回失败：\(path) code=\(code) msg=\(message)", level: .warn)
            throw BodianError.invalid(message.isEmpty ? "波点接口返回 code=\(code)" : message)
        }
        return json
    }

    private static func desktopHeaders(deviceId: String) -> [String: String] {
        [
            "User-Agent": "Dart/3.3 (dart:io)",
            "plat": "win",
            "channel": "W1",
            "ver": "1.1.7",
            "svrver": "13",
            "api-ver": "application/json",
            "brand": "Windows",
            "net": "wifi",
            "devid": deviceId,
            "qimei36": deviceId,
            "Content-Type": "application/json",
        ]
    }

    /// 复刻 `URLSearchParams.toString()` 的百分号编码：空格转 `+`，其余非 [A-Za-z0-9-._*] 转 %XX
    private static func formEncode(_ value: String) -> String {
        var out = ""
        for byte in Array(value.utf8) {
            switch byte {
            case 0x41...0x5A, 0x61...0x7A, 0x30...0x39, 0x2D, 0x2E, 0x5F, 0x2A:
                out.append(Character(UnicodeScalar(byte)))
            case 0x20:
                out.append("+")
            default:
                out += String(format: "%%%02X", byte)
            }
        }
        return out
    }

    /// sign = md5("kuwotest" + sorted(alnum of encoded query) [+ md5(body + "kuwotest")] + path)
    private static func signature(path: String, params: [String: String], body: String) -> String {
        let query = params.keys.sorted()
            .map { "\(formEncode($0))=\(formEncode(params[$0] ?? ""))" }
            .joined(separator: "&")
        var seed = "kuwotest"
        seed += String(query.filter { $0.isASCII && ($0.isLetter || $0.isNumber) }.sorted())
        if !body.isEmpty {
            seed += md5(body + "kuwotest")
        }
        return md5(seed + path)
    }

    private static func md5(_ value: String) -> String {
        Data(value.utf8).md5Hex()
    }

    private static func format(for quality: BeansAudioQuality) -> (format: String, br: String) {
        switch quality {
        case .standard:
            return ("mp3", "128kmp3")
        case .higher, .exhigh:
            return ("mp3", "320kmp3")
        case .lossless, .hires:
            return ("flac", "2000kflac")
        }
    }

    // MARK: - 数据映射

    private static func dictArray(_ value: Any?, keys: [String]) -> [[String: Any]] {
        guard let dict = value as? [String: Any] else {
            if let array = value as? [[String: Any]] { return array }
            return []
        }
        for key in keys {
            if let array = dict[key] as? [[String: Any]] { return array }
        }
        for (_, child) in dict {
            if let array = child as? [[String: Any]], !array.isEmpty { return array }
        }
        return []
    }

    /// 波点不同接口的 data 有时是数组、有时是 `{ playLists: [...] }`、有时是单个歌单对象，
    /// 这里统一兼容，避免「我的歌单」漏掉「我喜欢」。
    private static func playlists(from json: [String: Any], keys: [String]) -> [Playlist] {
        let data = json["data"]
        if let array = data as? [[String: Any]] {
            return array.compactMap(playlist(from:))
        }
        if let dict = data as? [String: Any] {
            if dict["id"] != nil || dict["playlistId"] != nil || dict["listId"] != nil {
                if let single = playlist(from: dict) {
                    // 单对象形态：只在它确实是歌单（有名字）时返回
                    return [single]
                }
            }
            for key in keys {
                if let array = dict[key] as? [[String: Any]], !array.isEmpty {
                    return array.compactMap(playlist(from:))
                }
            }
            for (_, child) in dict {
                if let array = child as? [[String: Any]], !array.isEmpty {
                    return array.compactMap(playlist(from:))
                }
            }
        }
        return []
    }

    private static func songs(from json: [String: Any], field: String) -> [Song] {
        let payload = json["data"] as? [String: Any] ?? [:]
        let rows = (payload[field] as? [[String: Any]])
            ?? dictArray(payload, keys: [field, "list", "info", "resultList"])
        return rows.compactMap(song(from:))
    }

    private static func song(from raw: [String: Any]) -> Song? {
        guard let numericID = Int(string(raw["id"] ?? raw["musicId"] ?? raw["rid"])), numericID > 0 else {
            return nil
        }
        let name = string(raw["name"] ?? raw["songName"] ?? raw["songname"])
        guard !name.isEmpty else { return nil }
        let artistList = (raw["artists"] as? [[String: Any]]) ?? []
        let artists = artistList.isEmpty
            ? string(raw["artist"] ?? raw["artistName"])
            : artistList.compactMap { string($0["name"]) }.joined(separator: " / ")
        let album = string(raw["album"] ?? raw["albumName"])
        let cover = string(raw["albumPic"] ?? raw["cover"] ?? raw["pic"])
        let duration = Double(Int(string(raw["duration"])) ?? 0)
        return Song(
            id: numericID,
            name: name,
            artists: artists.isEmpty ? "未知歌手" : artists,
            album: album,
            coverURL: cover.hasPrefix("http") ? URL(string: cover) : nil,
            duration: duration,
            source: .bodian
        )
    }

    private static func playlist(from raw: [String: Any]) -> Playlist? {
        let rawID = string(raw["id"] ?? raw["playlistId"] ?? raw["listId"] ?? raw["pid"])
        guard !rawID.isEmpty else { return nil }
        let name = string(raw["name"] ?? raw["title"] ?? raw["listName"])
        guard !name.isEmpty else { return nil }
        let cover = string(raw["pic"] ?? raw["cover"] ?? raw["imgUrl"] ?? raw["coverUrl"])
        let count = Int(string(raw["count"] ?? raw["songCount"] ?? raw["musicCount"] ?? raw["total"])) ?? 0
        let numeric = Int(rawID) ?? abs(rawID.hashValue % 900_000) + 100_000
        return Playlist(
            id: numeric,
            name: name,
            coverURL: cover.hasPrefix("http") ? URL(string: cover) : nil,
            trackCount: count,
            source: .bodian,
            externalID: rawID
        )
    }

    private static func string(_ value: Any?) -> String {
        if let text = value as? String { return text.trimmingCharacters(in: .whitespacesAndNewlines) }
        if let number = value as? NSNumber { return number.stringValue }
        return ""
    }
}
