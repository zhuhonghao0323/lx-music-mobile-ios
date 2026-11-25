import Foundation

/// 汽水音乐登录态。
///
/// 汽水没有可直接调用的开放登录接口：Passport 扫码要求官方 `bdms.js` 在 WebKit 里为同源
/// 请求生成 `a_bogus`（参考实现 Coda 用非持久化 WKWebView 承载），云端环境无法验收，
/// 所以这里先接「粘贴网页 Cookie」：Cookie 只保存在本机，不上传任何第三方。
///
/// 需要的字段至少包含 `sessionid`（或 `sessionid_ss`）；其余 `sid_guard`、`uid_tt`
/// 由服务端下发，一并原样保存。
final class QishuiMusicAuth: ObservableObject {
    static let shared = QishuiMusicAuth()

    @Published private(set) var isLoggedIn = false
    @Published private(set) var userId = ""
    @Published private(set) var nickname = ""
    @Published private(set) var avatarURL: URL?
    /// 汽水会员角标（接口返回 vip / 会员到期时展示），拿不到就是 nil
    @Published private(set) var vipBadge: String?

    private let defaults = UserDefaults.standard
    private let key = "beans.qishui.auth.v1"
    private var auth: [String: String] = [:]

    private init() {
        if let saved = defaults.dictionary(forKey: key) as? [String: String] {
            auth = saved
        }
        applyState()
    }

    /// 原始 Cookie 串，请求时原样放进 `Cookie` 头
    var cookieHeader: String { auth["cookie"] ?? "" }

    func cookieValue(_ name: String) -> String {
        Self.parseCookie(cookieHeader)[name] ?? ""
    }

    /// 汽水多数接口只认 `sessionid` / `sessionid_ss` 之一
    func hasSession() -> Bool {
        !cookieValue("sessionid").isEmpty || !cookieValue("sessionid_ss").isEmpty
    }

    func saveCookie(
        _ raw: String,
        userId: String = "",
        nickname: String = "",
        avatar: String = "",
        vip: String? = nil
    ) {
        let cookie = Self.normalize(raw)
        guard !cookie.isEmpty else { return }
        var next = auth
        next["cookie"] = cookie
        if !userId.isEmpty { next["uid"] = userId }
        if !nickname.isEmpty { next["nickname"] = nickname }
        if !avatar.isEmpty { next["avatar"] = avatar }
        if let vip { next["vip"] = vip }
        // Cookie 里自带的 uid 优先补进来，方便在账号页显示
        let parsed = Self.parseCookie(cookie)
        if (next["uid"] ?? "").isEmpty {
            let uid = parsed["uid_tt"] ?? parsed["uid_tt_ss"] ?? parsed["user_id"] ?? ""
            if !uid.isEmpty { next["uid"] = uid }
        }
        auth = next
        defaults.set(next, forKey: key)
        applyState()
        NotificationCenter.default.post(name: .beansQishuiLoginDidUpdate, object: nil)
    }

    func updateProfile(nickname: String, avatar: String, userId: String, vip: String?) {
        var next = auth
        if !nickname.isEmpty { next["nickname"] = nickname }
        if !avatar.isEmpty { next["avatar"] = avatar }
        if !userId.isEmpty { next["uid"] = userId }
        if let vip { next["vip"] = vip }
        guard next != auth else { return }
        auth = next
        defaults.set(next, forKey: key)
        applyState()
    }

    func logout() {
        auth = [:]
        defaults.removeObject(forKey: key)
        applyState()
        NotificationCenter.default.post(name: .beansQishuiLoginDidUpdate, object: nil)
    }

    private func applyState() {
        let nextLoggedIn = hasSession()
        let nextUID = (auth["uid"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let nextNick = (auth["nickname"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let nextAvatar = URL(string: auth["avatar"] ?? "")
        let vipText = (auth["vip"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let nextVip: String? = vipText.isEmpty ? nil : vipText
        if isLoggedIn != nextLoggedIn { isLoggedIn = nextLoggedIn }
        if userId != nextUID { userId = nextUID }
        if nickname != nextNick { nickname = nextNick }
        if avatarURL != nextAvatar { avatarURL = nextAvatar }
        if vipBadge != nextVip { vipBadge = nextVip }
    }

    /// 去掉换行、补分号，避免用户从 F12 复制时带上 `Cookie:` 前缀
    static func normalize(_ raw: String) -> String {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.lowercased().hasPrefix("cookie:") {
            text = String(text.dropFirst("cookie:".count))
        }
        text = text.replacingOccurrences(of: "\r", with: "")
        text = text.replacingOccurrences(of: "\n", with: "; ")
        return text.trimmingCharacters(in: CharacterSet(charactersIn: " ;"))
    }

    static func parseCookie(_ raw: String) -> [String: String] {
        var result: [String: String] = [:]
        for part in normalize(raw).split(separator: ";") {
            let pieces = part.split(separator: "=", maxSplits: 1)
            guard pieces.count == 2 else { continue }
            let name = pieces[0].trimmingCharacters(in: .whitespaces)
            var value = pieces[1].trimmingCharacters(in: .whitespaces)
            if value.hasPrefix("\""), value.hasSuffix("\""), value.count >= 2 {
                value = String(value.dropFirst().dropLast())
            }
            guard !name.isEmpty, !value.isEmpty else { continue }
            result[name] = value
        }
        return result
    }
}
