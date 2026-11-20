import Foundation

/// 收藏的「歌单广场」歌单。
/// 主页「我的歌单」板块与歌单广场的收藏状态都以这里为准。
final class FavoritePlaylistStore: ObservableObject {
    static let shared = FavoritePlaylistStore()

    @Published private(set) var playlists: [Playlist] = []

    private let defaults = UserDefaults.standard
    private let key = "beans.favoritePlaylists.v1"

    private init() {
        load()
    }

    func contains(_ playlist: Playlist) -> Bool {
        playlists.contains { isSame($0, playlist) }
    }

    /// 数字 id 在不同平台会撞车，波点歌单 id 还是哈希出来的，必须用 uniqueKey 兜一层
    private func isSame(_ lhs: Playlist, _ rhs: Playlist) -> Bool {
        lhs.uniqueKey == rhs.uniqueKey || (lhs.id == rhs.id && lhs.source == rhs.source)
    }

    /// 返回操作后的收藏状态
    @discardableResult
    func toggle(_ playlist: Playlist) -> Bool {
        if contains(playlist) {
            playlists.removeAll { isSame($0, playlist) }
            save()
            return false
        }
        playlists.insert(playlist, at: 0)
        save()
        return true
    }

    func remove(at offsets: IndexSet) {
        playlists.remove(atOffsets: offsets)
        save()
    }

    func remove(id: Int, source: SongSource) {
        playlists.removeAll { $0.id == id && $0.source == source }
        save()
    }

    private func load() {
        guard let data = defaults.data(forKey: key),
              let list = try? JSONDecoder().decode([Playlist].self, from: data) else { return }
        playlists = list
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(playlists) else { return }
        defaults.set(data, forKey: key)
    }
}
