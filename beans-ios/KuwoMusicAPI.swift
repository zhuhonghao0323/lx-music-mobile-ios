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
        let json = try await requestJSON(url, headers: [
            "User-Agent": webUA,
            "Referer": "https://www.kuwo.cn/",
            "Cookie": cookie,
            "Secret": secret
        ])
        if let success = json["success"] as? Bool, !success {
            throw KuwoError.invalid(Self.string(json["message"]).isEmpty ? "酷我歌单接口暂不可用，可在下方手动粘贴歌单链接" : Self.string(json["message"]))
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
        var n = digits + String(Int.random(in: 0...99_999_999))
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
        return out
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
    @State private var manualLink = ""
    @State private var manualCookie = ""
    @State private var showManualCookie = false
    @State private var imported: [Playlist] = []

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

            KuwoLoginWebView { cookie, uid, playlists in
                guard !uid.isEmpty else { return }
                auth.saveLogin(cookie: cookie, uid: uid, nickname: auth.nickname.isEmpty ? "酷我用户" : auth.nickname)
                if !playlists.isEmpty {
                    auth.savePlaylists(playlists)
                    status = "已登录，读到 \(playlists.count) 个歌单"
                } else {
                    status = "已登录，正在读取歌单…"
                }
                Task { await refreshPlaylists() }
            }
            .frame(height: 420)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

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
                    Button("保存 Cookie") {
                        let parsedUID = Self.uid(from: manualCookie)
                        guard !parsedUID.isEmpty else {
                            status = "Cookie 里没有 userid，请确认复制完整"
                            return
                        }
                        auth.saveLogin(cookie: manualCookie, uid: parsedUID, nickname: "酷我用户")
                        status = "Cookie 已保存，正在读取歌单…"
                        Task { await refreshPlaylists() }
                    }
                    .font(BeansFont.appFont(12, .semibold))
                    .foregroundStyle(Color.beansAmber)
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
    let onLogin: (String, String, [Playlist]) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onLogin: onLogin) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        let controller = WKUserContentController()
        controller.add(context.coordinator, name: "kuwoLogin")
        config.userContentController = controller

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
        webView.load(URLRequest(url: URL(string: "https://www.kuwo.cn/")!))
        context.coordinator.start(webView: webView)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        coordinator.stop()
        uiView.configuration.userContentController.removeScriptMessageHandler(forName: "kuwoLogin")
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        private let onLogin: (String, String, [Playlist]) -> Void
        private weak var webView: WKWebView?
        private var timer: Timer?
        private var reported = false
        private var delivered = false

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

        private func probeCookies() {
            guard !reported, let webView else { return }
            webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { [weak self] cookies in
                guard let self, !self.reported else { return }
                let kuwo = cookies.filter { $0.domain.contains("kuwo.cn") }
                guard !kuwo.isEmpty else { return }
                let header = kuwo.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
                let uid = kuwo.first { $0.name == "userid" || $0.name == "uid" }?.value ?? ""
                guard !uid.isEmpty else { return }
                self.reported = true
                // 登录成功后进入「我的歌单」页，直接从页面抓歌单卡片：
                // 网页接口有风控与签名，DOM 是最稳的兜底；抓不到再让用户手动粘贴链接。
                DispatchQueue.main.async {
                    self.loadMyPlaylists(cookie: header, uid: uid)
                }
            }
        }

        private func loadMyPlaylists(cookie: String, uid: String) {
            guard let webView else {
                deliver(cookie: cookie, uid: uid, list: [])
                return
            }
            guard let url = URL(string: "https://www.kuwo.cn/my/playlist") else {
                deliver(cookie: cookie, uid: uid, list: [])
                return
            }
            webView.load(URLRequest(url: url))
            let delays: [Double] = [2.5, 4.5, 7.0]
            for delay in delays {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self, weak webView] in
                    guard let self, let webView else { return }
                    webView.evaluateJavaScript(Self.scrapeJS) { result, _ in
                        let list = Self.playlists(from: result)
                        guard !list.isEmpty else { return }
                        self.deliver(cookie: cookie, uid: uid, list: list)
                    }
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 7.5) {
                self.deliver(cookie: cookie, uid: uid, list: [], final: true)
            }
        }

        /// 第一次拿到非空歌单就交付；空列表只在最后兜底交付，避免重复发通知
        private func deliver(cookie: String, uid: String, list: [Playlist], final: Bool = false) {
            guard !delivered else { return }
            if list.isEmpty && !final { return }
            delivered = true
            onLogin(cookie, uid, list)
        }

        private static let scrapeJS = #"""
        (function(){
          var out=[],seen={};
          document.querySelectorAll('a[href*="playlist_detail"]').forEach(function(a){
            var m=(a.href||'').match(/playlist_detail\/(\d+)/);
            if(!m) return;
            var id=m[1];
            if(seen[id]) return;
            seen[id]=1;
            var img=a.querySelector('img');
            var name=(a.innerText||a.textContent||'').replace(/\s+/g,' ').trim();
            if(!name) name=(a.getAttribute('title')||'').trim();
            out.push({id:id,name:name.slice(0,60),cover:img?img.src:''});
          });
          return JSON.stringify(out);
        })()
        """#

        private static func playlists(from result: Any?) -> [Playlist] {
            guard let text = result as? String,
                  let data = text.data(using: .utf8),
                  let raw = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                return []
            }
            return raw.compactMap { item in
                guard let id = Int(String(describing: item["id"] ?? "")), id > 0 else { return nil }
                let name = item["name"] as? String ?? ""
                guard !name.isEmpty else { return nil }
                let cover = item["cover"] as? String ?? ""
                return Playlist(id: id, name: name,
                                coverURL: cover.hasPrefix("http") ? URL(string: cover) : nil,
                                trackCount: 0, source: .kuwo, externalID: "\(id)")
            }
        }
    }
}
