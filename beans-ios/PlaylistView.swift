import SwiftUI

/// 歌单内排序方式
enum PlaylistSortMode: String, CaseIterable, Identifiable {
    case original = "默认"
    case name = "歌名"
    case duration = "时长"
    var id: String { rawValue }
}

struct PlaylistView: View {
    @EnvironmentObject private var player: PlayerManager
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var theme: ThemeStore
    @ObservedObject private var favorites = FavoritesStore.shared
    @ObservedObject private var importedStore = ImportedPlaylistStore.shared

    let playlist: Playlist
    @State private var tracks: [Song] = []
    @State private var loading = true
    @State private var errorMessage: String?
    @State private var searchText = ""
    @State private var sortMode: PlaylistSortMode = .original
    @State private var updatingImported = false
    @State private var showCopyToLocal = false
    @AppStorage("beans.homeHeaderHideSort") private var hideSortButton = false
    @AppStorage("beans.uiStyle") private var uiStyleRaw = BeansUIStyle.liquid.rawValue

    /// 导入歌单：歌曲存在本机，详情页直接用本地副本
    private var importedEntry: ImportedPlaylist? {
        importedStore.item(for: playlist)
    }

    private var isNativeClean: Bool {
        BeansUIStyle(rawValue: uiStyleRaw) == .nativeClean
    }

    private var cacheAccountID: String {
        switch playlist.source {
        case .netease:
            return "\(auth.user?.uid ?? 0)"
        case .qq:
            let qqAuth = QQMusicAuth.shared
            return qqAuth.rawUin.isEmpty ? qqAuth.playlistUin : qqAuth.rawUin
        case .kugou:
            return KugouMusicAuth.shared.userId
        case .migu:
            // 咪咕无账号体系，歌单缓存不按账号区分
            return "migu"
        case .bodian:
            // 波点按当前登录账号隔离缓存，未登录用固定值
            let bodianAuth = BodianMusicAuth.shared
            return bodianAuth.isLoggedIn ? bodianAuth.uid : "bodian-guest"
        case .kuwo:
            // 酷我按当前登录账号隔离缓存，未登录用固定值
            let kuwoAuth = KuwoMusicAuth.shared
            return kuwoAuth.isLoggedIn ? kuwoAuth.uid : "kuwo-guest"
        case .qishui:
            // 汽水按当前登录账号隔离缓存，未登录用固定值（与音乐库共用同一个 key）
            return QishuiMusicAuth.shared.cacheAccountID
        }
    }

    var body: some View {
        let _ = theme.accent
        ZStack {
                GlassBackdrop(customColor: theme.backgroundSyncAll ? theme.customBackground : nil)
                Group {
                if loading {
                    LoadingStateView()
                } else if let errorMessage {
                    ErrorStateView(message: errorMessage) {
                        Task { await load(force: true) }
                    }
                } else {
                    List {
                        header
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        Section {
                            ForEach(Array(displayedTracks.enumerated()), id: \.element.identityKey) { index, song in
                                SongCell(song: song, glassRow: true, playbackContext: displayedTracks, playbackIndex: index) {
                                    player.play(songs: displayedTracks, startAt: index)
                                }
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                            }
                        }
                    }
                    .beansScrollContentBackgroundHidden()
                    .listStyle(.plain)
                }
            }
            }
            .navigationTitle(playlist.name)
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showCopyToLocal) {
                CopyToLocalPlaylistSheet(songs: displayedTracks, suggestedName: playlist.name)
                    .environmentObject(theme)
            }
        .task { await load() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: isNativeClean ? 18 : 14) {
                CoverImage(url: playlist.coverURL, size: 96, cornerRadius: 18)
                VStack(alignment: .leading, spacing: 6) {
                    Text(playlist.name)
                        .font(BeansFont.appFont(18, .bold))
                        .foregroundStyle(Color.beansLabel)
                        .lineLimit(2)
                    if !playlist.creatorName.isEmpty {
                        Text(playlist.creatorName)
                            .font(BeansFont.appFont(12))
                            .foregroundStyle(Color.beansComment)
                    }
                    Text(beansSongCountText(tracks.count))
                        .font(BeansFont.appFont(12))
                        .foregroundStyle(Color.beansComment)
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 10) {
                GlassButton(title: "播放全部", systemName: "play.fill", prominent: true) {
                    player.play(songs: displayedTracks, startAt: 0)
                }
                GlassButton(title: "随机播放", systemName: "shuffle") {
                    if !displayedTracks.isEmpty {
                        player.play(songs: displayedTracks, startAt: Int.random(in: 0..<displayedTracks.count))
                    }
                }
            }
            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.beansComment)
                    TextField(beansLocalized("搜索歌单内歌曲", "Search songs in playlist"), text: $searchText)
                        .font(BeansFont.appFont(14))
                        .autocorrectionDisabled()
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(Color.beansComment)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background { BeansSurface(shape: RoundedRectangle(cornerRadius: 14, style: .continuous)) }

                // 保存到本地：把云端/第三方歌单复制到本地歌单，可自由增删歌曲
                Button {
                    BeansHaptics.tap()
                    showCopyToLocal = true
                } label: {
                    Image(systemName: "square.and.arrow.down.on.square")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.beansAmber)
                        .frame(width: 38, height: 38)
                        .background { BeansSurface(shape: Circle()) }
                }
                .buttonStyle(GlassPressButtonStyle())
                .accessibilityLabel("保存到本地歌单")

                if importedEntry != nil {
                    Button {
                        BeansHaptics.tap()
                        guard let entry = importedEntry else { return }
                        Task { await refreshImportedEntry(entry) }
                    } label: {
                        Group {
                            if updatingImported {
                                ProgressView().scaleEffect(0.8)
                            } else {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Color.beansAmber)
                            }
                        }
                        .frame(width: 38, height: 38)
                        .background { BeansSurface(shape: Circle()) }
                    }
                    .buttonStyle(GlassPressButtonStyle())
                    .disabled(updatingImported)
                    .accessibilityLabel("更新歌单")
                }

                if !hideSortButton {
                    Menu {
                        Picker("排序", selection: $sortMode) {
                            ForEach(PlaylistSortMode.allCases) { mode in
                                Text(LocalizedStringKey(mode.rawValue)).tag(mode)
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.beansAmber)
                            .frame(width: 38, height: 38)
                            .background { BeansSurface(shape: Circle()) }
                    }
                    .buttonStyle(GlassPressButtonStyle())
                }
            }
        }
        .padding(14)
        .background { BeansSurface(shape: RoundedRectangle(cornerRadius: 24, style: .continuous)) }
    }

    /// 歌单内搜索 + 排序后的列表
    private var displayedTracks: [Song] {
        var list = tracks
        let kw = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !kw.isEmpty {
            list = list.filter { song in
                song.name.lowercased().contains(kw)
                    || song.artists.lowercased().contains(kw)
                    || song.album.lowercased().contains(kw)
            }
        }
        switch sortMode {
        case .original: break
        case .name:
            list.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        case .duration:
            list.sort { $0.duration < $1.duration }
        }
        return list
    }

    private func load(force: Bool = false) async {
        // 导入歌单：歌曲已存在本机，直接读本地副本（秒开、离线可看），
        // 需要拿平台最新内容时走「更新」，不在这里重复请求接口。
        if let entry = importedEntry {
            tracks = entry.songs
            loading = false
            errorMessage = nil
            if force { await refreshImportedEntry(entry) }
            return
        }
        let cache = SyncedPlaylistCache.shared
        if let cached = cache.cachedSongs(playlist: playlist, accountID: cacheAccountID) {
            tracks = cached.songs
            loading = false
            if !force, cache.isFresh(cached) {
                return
            }
        } else {
            loading = true
        }
        errorMessage = nil
        BeansLogger.shared.log("歌单页面打开 source=\(playlist.source.rawValue) id=\(playlist.id) name=\(playlist.name) advertisedCount=\(playlist.trackCount)", level: .info)
        do {
            if playlist.source == .kugou {
                tracks = try await KugouMusicAPI.shared.playlistSongs(listID: playlist.id, externalID: playlist.externalID)
            } else if playlist.source == .qq {
                tracks = try await QQMusicAPI.shared.playlistSongs(listID: playlist.id)
                // 云端收藏接口临时被风控或返回空时，至少展示已同步到本机的 QQ 收藏，
                // 避免“我的喜欢”进入后变成空白页面。
                if tracks.isEmpty, playlist.id == QQMusicAPI.qqLikedPlaylistID {
                    tracks = favorites.qqFavoriteSongs
                    BeansLogger.shared.log("QQ 我的喜欢页面网络结果为空，使用本地收藏回退 count=\(tracks.count)", level: tracks.isEmpty ? .warn : .info)
                }
            } else if playlist.source == .bodian {
                tracks = try await BodianMusicAPI.shared.playlistTracks(playlistID: playlist.externalID ?? String(playlist.id))
                if tracks.isEmpty, playlist.isBodianLikedPlaylist {
                    tracks = favorites.bodianFavoriteSongs
                    BeansLogger.shared.log("波点我的喜欢页面网络结果为空，使用本地收藏回退 count=\(tracks.count)", level: tracks.isEmpty ? .warn : .info)
                }
            } else if playlist.source == .kuwo {
                tracks = try await KuwoMusicAPI.shared.playlistTracks(id: playlist.externalID ?? String(playlist.id))
                if tracks.isEmpty, playlist.isKuwoLikedPlaylist {
                    tracks = favorites.kuwoFavoriteSongs
                }
            } else if playlist.source == .qishui {
                tracks = try await QishuiMusicAPI.shared.playlistSongs(playlistID: playlist.externalID ?? String(playlist.id))
            } else {
                tracks = try await NetEaseAPI.shared.playlistTracks(id: playlist.id)
            }
            if !tracks.isEmpty {
                cache.saveSongs(tracks, playlist: playlist, accountID: cacheAccountID)
            }
            BeansLogger.shared.log("歌单页面加载完成 source=\(playlist.source.rawValue) id=\(playlist.id) name=\(playlist.name) count=\(tracks.count) error=无", level: tracks.isEmpty ? .warn : .info)
            loading = false
        } catch {
            if tracks.isEmpty {
                errorMessage = error.localizedDescription
            } else {
                BeansLogger.shared.log("歌单页面刷新失败，继续使用缓存 source=\(playlist.source.rawValue) id=\(playlist.id) error=\(error.localizedDescription)", level: .warn)
            }
            BeansLogger.shared.log("歌单页面加载失败 source=\(playlist.source.rawValue) id=\(playlist.id) name=\(playlist.name) error=\(error.localizedDescription)", level: .error)
            loading = false
        }
    }

    /// 导入歌单「更新」：重新从平台抓全量歌曲，覆盖本地副本
    private func refreshImportedEntry(_ entry: ImportedPlaylist) async {
        guard !updatingImported else { return }
        updatingImported = true
        BeansLogger.shared.log("导入歌单详情更新：\(entry.source.rawValue) \(entry.sourceID) \(entry.name)", level: .info)
        do {
            let payload = try await PlaylistImportService.fetch(source: entry.source, sourceID: entry.sourceID)
            importedStore.updateSongs(payload.songs, key: entry.key)
            tracks = payload.songs
            ToastCenter.shared.show("「\(entry.name)」已更新 \(payload.songs.count) 首")
        } catch {
            let text = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            ToastCenter.shared.show("更新失败：\(text)")
            BeansLogger.shared.log("导入歌单详情更新失败：\(entry.name) \(text)", level: .warn)
        }
        updatingImported = false
    }
}
