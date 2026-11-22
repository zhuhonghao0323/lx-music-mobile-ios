import Foundation
import SwiftUI
import WebKit

// MARK: - 酷我账号

/// 酷我登录态：只保存 Cookie（含 userid / Hm_Iuvt）与抓到的歌单列表。
/// 酷我没有开放平台，网页接口需要 Cookie + Secret 签名，因此这里保留完整 Cookie 字符串。
final class KuwoMusicAuth: ObservableObject {
    static let shared = KuwoMusicAuth()

    @Published private(set) var isLoggedIn = false
    @Published private(set) var uid = ""
    @Published private(set) var nickname = ""
    @Published private(set) var playlists: [Playlist] = []
    @Published private(set) var savedAt: Date = .distantPast

    private let authKey = "beans.kuwo.auth.v2"
    private let playlistsKey = "beans.kuwo.playlists.v2"
    private var cookie = ""

    private init() {
        if let saved = UserDefaults.standard.dictionary(forKey: authKey) as? [String: String] {
            cookie = saved["cookie"] ?? ""
            uid = saved["uid"] ?? ""
            nickname = saved["nickname"] ?? ""
            isLoggedIn = !cookie.isEmpty && !uid.isEmpty
        }
        if let data = UserDefaults.standard.data(forKey: playlistsKey),
           let list = try? JSONDecoder().decode([Playlist].self, from: data) {
            playlists = list
        }
        if let t = UserDefaults.standard.object(forKey: playlistsKey + ".at") as? Date {
            savedAt = t
        }
    }

    var cookieHeader: String { cookie }

    func saveLogin(cookie: String, uid: String, nickname: String) {
        self.cookie = cookie
        self.uid = uid
        self.nickname = nickname.isEmpty ? "酷我用户" : nickname
        isLoggedIn = !cookie.isEmpty && !uid.isEmpty
        UserDefaults.standard.set([
            "cookie": self.cookie,
            "uid": self.uid,
            "nickname": self.nickname
        ], forKey: authKey)
        NotificationCenter.default.post(name: .beansKuwoLoginDidUpdate, object: nil)
    }

    func savePlaylists(_ list: [Playlist]) {
        playlists = list
        savedAt = Date()
        if let data = try? JSONEncoder().encode(list) {
            UserDefaults.standard.set(data, forKey: playlistsKey)
            UserDefaults.standard.set(savedAt, forKey: playlistsKey + ".at")
        }
    }

    func clearPlaylists() {
        playlists = []
        UserDefaults.standard.removeObject(forKey: playlistsKey)
        UserDefaults.standard.removeObject(forKey: playlistsKey + ".at")
    }

    func logout() {
        cookie = ""
        uid = ""
        nickname = ""
        isLoggedIn = false
        UserDefaults.standard.removeObject(forKey: authKey)
        clearPlaylists()
        NotificationCenter.default.post(name: .beansKuwoLoginDidUpdate, object: nil)
    }
}

// MARK: - 酷我接口

/// 酷我音乐（www.kuwo.cn）。
///
/// 可用性说明（2026-11 实测）：
/// - 搜索：`www.kuwo.cn/search/searchMusicBykeyWord`，公开；
/// - 歌单歌曲：`nplserver.kuwo.cn/pl.svc?op=getlistinfo`，公开；
/// - 播放地址：`antiserver.kuwo.cn/anti.s`，公开，返回 128k/320k mp3；
/// - 歌词：酷我歌词接口已加密，这里复用同曲库的波点通道（rid 相同）；
/// - 我的歌单：网页接口需要 Cookie + `Secret` 头，登录后由 WebView 抓取或直接请求。
final class KuwoMusicAPI {
    static let shared = KuwoMusicAPI()

    enum KuwoError: LocalizedError {
        case invalid(String)
        case notPlayable
        case authRequired

        var errorDescription: String? {
            switch self {
            case .invalid(let message): return message
            case .notPlayable: return "酷我暂时没有可播放地址"
            case .authRequired: return "请先登录酷我账号"
            }
        }
    }

    private let session: URLSession
    private let mobileUA = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
    private let webUA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    private let cookieName = "Hm_Iuvt_cdb524f42f23cer9b268564v7y735ewrq2324"

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 25
        session = URLSession(configuration: config)
    }

    // MARK: 搜索

    func searchSongs(keyword: String, limit: Int = 40, page: Int = 0) async throws -> [Song] {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        var comps = URLComponents(string: "https://www.kuwo.cn/search/searchMusicBykeyWord")
        comps?.queryItems = [
            .init(name: "vipver", value: "1"),
            .init(name: "client", value: "kt"),
            .init(name: "ft", value: "music"),
            .init(name: "cluster", value: "0"),
            .init(name: "strategy", value: "2012"),
            .init(name: "encoding", value: "utf8"),
            .init(name: "rformat", value: "json"),
            .init(name: "mobi", value: "1"),
            .init(name: "issubtitle", value: "1"),
            .init(name: "show_copyright_off", value: "1"),
            .init(name: "pn", value: "\(max(0, page))"),
            .init(name: "rn", value: "\(limit)"),
            .init(name: "all", value: trimmed)
        ]
        guard let url = comps?.url else { throw KuwoError.invalid("搜索参数错误") }
        let json = try await requestJSON(url, headers: [
            "User-Agent": mobileUA,
            "Referer": "https://www.kuwo.cn/search/list?key=\(trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        ])
        let list = json["abslist"] as? [[String: Any]] ?? []
        return list.compactMap(Self.song(from:))
    }

    // MARK: 歌单

    func playlistInfo(id: String) async throws -> Playlist {
        let detail = try await playlistPayload(id: id, page: 0, size: 1)
        let title = Self.string(detail["title"])
        let pid = Self.int(detail["id"]) ?? Int(id) ?? abs(id.hashValue)
        let uid = Self.int(detail["uid"]) ?? 0
        let uname = Self.string(detail["uname"])
        let total = Self.int(detail["total"]) ?? 0
        let pic = Self.coverURL(Self.string(detail["pic"]))
        _ = uid
        _ = uname
        return Playlist(id: pid, name: title.isEmpty ? "酷我歌单" : title,
                        coverURL: pic, trackCount: total,
                        source: .kuwo, externalID: id)
    }

    func playlistTracks(id: String, limit: Int = 1000) async throws -> [Song] {
        var songs: [Song] = []
        var page = 0
        var total = Int.max
        while songs.count < min(limit, total), page < 20 {
            let detail = try await playlistPayload(id: id, page: page, size: 100)
            let list = detail["musiclist"] as? [[String: Any]] ?? []
            if let t = Self.int(detail["total"]) { total = t }
            if list.isEmpty { break }
            songs += list.compactMap(Self.song(fromPlaylist:))
            page += 1
        }
        return Array(songs.prefix(limit))
    }

    private func playlistPayload(id: String, page: Int, size: Int) async throws -> [String: Any] {
        var comps = URLComponents(string: "http://nplserver.kuwo.cn/pl.svc")
        comps?.queryItems = [
            .init(name: "op", value: "getlistinfo"),
            .init(name: "pid", value: id),
            .init(name: "pn", value: "\(page)"),
            .init(name: "rn", value: "\(size)"),
            .init(name: "encode", value: "utf8"),
            .init(name: "keyset", value: "pl2012"),
            .init(name: "identity", value: "kuwo"),
            .init(name: "pcmp4", value: "1"),
            .init(name: "vipver", value: "MUSIC_9.1.0.0_W1"),
            .init(name: "newver", value: "1")
        ]
        guard let url = comps?.url else { throw KuwoError.invalid("歌单参数错误") }
        let json = try await requestJSON(url, headers: [
            "User-Agent": mobileUA,
            "Referer": "https://www.kuwo.cn/"
        ])
        guard Self.string(json["result"]) == "ok" || json["musiclist"] != nil else {
            throw KuwoError.invalid("酷我没有返回这个歌单，可能已删除或未公开")
        }
        return json
    }

    // MARK: 排行榜 / 推荐歌单（首页，全部公开接口）

    /// 酷我官方榜单的 bangId，顺序即首页展示顺序（与 LX Music 的 kw 榜单一致）
    static let chartIDs: [Int] = [16, 17, 93, 145, 158, 151, 152, 155]

    /// 榜单列表：逐个请求 `ksong.s` 拿名称 / 封面 / 更新时间。
    /// 接口本身公开，不依赖登录；失败的榜直接跳过，不影响其它榜。
    func charts(limit: Int = 10) async throws -> [KuwoTopInfo] {
        var result: [KuwoTopInfo] = []
        for bangID in Self.chartIDs.prefix(limit) {
            if let info = await chartInfo(bangID: bangID) {
                result.append(info)
            }
        }
        guard !result.isEmpty else { throw KuwoError.invalid("酷我排行榜暂时不可用") }
        return result
    }

    private func chartInfo(bangID: Int) async -> KuwoTopInfo? {
        var comps = URLComponents(string: "https://kbangserver.kuwo.cn/ksong.s")
        comps?.queryItems = [
            .init(name: "from", value: "pc"),
            .init(name: "fmt", value: "json"),
            .init(name: "pn", value: "0"),
            .init(name: "rn", value: "1"),
            .init(name: "type", value: "bang"),
            .init(name: "data", value: "content"),
            .init(name: "id", value: "\(bangID)"),
            .init(name: "show_copyright_off", value: "0"),
            .init(name: "pcmp4", value: "1"),
            .init(name: "isbang", value: "1")
        ]
        guard let url = comps?.url,
              let json = try? await requestJSON(url, headers: ["User-Agent": mobileUA]) else { return nil }
        let name = Self.string(json["name"])
        guard !name.isEmpty else { return nil }
        // small 缩略图换成大图，首页卡片才不糊
        let pic = Self.string(json["pic"])
            .replacingOccurrences(of: "/small/", with: "/")
            .replacingOccurrences(of: "http://", with: "https://")
        return KuwoTopInfo(
            id: bangID,
            name: name,
            updateFrequency: Self.string(json["pub"]),
            coverURL: URL(string: pic)
        )
    }

    /// 榜单歌曲：`ksong.s` 一次最多返回 300 首
    func chartSongs(bangID: Int, limit: Int = 200) async throws -> [Song] {
        var comps = URLComponents(string: "https://kbangserver.kuwo.cn/ksong.s")
        comps?.queryItems = [
            .init(name: "from", value: "pc"),
            .init(name: "fmt", value: "json"),
            .init(name: "pn", value: "0"),
            .init(name: "rn", value: "\(max(1, min(limit, 300)))"),
            .init(name: "type", value: "bang"),
            .init(name: "data", value: "content"),
            .init(name: "id", value: "\(bangID)"),
            .init(name: "show_copyright_off", value: "0"),
            .init(name: "pcmp4", value: "1"),
            .init(name: "isbang", value: "1")
        ]
        guard let url = comps?.url else { throw KuwoError.invalid("榜单参数错误") }
        let json = try await requestJSON(url, headers: ["User-Agent": mobileUA])
        let list = json["musiclist"] as? [[String: Any]] ?? []
        guard !list.isEmpty else { throw KuwoError.invalid("该排行榜暂时没有歌曲") }
        return list.compactMap(Self.chartSong(from:))
    }

    private static func chartSong(from raw: [String: Any]) -> Song? {
        guard let rid = int(raw["id"]), rid > 0 else { return nil }
        let name = string(raw["name"])
        guard !name.isEmpty else { return nil }
        let artist = string(raw["artist"])
        let album = string(raw["album"])
        let pay = int(raw["pay"]) ?? 0
        return Song(
            id: rid,
            name: decodeEntities(name),
            artists: decodeEntities(artist.isEmpty ? "未知歌手" : artist),
            album: decodeEntities(album),
            coverURL: nil,
            duration: 0,
            source: .kuwo,
            fee: pay == 0 ? 0 : 1
        )
    }

    /// 推荐歌单（首页歌单板块）：公开的 PC 端推荐接口，按热度排序
    func recommendPlaylists(limit: Int = 18) async throws -> [Playlist] {
        var comps = URLComponents(string: "https://wapi.kuwo.cn/api/pc/classify/playlist/getRcmPlayList")
        comps?.queryItems = [
            .init(name: "pn", value: "1"),
            .init(name: "rn", value: "\(max(1, min(limit, 50)))"),
            .init(name: "order", value: "hot"),
            .init(name: "httpsStatus", value: "1")
        ]
        guard let url = comps?.url else { throw KuwoError.invalid("歌单参数错误") }
        let json = try await requestJSON(url, headers: [
            "User-Agent": mobileUA,
            "Referer": "https://www.kuwo.cn/"
        ])
        let data = json["data"] as? [String: Any]
        let list = (data?["data"] as? [[String: Any]]) ?? (json["data"] as? [[String: Any]]) ?? []
        return list.compactMap { raw in
            guard let pid = Self.int(raw["id"]), pid > 0 else { return nil }
            let name = Self.string(raw["name"])
            guard !name.isEmpty else { return nil }
            let img = Self.string(raw["img"]).replacingOccurrences(of: "http://", with: "https://")
            let total = Self.int(raw["total"]) ?? 0
            return Playlist(
                id: pid,
                name: Self.decodeEntities(name),
                coverURL: URL(string: img),
                trackCount: total,
                source: .kuwo,
                externalID: "\(pid)"
            )
        }
    }

    // MARK: 播放 / 歌词

    /// 酷我公开播放地址（anti.s），无需登录；拿不到时由调用方回退第三方音源。
    func songURL(id: Int) async -> String? {
        var comps = URLComponents(string: "https://antiserver.kuwo.cn/anti.s")
        comps?.queryItems = [
            .init(name: "type", value: "convert_url3"),
            .init(name: "rid", value: "MUSIC_\(id)"),
            .init(name: "format", value: "mp3"),
            .init(name: "response", value: "url")
        ]
        guard let url = comps?.url else { return nil }
        guard let json = try? await requestJSON(url, headers: ["User-Agent": mobileUA]),
              let text = json["url"] as? String,
              text.hasPrefix("http") else { return nil }
        return text
    }

    /// 酷我歌词接口已加密，复用波点（同曲库、同 rid）的解析结果
    func lyric(id: Int) async -> String? {
        await BodianMusicAPI.shared.lyric(id: id)
    }

    // MARK: 我的歌单（需要登录 Cookie）

    /// 拉取当前账号的歌单列表。接口校验 Cookie + Secret；失败时抛出，由页面引导用户手动导入。
    func fetchMyPlaylists() async throws -> [Playlist] {
        let auth = KuwoMusicAuth.shared
        guard auth.isLoggedIn else { throw KuwoError.authRequired }
        let uid = auth.uid
        let cookie = auth.cookieHeader
        let secret = Self.secret(cookieValue: Self.cookieValue(named: cookieName, in: cookie) ?? "")
        var comps = URLComponents(string: "https://www.kuwo.cn/api/www/user/playlist")
        comps?.queryItems = [
            .init(name: "uid", value: uid),
            .init(name: "pn", value: "1"),
            .init(name: "rn", value: "200"),
            .init(name: "httpsStatus", value: "1"),
            .init(name: "reqId", value: UUID().uuidString.lowercased()),
            .init(name: "plat", value: "web_www")
        ]
        guard let url = comps?.url else { throw KuwoError.invalid("歌单参数错误") }
        var headers: [String: String] = [
            "User-Agent": webUA,
            "Referer": "https://www.kuwo.cn/my/playlist",
            "Cookie": cookie,
            "Secret": secret
        ]
        // 酷我服务端会校验 csrf 与 Cookie 里的 kw_token 一致
        if let token = Self.cookieValue(named: "kw_token", in: cookie), !token.isEmpty {
            headers["csrf"] = token
        }
        let json = try await requestJSON(url, headers: headers)
        if let success = json["success"] as? Bool, !success {
            let message = Self.string(json["message"])
            if message.lowercased().contains("illegal") {
                throw KuwoError.invalid("酷我拒绝了这次请求（网页接口风控）。可以在下方手动导入歌单链接，或重新登录一次让网页刷新登录态")
            }
            throw KuwoError.invalid(message.isEmpty ? "酷我歌单接口暂不可用，可在下方手动粘贴歌单链接" : message)
        }
        let data = json["data"] as? [String: Any] ?? json
        let candidates = (data["data"] as? [[String: Any]])
            ?? (data["list"] as? [[String: Any]])
            ?? (data["playlist"] as? [[String: Any]])
            ?? []
        return candidates.compactMap { raw in
            let pid = Self.int(raw["id"] ?? raw["pid"] ?? raw["playlistId"]) ?? 0
            let name = Self.string(raw["name"] ?? raw["title"])
            guard pid > 0, !name.isEmpty else { return nil }
            let pic = Self.string(raw["pic"] ?? raw["cover"] ?? raw["img"])
            let count = Self.int(raw["total"] ?? raw["songCount"] ?? raw["musicNum"]) ?? 0
            return Playlist(id: pid, name: name, coverURL: Self.coverURL(pic),
                            trackCount: count, source: .kuwo, externalID: "\(pid)")
        }
    }

    // MARK: 网页签名

    /// 酷我网页版 axios 拦截器里的 Secret：用 Cookie 名和值生成一次性签名。
    /// 还原自 `kw-www` 前端的 `f(cookieValue, cookieName)`，不依赖账号密码。
    static func secret(cookieValue: String) -> String {
        let name = "Hm_Iuvt_cdb524f42f23cer9b268564v7y735ewrq2324"
        let digits = name.unicodeScalars.map { String($0.value) }.joined()
        guard !digits.isEmpty, !cookieValue.isEmpty else { return "" }
        let chars = Array(digits)
        func at(_ index: Int) -> Character? {
            index >= 0 && index < chars.count ? chars[index] : nil
        }
        let step = chars.count / 5
        let picked = [at(step), at(step * 2), at(step * 3), at(step * 4), at(step * 5)]
            .compactMap { $0 }
        guard let r = Int(String(picked)), r >= 2 else { return "" }
        let c = (name.count + 1) / 2
        let limit = 2_147_483_647
        // JS: d = Math.round(1e9*random())%1e8; n += d  （d 是数字，拼接时没有前导 0）
        let random = Int.random(in: 0..<100_000_000)
        var n = digits + String(random)
        while n.count > 10 {
            let first = Int(n.prefix(10)) ?? 0
            let rest = Int(n.dropFirst(10)) ?? 0
            n = String(first + rest)
        }
        guard var state = Int(n) else { return "" }
        state = (r * state + c) % limit
        var out = ""
        for scalar in cookieValue.unicodeScalars {
            let mixed = Int(scalar.value) ^ Int(Double(state) / Double(limit) * 255)
            out += String(format: "%02x", mixed)
            state = (r * state + c) % limit
        }
        // 关键：JS 末尾把随机数 d 的 16 进制（补足 8 位）拼在签名后面，
        // 少了这 8 位服务端一律判为 "The request is illegal!"。
        var tail = String(random, radix: 16)
        while tail.count < 8 { tail = "0" + tail }
        return out + tail
    }

    private static func cookieValue(named name: String, in cookie: String) -> String? {
        for part in cookie.split(separator: ";") {
            let trimmed = part.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix(name + "=") else { continue }
            return String(trimmed.dropFirst(name.count + 1))
        }
        return nil
    }

    // MARK: 解析

    private static func song(from raw: [String: Any]) -> Song? {
        let rawID = raw["DC_TARGETID"] ?? raw["MUSICRID"] ?? raw["id"]
        let idText = string(rawID).replacingOccurrences(of: "MUSIC_", with: "")
        guard let rid = int(idText), rid > 0 else { return nil }
        let name = string(raw["SONGNAME"] ?? raw["NAME"] ?? raw["songName"])
        guard !name.isEmpty else { return nil }
        let artist = string(raw["ARTIST"] ?? raw["artist"] ?? raw["FARTIST"])
        let album = string(raw["ALBUM"] ?? raw["album"])
        let duration = TimeInterval(int(raw["DURATION"] ?? raw["duration"]) ?? 0)
        let pic = string(raw["web_albumpic_short"] ?? raw["albumpic"] ?? raw["pic"])
        let fee = int(raw["PAY"]) ?? 0
        return Song(
            id: rid,
            name: decodeEntities(name),
            artists: decodeEntities(artist.isEmpty ? "未知歌手" : artist),
            album: decodeEntities(album),
            coverURL: coverURL(pic),
            duration: duration,
            source: .kuwo,
            fee: fee == 0 ? 0 : 1
        )
    }

    private static func song(fromPlaylist raw: [String: Any]) -> Song? {
        guard let rid = int(raw["id"] ?? raw["rid"]), rid > 0 else { return nil }
        let name = string(raw["displaysongname"] ?? raw["name"] ?? raw["SONGNAME"])
        guard !name.isEmpty else { return nil }
        let artist = string(raw["displayartistname"] ?? raw["artist"] ?? raw["ARTIST"])
        let album = string(raw["displayalbumname"] ?? raw["album"] ?? raw["ALBUM"])
        let duration = TimeInterval(int(raw["duration"] ?? raw["DURATION"]) ?? 0)
        let pic = string(raw["albumpic"] ?? raw["web_albumpic_short"])
        return Song(
            id: rid,
            name: decodeEntities(name),
            artists: decodeEntities(artist.isEmpty ? "未知歌手" : artist),
            album: decodeEntities(album),
            coverURL: coverURL(pic),
            duration: duration,
            source: .kuwo
        )
    }

    private static func coverURL(_ raw: String) -> URL? {
        guard !raw.isEmpty else { return nil }
        if raw.hasPrefix("http") { return URL(string: raw) }
        let path = raw.hasPrefix("/") ? String(raw.dropFirst()) : raw
        return URL(string: "https://img1.kuwo.cn/star/albumcover/\(path)")
    }

    private static func decodeEntities(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func string(_ value: Any?) -> String {
        if let text = value as? String { return text }
        if let number = value as? NSNumber { return number.stringValue }
        return ""
    }

    private static func int(_ value: Any?) -> Int? {
        if let number = value as? Int { return number }
        if let number = value as? NSNumber { return number.intValue }
        if let text = value as? String { return Int(text) }
        return nil
    }

    /// 给 `KuwoLoginWebView.Coordinator`（不同文件作用域）使用的解析helper
    static func intPublic(_ value: Any?) -> Int? { int(value) }
    static func stringPublic(_ value: Any?) -> String { string(value) }

    // MARK: 网络

    private func requestJSON(_ url: URL, headers: [String: String]) async throws -> [String: Any] {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
            throw KuwoError.invalid("酷我接口返回 \(http.statusCode)")
        }
        let object = try JSONSerialization.jsonObject(with: data)
        if let json = object as? [String: Any] { return json }
        throw KuwoError.invalid("酷我返回了无法识别的数据")
    }
}

// MARK: - 酷我登录

/// 酷我网页版登录。登录成功后原生读取 Cookie 里的 userid，并尝试拉取歌单；
/// 网页接口若被风控拦截，仍可在下方粘贴歌单链接手动导入。
struct KuwoLoginSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var theme: ThemeStore
    @ObservedObject private var auth = KuwoMusicAuth.shared

    @State private var status = "登录完成后会自动读取「我的歌单」"
    @State private var busy = false
    @State private var validating = false
    @State private var manualLink = ""
    @State private var manualCookie = ""
    @State private var showManualCookie = false
    @State private var imported: [Playlist] = []
    @State private var loginPromptToken = 0

    var body: some View {
        BeansNavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if auth.isLoggedIn {
                        loggedInCard
                    } else {
                        webCard
                    }
                    manualCard
                    if !auth.playlists.isEmpty {
                        playlistCard
                    }
                    Text("酷我网页接口需要登录 Cookie，登录后由 App 读取；不会上传任何账号信息。播放地址来自酷我公开接口，歌词复用同曲库通道。")
                        .font(BeansFont.appFont(11))
                        .foregroundStyle(Color.beansComment)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
                .padding(.bottom, 30)
            }
            .background {
                GlassBackdrop(customColor: theme.backgroundSyncAll ? theme.customBackground : nil)
            }
            .navigationTitle("酷我音乐")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    LibraryBackButton { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    private var loggedInCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Color.beansAmber)
                VStack(alignment: .leading, spacing: 2) {
                    Text(auth.nickname)
                        .font(BeansFont.appFont(15, .semibold))
                        .foregroundStyle(Color.beansLabel)
                    Text("UID \(auth.uid) · \(auth.playlists.count) 个歌单")
                        .font(BeansFont.appFont(11))
                        .foregroundStyle(Color.beansComment)
                }
                Spacer(minLength: 0)
                Button("退出") {
                    auth.logout()
                    status = "已退出酷我账号"
                }
                .font(BeansFont.appFont(12, .semibold))
                .foregroundStyle(.red)
            }
            Text(status)
                .font(BeansFont.appFont(11))
                .foregroundStyle(Color.beansComment)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                Task { await refreshPlaylists() }
            } label: {
                HStack {
                    if busy { ProgressView().controlSize(.small) }
                    Text(busy ? "正在读取歌单…" : "刷新我的歌单")
                    Spacer()
                    Image(systemName: "arrow.clockwise")
                }
                .font(BeansFont.appFont(13, .semibold))
                .foregroundStyle(Color.beansAmber)
                .padding(12)
                .background(Color.beansAmber.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background { BeansSurface(shape: RoundedRectangle(cornerRadius: 20, style: .continuous)) }
    }

    private var webCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "person.crop.circle.badge.checkmark")
                    .foregroundStyle(Color.beansAmber)
                Text("登录酷我账号")
                    .font(BeansFont.appFont(14, .semibold))
                    .foregroundStyle(Color.beansLabel)
                Spacer()
                if busy { ProgressView().controlSize(.mini) }
            }
            Text(status)
                .font(BeansFont.appFont(11))
                .foregroundStyle(Color.beansComment)
                .fixedSize(horizontal: false, vertical: true)

            KuwoLoginWebView(loginPromptToken: loginPromptToken) { cookie, uid, playlists in
                guard !uid.isEmpty else { return }
                // 注意顺序：网页里先把歌单抓完再回调，这里才写登录态。
                // 之前先写登录态会立刻把这张卡片换成「已登录」，WebView 被销毁，
                // 正在进行的歌单抓取就断了 —— 表现就是「登录成功但 0 个歌单」。
                auth.saveLogin(cookie: cookie, uid: uid, nickname: auth.nickname.isEmpty ? "酷我用户" : auth.nickname)
                if !playlists.isEmpty {
                    auth.savePlaylists(playlists)
                    status = "已登录，读到 \(playlists.count) 个歌单"
                } else {
                    status = "已登录，但网页没返回歌单，正在换原生接口再试…"
                    Task { await refreshPlaylists() }
                }
            }
            .frame(height: 460)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            Text("已自动打开登录框：支持手机号快捷登录、账号密码、微信 / QQ。登录成功后这里会变成你的账号信息。")
                .font(BeansFont.appFont(10.5))
                .foregroundStyle(Color.beansComment)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                loginPromptToken += 1
            } label: {
                Text("没看到登录框？点这里重新打开")
                    .font(BeansFont.appFont(11.5, .semibold))
                    .foregroundStyle(Color.beansAmber)
            }
            .buttonStyle(.plain)

            Button {
                showManualCookie.toggle()
            } label: {
                Text(showManualCookie ? "收起手动 Cookie" : "已在浏览器登录？粘贴 Cookie")
                    .font(BeansFont.appFont(11.5, .semibold))
                    .foregroundStyle(Color.beansAmber)
            }
            .buttonStyle(.plain)

            if showManualCookie {
                VStack(alignment: .leading, spacing: 8) {
                    TextEditor(text: $manualCookie)
                        .font(.system(size: 11, design: .monospaced))
                        .frame(height: 86)
                        .padding(8)
                        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
                    Button(validating ? "正在验证…" : "保存 Cookie") {
                        let raw = manualCookie.trimmingCharacters(in: .whitespacesAndNewlines)
                        let parsedUID = Self.uid(from: raw)
                        guard !parsedUID.isEmpty else {
                            status = "Cookie 里没有 userid，请确认复制完整"
                            return
                        }
                        guard !validating else { return }
                        validating = true
                        status = "正在验证 Cookie（会打开酷我网页确认登录态）…"
                        // 真实验证：用这份 Cookie 打开酷我首页，只有页面不再显示「登录 / 注册」
                        // 且 cookie 里带 userid 才保存，避免粘错 Cookie 后各处显示「未登录」。
                        KuwoCookieValidator.shared.validate(cookieHeader: raw) { ok in
                            validating = false
                            guard ok else {
                                status = "Cookie 验证失败：网页仍是未登录状态，可能已过期或不完整"
                                return
                            }
                            auth.saveLogin(cookie: raw, uid: parsedUID, nickname: "酷我用户")
                            status = "Cookie 已验证，正在读取歌单…"
                            Task { await refreshPlaylists() }
                        }
                    }
                    .font(BeansFont.appFont(12, .semibold))
                    .foregroundStyle(Color.beansAmber)
                    .disabled(validating)
                }
            }
        }
        .padding(14)
        .background { BeansSurface(shape: RoundedRectangle(cornerRadius: 20, style: .continuous)) }
    }

    private var manualCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("手动导入歌单")
                .font(BeansFont.appFont(13, .semibold))
                .foregroundStyle(Color.beansLabel)
            Text("粘贴酷我歌单链接（如 https://www.kuwo.cn/playlist_detail/2947959139），无需登录即可导入。")
                .font(BeansFont.appFont(11))
                .foregroundStyle(Color.beansComment)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                TextField("歌单链接或歌单 ID", text: $manualLink)
                    .font(BeansFont.appFont(12))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 10)
                    .padding(.vertical, 9)
                    .background(Color.primary.opacity(0.05), in: Capsule())
                Button("导入") {
                    Task { await importManual() }
                }
                .font(BeansFont.appFont(12, .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(Color.beansAmber, in: Capsule())
                .disabled(busy || manualLink.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(14)
        .background { BeansSurface(shape: RoundedRectangle(cornerRadius: 20, style: .continuous)) }
    }

    private var playlistCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("我的酷我歌单")
                .font(BeansFont.appFont(13, .semibold))
                .foregroundStyle(Color.beansLabel)
            ForEach(auth.playlists) { playlist in
                HStack(spacing: 10) {
                    CoverImage(url: playlist.coverURL, size: 40, cornerRadius: 9)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(playlist.name)
                            .font(BeansFont.appFont(13, .medium))
                            .foregroundStyle(Color.beansLabel)
                            .lineLimit(1)
                        Text(beansSongCountText(playlist.trackCount))
                            .font(BeansFont.appFont(10.5))
                            .foregroundStyle(Color.beansComment)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 3)
            }
        }
        .padding(14)
        .background { BeansSurface(shape: RoundedRectangle(cornerRadius: 20, style: .continuous)) }
    }

    private func refreshPlaylists() async {
        guard !busy else { return }
        busy = true
        defer { busy = false }
        do {
            let list = try await KuwoMusicAPI.shared.fetchMyPlaylists()
            auth.savePlaylists(list)
            status = list.isEmpty ? "登录成功，但这个账号没有公开歌单" : "已读取 \(list.count) 个歌单"
        } catch {
            status = error.localizedDescription
        }
    }

    private func importManual() async {
        let raw = manualLink.trimmingCharacters(in: .whitespacesAndNewlines)
        let id = Self.playlistID(from: raw)
        guard !id.isEmpty else {
            status = "链接里没有识别到歌单 ID"
            return
        }
        busy = true
        defer { busy = false }
        do {
            let playlist = try await KuwoMusicAPI.shared.playlistInfo(id: id)
            var list = auth.playlists
            if let index = list.firstIndex(where: { $0.externalID == id || $0.id == playlist.id }) {
                list[index] = playlist
            } else {
                list.insert(playlist, at: 0)
            }
            auth.savePlaylists(list)
            status = "已导入「\(playlist.name)」"
            manualLink = ""
        } catch {
            status = error.localizedDescription
        }
    }

    private static func playlistID(from raw: String) -> String {
        if raw.allSatisfy({ $0.isNumber }), !raw.isEmpty { return raw }
        if let range = raw.range(of: "playlist_detail/") {
            let tail = raw[range.upperBound...]
            let digits = tail.prefix { $0.isNumber }
            if !digits.isEmpty { return String(digits) }
        }
        let digits = raw.filter { $0.isNumber }
        return digits.count >= 6 ? digits : ""
    }

    private static func uid(from cookie: String) -> String {
        for part in cookie.split(separator: ";") {
            let trimmed = part.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("userid=") {
                return String(trimmed.dropFirst("userid=".count))
            }
        }
        return ""
    }
}

// MARK: - 登录用 WKWebView

/// 打开酷我网页版，轮询 Cookie；拿到 userid 后回传完整 Cookie。
private struct KuwoLoginWebView: UIViewRepresentable {
    /// 点一次「重新打开登录框」就 +1，用来手动唤出登录弹窗（自动点击失败时兜底）
    var loginPromptToken: Int = 0
    let onLogin: (String, String, [Playlist]) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onLogin: onLogin) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        // 必须用桌面版 UA：移动版 m.kuwo.cn 只有排行榜和「下载 APP」，根本没有登录入口
        // （用户截图里那一页就是移动版）。桌面版 www.kuwo.cn 顶部有「登录 / 注册」，
        // 点开就是手机号快捷登录 / 账号密码 / 微信 / QQ。
        webView.customUserAgent = KuwoWebUserAgent.desktop
        webView.load(URLRequest(url: URL(string: "https://www.kuwo.cn/")!))
        context.coordinator.start(webView: webView)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard context.coordinator.lastPromptToken != loginPromptToken else { return }
        context.coordinator.lastPromptToken = loginPromptToken
        if loginPromptToken > 0 {
            webView.evaluateJavaScript(Coordinator.openLoginPanelJS)
        }
    }

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        coordinator.stop()
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        private let onLogin: (String, String, [Playlist]) -> Void
        private weak var webView: WKWebView?
        private var timer: Timer?
        private var reported = false
        private var openedLoginPanel = false
        private var delivered = false
        var lastPromptToken = 0

        init(onLogin: @escaping (String, String, [Playlist]) -> Void) {
            self.onLogin = onLogin
        }

        func start(webView: WKWebView) {
            self.webView = webView
            timer?.invalidate()
            let timer = Timer(timeInterval: 1.5, repeats: true) { [weak self] _ in
                self?.probeCookies()
            }
            RunLoop.main.add(timer, forMode: .common)
            self.timer = timer
        }

        func stop() {
            timer?.invalidate()
            timer = nil
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard !openedLoginPanel, !reported else { return }
            openedLoginPanel = true
            // 桌面版首页是 Vue 渲染的，等按钮挂载完再点，否则 querySelector 拿到 nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak webView] in
                webView?.evaluateJavaScript(Self.openLoginPanelJS)
            }
        }

        private func probeCookies() {
            guard !reported, let webView else { return }
            webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { [weak self] cookies in
                guard let self, !self.reported else { return }
                let kuwo = cookies.filter { $0.domain.contains("kuwo.cn") }
                guard !kuwo.isEmpty else { return }
                let header = kuwo.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
                let uid = kuwo.first { $0.name == "userid" || $0.name == "uid" }?.value ?? ""
                guard !uid.isEmpty else { return }
                // cookie 上已经有 userid；再等一拍让页面把「登录 / 注册」换成昵称，
                // 避免把浏览态 cookie 误判成登录成功。
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    guard !self.reported else { return }
                    self.reported = true
                    self.collectPlaylists(cookie: header, uid: uid)
                }
            }
        }

        // MARK: 登录后读歌单（页面内同源请求 + DOM 兜底）

        /// 登录成功后进「我的歌单」页。原生请求带不全浏览器的 Cookie / Referer / 签名，
        /// 所以改成在页面里用同源 fetch 请求接口 —— 浏览器的 Cookie、Referer、
        /// 设备指纹都是真的，成功率远高于原生 URLSession。
        private func collectPlaylists(cookie: String, uid: String) {
            guard let webView else {
                deliver(cookie: cookie, uid: uid, list: [])
                return
            }
            let target = "https://www.kuwo.cn/my/playlist"
            if webView.url?.absoluteString.hasPrefix(target) != true {
                webView.load(URLRequest(url: URL(string: target)!))
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) { [weak self] in
                self?.fetchPlaylistsInPage(cookie: cookie, uid: uid, attempt: 0)
            }
        }

        private func fetchPlaylistsInPage(cookie: String, uid: String, attempt: Int) {
            guard let webView, !delivered else { return }
            let js = Self.playlistFetchJS.replacingOccurrences(of: "__UID__", with: uid)
            webView.evaluateJavaScript(js, completionHandler: nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { [weak self] in
                guard let self, !self.delivered else { return }
                self.webView?.evaluateJavaScript("window.__kuwoPlaylistPayload || ''") { result, _ in
                    let text = (result as? String) ?? ""
                    let list = Self.parsePlaylists(text)
                    if !list.isEmpty {
                        self.deliver(cookie: cookie, uid: uid, list: list)
                    } else if attempt < 2 {
                        self.fetchPlaylistsInPage(cookie: cookie, uid: uid, attempt: attempt + 1)
                    } else {
                        self.scrapePlaylistDOM(cookie: cookie, uid: uid, attempt: 0)
                    }
                }
            }
        }

        /// 接口被风控时退回 DOM：直接抓页面上的歌单卡片链接
        private func scrapePlaylistDOM(cookie: String, uid: String, attempt: Int) {
            guard let webView, !delivered else { return }
            webView.evaluateJavaScript(Self.scrapeJS) { [weak self] result, _ in
                guard let self, !self.delivered else { return }
                let list = Self.parseScraped(result)
                if !list.isEmpty {
                    self.deliver(cookie: cookie, uid: uid, list: list)
                } else if attempt < 2 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                        self.scrapePlaylistDOM(cookie: cookie, uid: uid, attempt: attempt + 1)
                    }
                } else {
                    self.deliver(cookie: cookie, uid: uid, list: [])
                }
            }
        }

        private func deliver(cookie: String, uid: String, list: [Playlist]) {
            guard !delivered else { return }
            delivered = true
            onLogin(cookie, uid, list)
        }

        /// 页面内同源请求「我的歌单」。Secret 用酷我前端同一套算法
        /// （`f(cookieValue, cookieName)`），在页面里算比在 Swift 里算更不容易出错。
        /// 结果写进 `window.__kuwoPlaylistPayload`，Swift 侧轮询读取。
        static let playlistFetchJS = #"""
        (function(){
          window.__kuwoPlaylistPayload = "";
          function sign(t,e){
            if(!e||e.length<=0) return null;
            var n="";for(var i=0;i<e.length;i++)n+=e.charCodeAt(i).toString();
            var o=Math.floor(n.length/5),
                r=parseInt(n.charAt(o)+n.charAt(2*o)+n.charAt(3*o)+n.charAt(4*o)+n.charAt(5*o)),
                c=Math.ceil(e.length/2),
                l=Math.pow(2,31)-1;
            if(r<2) return null;
            var d=Math.round(1e9*Math.random())%1e8;
            for(n+=d;n.length>10;)n=(parseInt(n.substring(0,10))+parseInt(n.substring(10,n.length))).toString();
            n=(r*n+c)%l;
            var h="";
            for(i=0;i<t.length;i++){
              var x=parseInt(t.charCodeAt(i)^Math.floor(n/l*255));
              h+=x<16?"0"+x.toString(16):x.toString(16);
              n=(r*n+c)%l;
            }
            for(d=d.toString(16);d.length<8;)d="0"+d;
            return h+d;
          }
          var NAME="Hm_Iuvt_cdb524f42f23cer9b268564v7y735ewrq2324";
          function readCookie(name){
            var m=document.cookie.match(new RegExp("(^|;\\s*)"+name+"=([^;]*)"));
            return m?decodeURIComponent(m[2]):"";
          }
          var cv=readCookie(NAME), tk=readCookie("kw_token");
          var headers={"Accept":"application/json, text/plain, */*"};
          if(tk) headers["csrf"]=tk;
          var s=sign(cv,NAME);
          if(s) headers["Secret"]=s;
          var url="/api/www/user/playlist?uid=__UID__&pn=1&rn=100&httpsStatus=1&reqId="+Date.now()+"&plat=web_www";
          fetch(url,{headers:headers,credentials:"include"})
            .then(function(r){return r.text();})
            .then(function(t){window.__kuwoPlaylistPayload=t;})
            .catch(function(){window.__kuwoPlaylistPayload="";});
          return "ok";
        })()
        """#

        /// 从接口返回里捞歌单数组：兼容 data.data / data.list / data.playlist 等层级
        static func parsePlaylists(_ text: String) -> [Playlist] {
            guard !text.isEmpty,
                  let data = text.data(using: .utf8),
                  let root = try? JSONSerialization.jsonObject(with: data) else { return [] }
            var found: [[String: Any]] = []
            func walk(_ any: Any, depth: Int) {
                guard depth < 5 else { return }
                if let arr = any as? [[String: Any]] {
                    if arr.count > found.count,
                       let first = arr.first,
                       (first["id"] != nil || first["pid"] != nil),
                       first["name"] != nil,
                       first["musiclist"] == nil {
                        found = arr
                    }
                    for item in arr { walk(item, depth: depth + 1) }
                } else if let dict = any as? [String: Any] {
                    for (_, value) in dict { walk(value, depth: depth + 1) }
                }
            }
            walk(root, depth: 0)
            return found.compactMap { raw in
                let pid = KuwoMusicAPI.intPublic(raw["id"] ?? raw["pid"] ?? raw["playlistId"])
                let name = KuwoMusicAPI.stringPublic(raw["name"] ?? raw["title"])
                guard let pid, pid > 0, !name.isEmpty else { return nil }
                let pic = KuwoMusicAPI.stringPublic(raw["img"] ?? raw["pic"] ?? raw["cover"])
                let count = KuwoMusicAPI.intPublic(raw["total"] ?? raw["songCount"] ?? raw["musicNum"]) ?? 0
                return Playlist(
                    id: pid,
                    name: name,
                    coverURL: URL(string: pic.hasPrefix("http") ? pic : ""),
                    trackCount: count,
                    source: .kuwo,
                    externalID: "\(pid)"
                )
            }
        }

        /// DOM 抓取结果（JSON 字符串）转歌单
        static func parseScraped(_ result: Any?) -> [Playlist] {
            guard let text = result as? String,
                  let data = text.data(using: .utf8),
                  let raw = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                return []
            }
            return raw.compactMap { item in
                guard let id = KuwoMusicAPI.intPublic(item["id"]), id > 0 else { return nil }
                let name = KuwoMusicAPI.stringPublic(item["name"])
                guard !name.isEmpty else { return nil }
                let cover = KuwoMusicAPI.stringPublic(item["cover"])
                return Playlist(id: id, name: name,
                                coverURL: cover.hasPrefix("http") ? URL(string: cover) : nil,
                                trackCount: 0, source: .kuwo, externalID: "\(id)")
            }
        }

        private static let scrapeJS = #"""
        (function(){
          var out=[],seen={};
          document.querySelectorAll('a[href*="playlist_detail"], a[href*="/playlist/"]').forEach(function(a){
            var m=(a.href||'').match(/(?:playlist_detail\/|\/playlist\/)(\d+)/);
            if(!m) return;
            var id=m[1];
            if(seen[id]) return;
            seen[id]=1;
            var img=a.querySelector('img');
            var name=(a.innerText||a.textContent||'').replace(/\s+/g,' ').trim();
            if(!name) name=(a.getAttribute('title')||'').trim();
            if(!name) return;
            out.push({id:id,name:name.slice(0,60),cover:img?img.src:''});
          });
          return JSON.stringify(out);
        })()
        """#

        /// 桌面版首页的「登录 / 注册」入口（div.reg_text），点开后是手机号快捷登录 /
        /// 账号密码 / 微信 / QQ。登录成功后该节点会被昵称替换，可据此判断状态。
        static let openLoginPanelJS = """
        (function(){
          var n = 0;
          var t = setInterval(function(){
            var el = document.querySelector('div.reg_text');
            if (el && el.innerText && el.innerText.indexOf('登录') >= 0) {
              el.click();
              clearInterval(t);
            }
            if (++n > 80) { clearInterval(t); }
          }, 250);
          return 'ok';
        })()
        """
    }
}

// MARK: - Cookie 验证

/// 酷我网页版 UA：登录页必须用桌面版，移动版站点没有登录入口。
enum KuwoWebUserAgent {
    static let desktop = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
}

/// 用一份 Cookie 实际打开酷我首页，确认页面不再是「登录 / 注册」。
/// 用 nonPersistent 数据仓，验证失败不会污染 App 里已经登录的 Cookie。
final class KuwoCookieValidator: NSObject, WKNavigationDelegate {
    static let shared = KuwoCookieValidator()

    private var webView: WKWebView?
    private var completion: ((Bool) -> Void)?
    private var timeout: DispatchWorkItem?

    func validate(cookieHeader: String, completion: @escaping (Bool) -> Void) {
        DispatchQueue.main.async {
            self.cancelCurrent()
            let pairs = Self.parse(cookieHeader)
            guard !pairs.isEmpty else {
                completion(false)
                return
            }
            let store = WKWebsiteDataStore.nonPersistent()
            let group = DispatchGroup()
            for (name, value) in pairs {
                let properties: [HTTPCookiePropertyKey: Any] = [
                    .name: name,
                    .value: value,
                    .domain: ".kuwo.cn",
                    .path: "/",
                    .secure: "TRUE",
                    .expires: Date().addingTimeInterval(60 * 60 * 24 * 30)
                ]
                guard let cookie = HTTPCookie(properties: properties) else { continue }
                group.enter()
                store.httpCookieStore.setCookie(cookie) { group.leave() }
            }
            group.notify(queue: .main) {
                let config = WKWebViewConfiguration()
                config.websiteDataStore = store
                let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 780), configuration: config)
                webView.customUserAgent = KuwoWebUserAgent.desktop
                webView.navigationDelegate = self
                self.webView = webView
                self.completion = completion
                let work = DispatchWorkItem { [weak self] in self?.finish(false) }
                self.timeout = work
                DispatchQueue.main.asyncAfter(deadline: .now() + 18, execute: work)
                webView.load(URLRequest(url: URL(string: "https://www.kuwo.cn/")!))
            }
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard completion != nil else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self, weak webView] in
            guard let self, let webView, self.completion != nil else { return }
            webView.evaluateJavaScript(Self.checkJS) { result, _ in
                let noLoginEntry = (result as? String) == "1"
                webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
                    let hasUserID = cookies.contains {
                        $0.domain.contains("kuwo.cn")
                            && ($0.name == "userid" || $0.name == "uid")
                            && !$0.value.isEmpty
                    }
                    DispatchQueue.main.async {
                        self.finish(noLoginEntry && hasUserID)
                    }
                }
            }
        }
    }

    private func finish(_ ok: Bool) {
        timeout?.cancel()
        timeout = nil
        let callback = completion
        completion = nil
        webView?.stopLoading()
        webView?.navigationDelegate = nil
        webView = nil
        DispatchQueue.main.async {
            callback?(ok)
        }
    }

    private func cancelCurrent() {
        timeout?.cancel()
        timeout = nil
        let callback = completion
        completion = nil
        webView?.stopLoading()
        webView?.navigationDelegate = nil
        webView = nil
        // 上一次验证还没回调就结束的话，通知调用方失败，避免界面卡在「正在验证…」
        if let callback {
            DispatchQueue.main.async { callback(false) }
        }
    }

    private static func parse(_ header: String) -> [(String, String)] {
        header.split(separator: ";").compactMap { part in
            let trimmed = part.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let eq = trimmed.firstIndex(of: "=") else { return nil }
            let name = String(trimmed[trimmed.startIndex..<eq]).trimmingCharacters(in: .whitespaces)
            let value = String(trimmed[trimmed.index(after: eq)...]).trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty, !value.isEmpty else { return nil }
            return (name, value)
        }
    }

    /// 1 = 页面上没有「登录 / 注册」入口（已登录）
    private static let checkJS = """
    (function(){
      try {
        var reg = document.querySelector('div.reg_text');
        var text = (document.body && document.body.innerText || '').length;
        return (!reg && text > 50) ? '1' : '0';
      } catch(e) { return '0'; }
    })()
    """
}
