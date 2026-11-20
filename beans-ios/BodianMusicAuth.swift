import Foundation

/// 波点音乐登录态。波点没有网页登录，只能扫码；登录后靠 uid + token 访问账号相关接口。
final class BodianMusicAuth: ObservableObject {
    static let shared = BodianMusicAuth()

    @Published private(set) var isLoggedIn = false
    @Published private(set) var uid = ""
    @Published private(set) var nickname = ""
    @Published private(set) var avatarURL: URL?

    private let defaults = UserDefaults.standard
    private let key = "beans.bodian.auth.v1"
    private let deviceKey = "beans.bodian.deviceId"
    private var auth: [String: String] = [:]

    private init() {
        if let saved = defaults.dictionary(forKey: key) as? [String: String] {
            auth = saved
        }
        applyState()
        _ = deviceId
    }

    var token: String { auth["token"] ?? "" }

    /// 波点会员标识：扫码登录返回里没有稳定的会员字段，暂不展示角标
    var vipBadge: String? { nil }

    /// 波点要求稳定的 32 位小写十六进制设备号，删掉就等于换了新设备。
    var deviceId: String {
        if let saved = defaults.string(forKey: deviceKey),
           saved.count == 32,
           saved.allSatisfy({ $0.isHexDigit }) {
            return saved.lowercased()
        }
        let hex = "0123456789abcdef"
        var value = ""
        for _ in 0..<32 {
            value.append(hex.randomElement() ?? "0")
        }
        defaults.set(value, forKey: deviceKey)
        return value
    }

    func saveLogin(uid: String, token: String, nickname: String, avatar: String) {
        var next = auth
        next["uid"] = uid
        next["token"] = token
        next["nickname"] = nickname
        next["avatar"] = avatar
        auth = next
        defaults.set(next, forKey: key)
        applyState()
        NotificationCenter.default.post(name: .beansBodianLoginDidUpdate, object: nil)
    }

    func logout() {
        auth = [:]
        defaults.removeObject(forKey: key)
        applyState()
        NotificationCenter.default.post(name: .beansBodianLoginDidUpdate, object: nil)
    }

    private func applyState() {
        let nextUID = (auth["uid"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let nextToken = auth["token"] ?? ""
        let nextNick = auth["nickname"] ?? ""
        let nextAvatar = URL(string: auth["avatar"] ?? "")
        let nextLoggedIn = !nextUID.isEmpty && !nextToken.isEmpty
        if uid != nextUID { uid = nextUID }
        if isLoggedIn != nextLoggedIn { isLoggedIn = nextLoggedIn }
        if nickname != nextNick { nickname = nextNick }
        if avatarURL != nextAvatar { avatarURL = nextAvatar }
    }
}
