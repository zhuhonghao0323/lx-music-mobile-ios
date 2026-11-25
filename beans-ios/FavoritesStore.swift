import Foundation

/// 收藏管理（红心）：网易云登录后同步到网易云云端；QQ 本地持久化，
/// 登录 QQ 时尽力同步到 QQ 云端（music.srfDissong），失败不影响本地收藏。
final class FavoritesStore: ObservableObject {
    static let shared = FavoritesStore()

    /// QQ 红心收藏（本地持久化，供音乐库展示）
    @Published private(set) var qqFavoriteSongs: [Song] = []
    /// 网易云红心收藏（本地缓存 + 云端同步）
    @Published private(set) var neteaseFavoriteSongs: [Song] = []
    /// 酷狗红心收藏（本地持久化，酷狗暂无稳定云端红心写入接口）
    @Published private(set) var kugouFavoriteSongs: [Song] = []
    /// 咪咕红心收藏（咪咕无账号体系，仅本地持久化）
    @Published private(set) var miguFavoriteSongs: [Song] = []
    /// 波点红心收藏（本地持久化；波点的红心歌单写入接口未验证，先不入云端）
    @Published private(set) var bodianFavoriteSongs: [Song] = []
    /// 酷我红心收藏（本地持久化；酷我网页红心接口未公开）
    @Published private(set) var kuwoFavoriteSongs: [Song] = []
    /// 汽水红心收藏（本地持久化；写入汽水云端需要签名服务，先不入云）
    @Published private(set) var qishuiFavoriteSongs: [Song] = []

    private let defaults = UserDefaults.standard
    private let neteaseKey = "beans.fav.netease.v1"
    private let qqKey = "beans.fav.qq.v1"
    private let kugouKey = "beans.fav.kugou.v1"
    private let miguKey = "beans.fav.migu.v1"
    private let bodianKey = "beans.fav.bodian.v1"
    private let kuwoKey = "beans.fav.kuwo.v1"
    private let qishuiKey = "beans.fav.qishui.v1"

    private init() {
        qqFavoriteSongs = Self.loadSongs(qqKey)
        neteaseFavoriteSongs = Self.loadSongs(neteaseKey)
        kugouFavoriteSongs = Self.loadSongs(kugouKey)
        miguFavoriteSongs = Self.loadSongs(miguKey)
        bodianFavoriteSongs = Self.loadSongs(bodianKey)
        kuwoFavoriteSongs = Self.loadSongs(kuwoKey)
        qishuiFavoriteSongs = Self.loadSongs(qishuiKey)
    }

    /// 该歌曲是否已收藏
    func isLiked(_ song: Song?) -> Bool {
        guard let song else { return false }
        switch song.source {
        case .netease:
            return neteaseFavoriteSongs.contains { $0.id == song.id }
        case .qq:
            if let mid = song.qqMid, !mid.isEmpty {
                return qqFavoriteSongs.contains { $0.qqMid == mid || $0.identityKey == song.identityKey }
            }
            return qqFavoriteSongs.contains { $0.identityKey == song.identityKey }
        case .kugou:
            return kugouFavoriteSongs.contains { $0.identityKey == song.identityKey }
        case .migu:
            return miguFavoriteSongs.contains { $0.identityKey == song.identityKey }
        case .bodian:
            return bodianFavoriteSongs.contains { $0.identityKey == song.identityKey }
        case .kuwo:
            return kuwoFavoriteSongs.contains { $0.identityKey == song.identityKey }
        case .qishui:
            return qishuiFavoriteSongs.contains { $0.identityKey == song.identityKey }
        }
    }

    /// 切换收藏状态；返回是否成功（云端同步失败时网易云会回滚）
    @discardableResult
    func toggle(_ song: Song) async -> Bool {
        switch song.source {
        case .netease:
            let liked = !isLiked(song)
            updateNetease(song, liked: liked)
            do {
                let ok = try await NetEaseAPI.shared.like(id: song.id, liked: liked)
                if !ok {
                    updateNetease(song, liked: !liked)
                    return false
                }
                return true
            } catch {
                updateNetease(song, liked: !liked)
                return false
            }
        case .qq:
            let liked = !isLiked(song)
            updateQQ(song, liked: liked)
            guard let mid = song.qqMid, !mid.isEmpty else {
                BeansLogger.shared.log("QQ 红心缺少 songmid，已保留本地收藏：\(song.name) liked=\(liked)", level: .warn)
                return true
            }
            if QQMusicAuth.shared.isLoggedIn {
                let ok = (try? await QQMusicAPI.shared.like(songmid: mid, liked: liked)) ?? false
                if !ok {
                    BeansLogger.shared.log("QQ 红心云端同步失败，已保留本地收藏：\(song.name) liked=\(liked)", level: .warn)
                }
            }
            return true
        case .kugou:
            let liked = !isLiked(song)
            updateKugou(song, liked: liked)
            return true
        case .migu:
            let liked = !isLiked(song)
            updateMigu(song, liked: liked)
            return true
        case .bodian:
            let liked = !isLiked(song)
            updateBodian(song, liked: liked)
            return true
        case .kuwo:
            let liked = !isLiked(song)
            updateKuwo(song, liked: liked)
            return true
        case .qishui:
            let liked = !isLiked(song)
            updateQishui(song, liked: liked)
            return true
        }
    }

    /// 移除 QQ 收藏（音乐库侧滑删除）
    func removeQQFavorite(_ song: Song) {
        updateQQ(song, liked: false)
    }

    /// 登录 QQ / 微信后从 QQ 音乐云端同步“我的喜欢”。
    /// 只有云端明确返回歌曲时才覆盖本地，避免接口空响应误清空收藏。
    @MainActor
    func syncQQFromCloud() async {
        guard QQMusicAuth.shared.isLoggedIn else { return }
        guard let songs = try? await QQMusicAPI.shared.favoriteSongs(), !songs.isEmpty else { return }
        qqFavoriteSongs = songs
        saveSongs(qqFavoriteSongs, key: qqKey)
    }

    /// 登录波点后从云端同步「我喜欢」。只有云端明确返回歌曲时才覆盖本地，避免空响应误清空。
    @MainActor
    func syncBodianFromCloud() async {
        guard BodianMusicAuth.shared.isLoggedIn else { return }
        guard let songs = try? await BodianMusicAPI.shared.likedSongs(), !songs.isEmpty else { return }
        bodianFavoriteSongs = songs
        saveSongs(bodianFavoriteSongs, key: bodianKey)
    }

    private func updateNetease(_ song: Song, liked: Bool) {
        if liked {
            neteaseFavoriteSongs.removeAll { $0.id == song.id }
            neteaseFavoriteSongs.insert(song, at: 0)
        } else {
            neteaseFavoriteSongs.removeAll { $0.id == song.id }
        }
        saveSongs(neteaseFavoriteSongs, key: neteaseKey)
    }

    private func updateQQ(_ song: Song, liked: Bool) {
        if liked {
            qqFavoriteSongs.removeAll { existing in
                existing.identityKey == song.identityKey
                    || (existing.qqMid != nil && song.qqMid != nil && existing.qqMid == song.qqMid)
            }
            qqFavoriteSongs.insert(song, at: 0)
        } else {
            qqFavoriteSongs.removeAll { existing in
                existing.identityKey == song.identityKey
                    || (existing.qqMid != nil && song.qqMid != nil && existing.qqMid == song.qqMid)
            }
        }
        saveSongs(qqFavoriteSongs, key: qqKey)
    }

    private func updateKugou(_ song: Song, liked: Bool) {
        if liked {
            kugouFavoriteSongs.removeAll { $0.identityKey == song.identityKey }
            kugouFavoriteSongs.insert(song, at: 0)
        } else {
            kugouFavoriteSongs.removeAll { $0.identityKey == song.identityKey }
        }
        saveSongs(kugouFavoriteSongs, key: kugouKey)
    }

    private func updateMigu(_ song: Song, liked: Bool) {
        if liked {
            miguFavoriteSongs.removeAll { $0.identityKey == song.identityKey }
            miguFavoriteSongs.insert(song, at: 0)
        } else {
            miguFavoriteSongs.removeAll { $0.identityKey == song.identityKey }
        }
        saveSongs(miguFavoriteSongs, key: miguKey)
    }

    private func updateKuwo(_ song: Song, liked: Bool) {
        if liked {
            kuwoFavoriteSongs.removeAll { $0.identityKey == song.identityKey }
            kuwoFavoriteSongs.insert(song, at: 0)
        } else {
            kuwoFavoriteSongs.removeAll { $0.identityKey == song.identityKey }
        }
        saveSongs(kuwoFavoriteSongs, key: kuwoKey)
    }

    private func updateQishui(_ song: Song, liked: Bool) {
        if liked {
            qishuiFavoriteSongs.removeAll { $0.identityKey == song.identityKey }
            qishuiFavoriteSongs.insert(song, at: 0)
        } else {
            qishuiFavoriteSongs.removeAll { $0.identityKey == song.identityKey }
        }
        saveSongs(qishuiFavoriteSongs, key: qishuiKey)
    }

    private func updateBodian(_ song: Song, liked: Bool) {
        if liked {
            bodianFavoriteSongs.removeAll { $0.identityKey == song.identityKey }
            bodianFavoriteSongs.insert(song, at: 0)
        } else {
            bodianFavoriteSongs.removeAll { $0.identityKey == song.identityKey }
        }
        saveSongs(bodianFavoriteSongs, key: bodianKey)
    }

    private static func loadSongs(_ key: String) -> [Song] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let saved = try? JSONDecoder().decode([Song].self, from: data) else { return [] }
        return saved
    }

    private func saveSongs(_ songs: [Song], key: String) {
        if let data = try? JSONEncoder().encode(songs) {
            defaults.set(data, forKey: key)
        }
    }

    /// 退出网易云登录时清空本地网易云收藏缓存（保留 QQ 收藏）
    func resetNetease() {
        neteaseFavoriteSongs = []
        defaults.removeObject(forKey: neteaseKey)
    }
}
