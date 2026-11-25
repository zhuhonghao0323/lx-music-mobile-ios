import SwiftUI

/// 汽水音乐独立入口。
///
/// 没有并进「音乐库 / 搜索」的平台枚举：汽水的搜索与 App 播放流要求签名服务，
/// 并进全站平台切换会让用户在搜索里选到一个默认不可用的平台。这里单独给一页，
/// 主路径是「推荐歌单 / 我的歌单 → 歌单详情 → 播放」，能力边界写在页面上。
struct QishuiHomeView: View {
    @EnvironmentObject private var theme: ThemeStore
    @EnvironmentObject private var player: PlayerManager
    @EnvironmentObject private var auth: AuthStore
    @ObservedObject private var qishuiAuth = QishuiMusicAuth.shared

    @State private var recommend: [Playlist] = []
    @State private var mine: [Playlist] = []
    @State private var loading = false
    @State private var errorMessage: String?
    @State private var showLogin = false
    @State private var didLoad = false

    private let api = QishuiMusicAPI.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                accountCard

                if !qishuiAuth.isLoggedIn {
                    guestHint
                }

                if !mine.isEmpty {
                    section(title: "我的歌单", subtitle: "\(mine.count) 个") {
                        grid(mine)
                    }
                }

                section(title: "推荐歌单", subtitle: recommend.isEmpty ? "" : "\(recommend.count) 个") {
                    if loading && recommend.isEmpty {
                        loadingGrid
                    } else if recommend.isEmpty {
                        emptyState
                    } else {
                        grid(recommend)
                    }
                }

                Text("汽水音乐的搜索与完整播放需要账号 Cookie；未登录时只能浏览歌单与歌词，播放会回落到试听片段。")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Color.beansComment)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)
            .padding(.bottom, 120)
        }
        .background { GlassBackdrop() }
        .navigationTitle("汽水音乐")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard !didLoad else { return }
            didLoad = true
            await load()
        }
        .refreshable { await load(force: true) }
        .sheet(isPresented: $showLogin) {
            QishuiLoginSheet()
                .environmentObject(theme)
        }
        .onReceive(NotificationCenter.default.publisher(for: .beansQishuiLoginDidUpdate)) { _ in
            Task { await load(force: true) }
        }
    }

    // MARK: - 顶部账号

    private var accountCard: some View {
        Button {
            BeansHaptics.tap()
            showLogin = true
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "s.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 46, height: 46)
                    .foregroundStyle(Color(red: 0.10, green: 0.78, blue: 0.72))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text(qishuiAuth.isLoggedIn
                         ? (qishuiAuth.nickname.isEmpty ? "汽水音乐已登录" : qishuiAuth.nickname)
                         : "汽水音乐")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.beansLabel)
                    Text(qishuiAuth.isLoggedIn
                         ? (qishuiAuth.vipBadge.map { "\($0) · 点击管理账号" } ?? "已登录 · 点击管理账号")
                         : "未登录 · 浏览推荐歌单，登录后同步我的歌单")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.beansComment)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                }
                Spacer(minLength: 0)
                Text(qishuiAuth.isLoggedIn ? "管理" : "登录")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.beansAmber)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background { BeansSurface(shape: Capsule()) }
            }
            .padding(14)
            .background { BeansGlass(shape: RoundedRectangle(cornerRadius: 20, style: .continuous)) }
            .contentShape(Rectangle())
        }
        .buttonStyle(GlassPressButtonStyle(scale: 0.97))
    }

    private var guestHint: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(Color.beansAmber)
            Text("不登录也能听推荐歌单里的免费曲目；登录后才会带上账号权限，并同步「我的歌单」。")
                .font(.system(size: 12.5))
                .foregroundStyle(Color.beansComment)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { BeansGlass(shape: RoundedRectangle(cornerRadius: 14, style: .continuous)) }
    }

    // MARK: - 分区

    @ViewBuilder
    private func section<Content: View>(title: String, subtitle: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.beansLabel)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 11.5))
                        .foregroundStyle(Color.beansComment)
                }
                Spacer()
            }
            content()
        }
    }

    private func grid(_ items: [Playlist]) -> some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
            spacing: 16
        ) {
            ForEach(items) { playlist in
                NavigationLink {
                    PlaylistView(playlist: playlist)
                        .environmentObject(player)
                        .environmentObject(auth)
                        .environmentObject(theme)
                } label: {
                    VStack(alignment: .leading, spacing: 7) {
                        QishuiCover(url: playlist.coverURL)
                            .aspectRatio(1, contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.10), lineWidth: 0.6)
                            }
                        Text(playlist.name)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.beansLabel)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if playlist.trackCount > 0 {
                            Text("\(playlist.trackCount) 首")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.beansComment)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var loadingGrid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
            spacing: 16
        ) {
            ForEach(0..<4, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.primary.opacity(0.07))
                    .aspectRatio(1, contentMode: .fit)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "waveform.slash")
                .font(.system(size: 24))
                .foregroundStyle(Color.beansComment)
            Text(errorMessage ?? "没有拿到推荐歌单，下拉重试")
                .font(.system(size: 12.5))
                .foregroundStyle(Color.beansComment)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background { BeansGlass(shape: RoundedRectangle(cornerRadius: 16, style: .continuous)) }
    }

    // MARK: - 数据

    private func load(force: Bool = false) async {
        if loading { return }
        await MainActor.run {
            loading = true
            errorMessage = nil
        }
        var recommendResult: [Playlist] = []
        var mineResult: [Playlist] = []
        do {
            recommendResult = try await api.discoverPlaylists(limit: 24)
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
        if qishuiAuth.isLoggedIn {
            let profileOK = await api.refreshProfile()
            if !profileOK {
                BeansLogger.shared.log("汽水账号资料校验未通过", level: .warn)
            }
            mineResult = (try? await api.userPlaylists()) ?? []
        }
        await MainActor.run {
            if !recommendResult.isEmpty || recommend.isEmpty {
                recommend = recommendResult
            }
            mine = mineResult
            loading = false
        }
    }
}

/// 汽水封面：16:9 长图会裁成方形，缺图时给一个固定渐变，避免卡片高低不齐。
private struct QishuiCover: View {
    let url: URL?

    var body: some View {
        GeometryReader { geo in
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                default:
                    LinearGradient(
                        colors: [Color(red: 0.10, green: 0.42, blue: 0.40), Color(red: 0.06, green: 0.20, blue: 0.24)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .overlay {
                        Image(systemName: "music.note")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.35))
                    }
                }
            }
        }
    }
}
