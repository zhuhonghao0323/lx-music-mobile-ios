import SwiftUI
import UIKit
import MediaPlayer

private struct ReferenceLyricCenterKey: PreferenceKey {
    static var defaultValue: [UUID: CGFloat] = [:]

    static func reduce(value: inout [UUID: CGFloat], nextValue: () -> [UUID: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

private struct ReferencePlaybackPresentationMetrics {
    static let headerTopSpacing: CGFloat = 20
}

struct ReferencePlaybackView: View {
    @EnvironmentObject private var theme: ThemeStore
    @EnvironmentObject private var player: PlayerManager
    @EnvironmentObject private var clock: PlaybackClock
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var localLibrary = LocalLibraryStore.shared
    @ObservedObject private var appleLayout = AppleMusicLayoutStore.shared

    let song: Song?
    let lyrics: [LyricLine]
    @Binding var showLyrics: Bool
    let onFavorite: () -> Void
    /// 底部一键收藏：直接进「我的收藏歌单」，不弹歌单选择（头部心形仍保留选择逻辑）
    var onQuickFavorite: (() -> Void)? = nil
    let onQueue: () -> Void
    let onComments: () -> Void
    let onSleepTimer: () -> Void
    let onAddToLocalPlaylist: () -> Void
    let onDownload: () -> Void
    let onPlayerSettings: () -> Void
    /// 关闭播放页（封面左滑返回）
    let onClose: () -> Void

    @AppStorage("beans.lyricOffset") private var lyricOffset = 0.0
    @AppStorage("beans.appleMusic.showVolume") private var showVolumeControl = false
    @AppStorage("beans.appleMusic.primaryHex") private var primaryHex = ""
    @AppStorage("beans.appleMusic.secondaryHex") private var secondaryHex = ""
    @AppStorage("beans.appleMusic.accentHex") private var accentHex = ""
    @AppStorage("beans.appleMusic.volumeHex") private var volumeHex = ""
    @AppStorage("beans.appleMusic.syncWallpaper") private var syncWallpaper = false
    @AppStorage("beans.appleMusic.wallpaperBlur") private var wallpaperBlur = 14.0
    @AppStorage("beans.showSongVIPBadge") private var showSongVIPBadge = true
    @AppStorage("beans.appleMusic.showLyricPreview") private var showLyricPreview = true
    /// 与经典 / 黑胶共用：背景光晕、浮尘、DJ 脉冲、进度条样式
    @AppStorage("beans.playerBreath") private var breath = 0.6
    @AppStorage("beans.playerDustMode") private var dustModeRaw = BeansPlayerDustMode.off.rawValue
    @AppStorage("beans.playerDustDensity") private var dustDensity = 1.0
    @AppStorage("beans.playerDustSize") private var dustSize = 1.0
    @AppStorage("beans.djVisual") private var djVisualEnabled = false
    @AppStorage("beans.djVisualIntensity") private var djVisualIntensity = 0.8
    /// 歌词设置：字号 / 行距 / 翻译 / 发光，与经典方案共用同一组开关
    @AppStorage("beans.lyricFontSize") private var lyricFontSize = 17
    @AppStorage("beans.lyricSpacing") private var lyricSpacing = 24
    @AppStorage("beans.lyricTranslation") private var lyricTranslation = true
    @AppStorage("beans.lyricGlow") private var lyricGlowLevel = 1
    /// 歌词展示方式（与经典方案共用）：逐字高亮 / 大字聚焦
    @AppStorage("beans.lyricDisplayMode") private var lyricDisplayModeRaw = LyricDisplayMode.classic.rawValue
    @AppStorage(LyricStageSettings.enabledKey) private var lyricStageEnabled = LyricStageSettings.defaultEnabled
    @AppStorage(LyricStageSettings.idKey) private var lyricStageID = LyricStageSettings.defaultID
    /// 舞台首帧就绪后才顶替原生歌词，避免 WebView 黑屏
    @State private var lyricStageReady = false
    private let downloadFeatureUnlocked = true
    @State private var lyricCenters: [UUID: CGFloat] = [:]
    @State private var focusedLyricID: UUID?
    /// 沉浸舞台：点一下屏幕才呼出极简控制层，默认全部隐藏
    @State private var stageChromeVisible = false
    /// 进入舞台后先露出 3 秒控制层（含右上角设置入口），随后自动淡出
    @State private var stageChromeAutoHideTask: Task<Void, Never>?
    @State private var lyricsViewportHeight: CGFloat = 0
    @State private var isDraggingLyrics = false
    @State private var resumeTask: Task<Void, Never>?
    /// 上/下滑切歌时封面整块的位移（滑出 → 换歌 → 滑入）
    @State private var coverSwitchOffset: CGFloat = 0

    /// 字号以 17pt 为基准，按用户设置整体缩放
    private var lyricScale: CGFloat {
        CGFloat(min(max(lyricFontSize, 12), 28)) / 17.0
    }

    private var lyricStage: LyricStage? {
        LyricStage.stage(id: lyricStageID)
    }

    /// 舞台是否已配置（决定是否尝试挂载 WebView）。
    /// 这里同时校验 HTML 是否真在包里：缺失时不挂 WebView，直接留在原生歌词。
    private var lyricStageConfigured: Bool {
        lyricStageEnabled
            && lyricStage != nil
            && !lyrics.isEmpty
            && showLyrics
            && LyricStageResources.url(for: lyricStageID) != nil
    }

    /// 舞台就绪后才隐藏原生歌词
    private var lyricStageActive: Bool {
        lyricStageConfigured && lyricStageReady
    }

    private var stageAccentHex: String? {
        let ui = UIColor(accentColor)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        guard ui.getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }

    private func layoutEntry(_ part: AppleMusicLayoutPart) -> PlayerLayoutEntry {
        appleLayout.entry(for: part)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                playerBackground

                // 舞台 WebView 常驻：未就绪时 0.001 透明度预热，
                // 就绪后整块铺满屏幕并盖住顶部信息条与底部播放控件（不再有毛玻璃上下栏）。
                if lyricStageConfigured, let stage = lyricStage {
                    stageCanvas(stage, insets: geometry.safeAreaInsets)
                        .opacity(lyricStageActive ? 1 : 0.001)
                        .allowsHitTesting(lyricStageActive)
                        .zIndex(lyricStageActive ? 2 : 0)
                }

                if !lyricStageActive {
                    VStack(spacing: 0) {
                        Color.clear.frame(height: ReferencePlaybackPresentationMetrics.headerTopSpacing)

                        ZStack {
                            if showLyrics {
                                lyricsPage
                                    .simultaneousGesture(lyricsSwipeBackGesture)
                                    .transition(.asymmetric(
                                        insertion: .move(edge: .bottom).combined(with: .opacity),
                                        removal: .move(edge: .top).combined(with: .opacity)
                                    ))
                            } else {
                                coverPage(size: geometry.size)
                                    .simultaneousGesture(coverSwipeGesture)
                                    .transition(.asymmetric(
                                        insertion: .move(edge: .top).combined(with: .opacity),
                                        removal: .move(edge: .top).combined(with: .opacity)
                                    ))
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .animation(.easeInOut(duration: 0.22), value: showLyrics)

                        playbackControls(bottomInset: geometry.safeAreaInsets.bottom)
                    }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .background {
            HighRefreshConfigurator()
                .frame(width: 0, height: 0)
                .allowsHitTesting(false)
        }
        .onDisappear {
            resumeTask?.cancel()
            stageChromeAutoHideTask?.cancel()
        }
        .onChange(of: lyricStageID) { _ in lyricStageReady = false }
        .onChange(of: lyricStageEnabled) { _ in lyricStageReady = false }
        .onChange(of: showLyrics) { _ in
            lyricStageReady = false
            stageChromeVisible = false
            stageChromeAutoHideTask?.cancel()
        }
        .onChange(of: lyricStageActive) { active in
            if active {
                showStageChromeTemporarily()
            } else {
                stageChromeAutoHideTask?.cancel()
                stageChromeVisible = false
            }
        }
        // 兜底：2.4s 仍未 ready 就直接放行，避免舞台被 ready 门控永久挡住。
        // 资源缺失时不能放行，否则空 WebView 会顶掉原生歌词。
        .task(id: "stage-" + lyricStageID + "-" + (song?.identityKey ?? "") + "-" + (lyricStageEnabled ? "1" : "0") + "-" + (showLyrics ? "1" : "0")) {
            guard lyricStageEnabled, showLyrics else { return }
            guard LyricStageResources.url(for: lyricStageID) != nil, !lyrics.isEmpty else { return }
            try? await Task.sleep(nanoseconds: 2_400_000_000)
            guard !Task.isCancelled else { return }
            if !lyricStageReady { lyricStageReady = true }
        }
    }

    @ViewBuilder
    private var playerBackground: some View {
        ZStack {
            // Full-screen covers need an opaque base so the home page cannot show through
            // while the cover image is loading or when a presentation uses a clear surface.
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()

            if syncWallpaper, let image = theme.customBackgroundImage(for: colorScheme) {
                WallpaperImage(image: image)
                    .blur(radius: CGFloat(wallpaperBlur))
                    .scaleEffect(wallpaperBlur > 0 ? 1.08 : 1)
                    .overlay(Color.black.opacity(colorScheme == .dark ? 0.44 : 0.16))
                    .ignoresSafeArea()
            } else if syncWallpaper, let color = theme.customBackground(for: colorScheme) {
                LinearGradient(
                    colors: [color.opacity(0.92), color.opacity(0.58), colorScheme == .dark ? .black.opacity(0.88) : .white.opacity(0.70)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .blur(radius: CGFloat(wallpaperBlur * 0.35))
                .ignoresSafeArea()
            } else {
                CoverBlurBackground(url: song?.coverURL, scheme: colorScheme)
                    .overlay(Color.black.opacity(colorScheme == .dark ? 0.48 : 0.14))
                    .ignoresSafeArea()
            }

            AmbientGlowView(
                accent: accentColor,
                secondary: primaryColor.opacity(0.72),
                isPlaying: player.isPlaying,
                dustMode: BeansPlayerDustMode(rawValue: dustModeRaw) ?? .off,
                dustDensity: dustDensity,
                dustSize: dustSize,
                breath: breath
            )
            if djVisualEnabled {
                DJVisualView(
                    accent: accentColor,
                    secondary: primaryColor.opacity(0.7),
                    isPlaying: player.isPlaying,
                    intensity: djVisualIntensity
                )
            }
        }
    }

    private func coverPage(size: CGSize) -> some View {
        let contentWidth = max(size.width - 64, 0)
        let artworkSize = min(contentWidth, min(size.height * 0.50, 390))

        return VStack(spacing: 0) {
            Spacer(minLength: 8)

            CoverImage(
                url: song?.coverURL,
                size: artworkSize,
                cornerRadius: 18,
                emptyHint: player.isBuffering ? "等待开始播放…" : nil
            )
            .frame(width: artworkSize, height: artworkSize)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .onTapGesture(count: 2) {
                guard song != nil else { return }
                BeansHaptics.success()
                onFavorite()
            }
            .shadow(color: .black.opacity(0.46), radius: 36, y: 18)
            .scaleEffect(player.isPlaying ? 1 : 0.965)
            .modifier(AppleMusicLayoutTransform(entry: layoutEntry(.cover)))
            .animation(.spring(response: 0.36, dampingFraction: 0.84), value: player.isPlaying)

            if showLyricPreview {
            VStack(spacing: 5) {
                HStack(spacing: 9) {
                    Text(song?.name ?? "未在播放")
                        .font(BeansFont.appFont(22, .bold))
                        .foregroundStyle(primaryColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    if showSongVIPBadge, let badge = player.playbackSourceBadge {
                        PlaybackSourceBadge(text: badge, isSource: player.playbackBadgeIsSource)
                    }
                }
                Text(subtitle)
                    .font(BeansFont.appFont(13.5, .medium))
                    .foregroundStyle(secondaryColor)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: 420)
            .padding(.top, 22)
            .modifier(AppleMusicLayoutTransform(entry: layoutEntry(.title)))

            MiniLyricsPreview(lines: previewLyrics, primary: primaryColor, secondary: secondaryColor) {
                guard !lyrics.isEmpty else { return }
                BeansHaptics.tap()
                showLyrics = true
            }
            .padding(.top, 18)
            .modifier(AppleMusicLayoutTransform(entry: layoutEntry(.previewLyric)))
            } else {
                compactTrackHeader
                    .padding(.top, 22)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 32)
        .offset(y: coverSwitchOffset)
    }

    private var compactTrackHeader: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(song?.name ?? "未在播放")
                    .font(BeansFont.appFont(16, .semibold))
                    .foregroundStyle(primaryColor)
                    .lineLimit(1)
                Text(subtitle)
                    .font(BeansFont.appFont(12, .medium))
                    .foregroundStyle(secondaryColor)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            compactActionButton(
                icon: localLibrary.containsSong(song) ? "heart.fill" : "heart",
                active: localLibrary.containsSong(song)
            ) { onFavorite() }
            Menu {
                Button("定时关闭", action: onSleepTimer)
                Button("添加到本地歌单", action: onAddToLocalPlaylist)
                if downloadFeatureUnlocked {
                    Button("下载歌曲", action: onDownload)
                }
                Button("播放器设置", action: onPlayerSettings)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(primaryColor.opacity(0.78))
                    .frame(width: 38, height: 38)
            }
        }
        .frame(maxWidth: 420)
    }

    // MARK: - 沉浸舞台

    /// 舞台画布：铺满全屏，歌词由 WebView 自己绘制。
    /// 轻点任意位置呼出/收起极简控制层；从左往右滑仍然回到封面。
    private func stageCanvas(_ stage: LyricStage, insets: EdgeInsets) -> some View {
        ZStack {
            LyricStageWebView(
                stage: stage,
                lines: lyrics,
                progress: clock.progress,
                isPlaying: player.isPlaying,
                accentHex: stageAccentHex,
                onReady: { ok in lyricStageReady = ok }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if lyricStageActive {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        toggleStageChrome()
                    }

                if stageChromeVisible {
                    immersiveChrome(insets: insets)
                        .transition(.opacity)
                }
            }
        }
        .ignoresSafeArea()
        // 控制层露出时也要能从左往右滑回封面（chrome 会盖住上面的点击层）
        .simultaneousGesture(lyricsSwipeBackGesture, including: lyricStageActive ? GestureMask.all : GestureMask.none)
    }

    /// 轻点切换控制层；呼出时 3.2 秒后自动淡出，避免常驻遮挡歌词
    private func toggleStageChrome() {
        if stageChromeVisible {
            stageChromeAutoHideTask?.cancel()
            withAnimation(.easeInOut(duration: 0.18)) { stageChromeVisible = false }
        } else {
            showStageChromeTemporarily()
        }
    }

    private func showStageChromeTemporarily() {
        stageChromeAutoHideTask?.cancel()
        withAnimation(.easeInOut(duration: 0.18)) { stageChromeVisible = true }
        stageChromeAutoHideTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_200_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.35)) { stageChromeVisible = false }
        }
    }

    /// 沉浸模式下临时呼出的控制层：没有毛玻璃、没有常驻栏，只在点击后出现
    private func immersiveChrome(insets: EdgeInsets) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button {
                    BeansHaptics.tap()
                    withAnimation(.easeInOut(duration: 0.22)) { showLyrics = false }
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(.black.opacity(0.34)))
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 2) {
                    Text(song?.name ?? "")
                        .font(BeansFont.appFont(14, .semibold))
                        .lineLimit(1)
                    Text(subtitle)
                        .font(BeansFont.appFont(11))
                        .opacity(0.72)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                // 播放设置入口：舞台全屏后唯一能进设置的地方，跟随控制层自动隐藏
                Button {
                    BeansHaptics.tap()
                    stageChromeAutoHideTask?.cancel()
                    withAnimation(.easeInOut(duration: 0.18)) { stageChromeVisible = false }
                    onPlayerSettings()
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(.black.opacity(0.34)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("播放设置")

                Button {
                    BeansHaptics.tap()
                    withAnimation(.easeInOut(duration: 0.18)) { stageChromeVisible = false }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(.black.opacity(0.34)))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 18)
            .padding(.top, max(insets.top, 20) + 4)

            Spacer(minLength: 0)

            VStack(spacing: 14) {
                ReferenceScrubber()
                HStack(spacing: 40) {
                    Button {
                        BeansHaptics.tap()
                        player.previous()
                    } label: {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 22, weight: .semibold))
                    }
                    .buttonStyle(.plain)

                    Button {
                        BeansHaptics.tap()
                        player.togglePlayPause()
                    } label: {
                        PlayPauseMorphIcon(isPlaying: player.isPlaying, size: 22)
                            .frame(width: 58, height: 58)
                            .background(Circle().fill(.white.opacity(0.14)))
                    }
                    .buttonStyle(.plain)

                    Button {
                        BeansHaptics.tap()
                        player.next()
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 22, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 26)
            .padding(.bottom, max(insets.bottom, 16) + 14)
        }
        .foregroundStyle(.white)
        .background {
            VStack(spacing: 0) {
                LinearGradient(colors: [.black.opacity(0.52), .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: 150)
                Spacer(minLength: 0)
                LinearGradient(colors: [.clear, .black.opacity(0.62)], startPoint: .top, endPoint: .bottom)
                    .frame(height: 220)
            }
            .allowsHitTesting(false)
        }
    }

    private var lyricsPage: some View {
        VStack(spacing: 0) {
            lyricsHeader
                .padding(.horizontal, 24)
                .padding(.bottom, 10)

            if lyricStageActive {
                // 舞台自己会画歌词，原生歌词行隐掉，只留顶部信息与底部控制
                Spacer(minLength: 0)
            } else if lyrics.isEmpty {
                emptyLyricsView
            } else {
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        LazyVStack(alignment: .leading, spacing: max(10, CGFloat(lyricSpacing))) {
                            Color.clear.frame(height: max(88, lyricsViewportHeight * 0.30))
                            ForEach(lyrics) { line in
                                lyricLine(line, isFocused: line.id == currentVisualLyricID)
                                    .id(line.id)
                                    .background {
                                        GeometryReader { rowGeometry in
                                            Color.clear.preference(
                                                key: ReferenceLyricCenterKey.self,
                                                value: [line.id: rowGeometry.frame(in: .named("referenceLyricsViewport")).midY]
                                            )
                                        }
                                    }
                            }
                            Color.clear.frame(height: max(110, lyricsViewportHeight * 0.34))
                        }
                        .padding(.horizontal, 28)
                    }
                    .coordinateSpace(name: "referenceLyricsViewport")
                    .mask(
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0.0),
                                .init(color: .black, location: 0.12),
                                .init(color: .black, location: 0.84),
                                .init(color: .clear, location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .background {
                        GeometryReader { viewport in
                            Color.clear
                                .onAppear { lyricsViewportHeight = viewport.size.height }
                                .onChange(of: viewport.size.height) { lyricsViewportHeight = $0 }
                        }
                    }
                    .onPreferenceChange(ReferenceLyricCenterKey.self) { centers in
                        lyricCenters = centers
                        updateFocusedLyric(from: centers)
                    }
                    .simultaneousGesture(lyricsDragGesture(proxy: proxy))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                            scrollToPlaybackLyric(proxy: proxy, animated: false)
                        }
                    }
                    .onChange(of: currentPlaybackLyricID) { _ in
                        guard !isDraggingLyrics else { return }
                        scrollToPlaybackLyric(proxy: proxy, animated: true)
                    }
                }
            }
        }
    }

    private var lyricsHeader: some View {
        HStack(spacing: 12) {
            Button {
                BeansHaptics.tap()
                showLyrics = false
            } label: {
                CoverImage(url: song?.coverURL, size: 48, cornerRadius: 10)
                    .shadow(color: .black.opacity(0.26), radius: 9, y: 4)
            }
            .buttonStyle(GlassPressButtonStyle(scale: 0.94))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 7) {
                    Text(song?.name ?? "未在播放")
                        .font(BeansFont.appFont(15, .semibold))
                        .foregroundStyle(primaryColor)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                Text(subtitle)
                    .font(BeansFont.appFont(12, .medium))
                    .foregroundStyle(secondaryColor)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            Spacer(minLength: 0)
            HStack(spacing: 0) {
                compactActionButton(
                    icon: localLibrary.containsSong(song) ? "heart.fill" : "heart",
                    active: localLibrary.containsSong(song)
                ) {
                    onFavorite()
                }
                Menu {
                    // 上划手势改成切歌后，评论入口收到菜单里
                    Button("查看评论", action: onComments)
                    Button("定时关闭", action: onSleepTimer)
                    Button("添加到本地歌单", action: onAddToLocalPlaylist)
                    if downloadFeatureUnlocked {
                        Button("下载歌曲", action: onDownload)
                    }
                    Button("播放器设置", action: onPlayerSettings)
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(primaryColor.opacity(0.78))
                        .frame(width: 38, height: 38)
                        .contentShape(Rectangle())
                }
            }
        }
    }

    private func playbackControls(bottomInset: CGFloat) -> some View {
        VStack(spacing: 15) {
            ReferenceScrubber()
                .modifier(AppleMusicLayoutTransform(entry: layoutEntry(.progress)))
            HStack(spacing: 28) {
                Button {
                    BeansHaptics.tap()
                    player.previous()
                } label: {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 25, weight: .semibold))
                }
                .buttonStyle(.plain)
                .modifier(AppleMusicLayoutTransform(entry: layoutEntry(.previous)))

                Button {
                    BeansHaptics.tap()
                    player.togglePlayPause()
                } label: {
                    PlayPauseMorphIcon(isPlaying: player.isPlaying, size: 24)
                        .frame(width: 66, height: 66)
                        .foregroundStyle(primaryColor)
                }
                .buttonStyle(GlassPressButtonStyle(scale: 0.92))
                .modifier(AppleMusicLayoutTransform(entry: layoutEntry(.play)))

                Button {
                    BeansHaptics.tap()
                    player.next()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 25, weight: .semibold))
                }
                .buttonStyle(.plain)
                .modifier(AppleMusicLayoutTransform(entry: layoutEntry(.next)))
            }
            .foregroundStyle(primaryColor)
            .frame(maxWidth: 320)

            if showVolumeControl {
                ReferenceVolumeControl(accent: volumeColor, secondary: secondaryColor)
                    .frame(maxWidth: 420)
                    .modifier(AppleMusicLayoutTransform(entry: layoutEntry(.volume)))
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            HStack(spacing: 26) {
                // 收藏：与歌词页头部、播放设置里的「我的收藏」共用本地歌单，
                // 点一下加入默认收藏歌单，再点一下取消，实心/空心实时反映状态。
                referenceActionButton(
                    icon: localLibrary.containsSong(song) ? "heart.fill" : "heart",
                    active: localLibrary.containsSong(song)
                ) {
                    guard song != nil else { return }
                    if let onQuickFavorite {
                        onQuickFavorite()
                    } else {
                        onFavorite()
                    }
                }
                referenceActionButton(icon: "quote.bubble", active: showLyrics) {
                    guard !lyrics.isEmpty else { return }
                    showLyrics.toggle()
                }
                referenceActionButton(icon: player.playMode.icon, active: player.playMode == .shuffle) {
                    player.togglePlayMode()
                }
                referenceActionButton(icon: "list.bullet") {
                    onQueue()
                }
            }
            .frame(maxWidth: 420)
            .modifier(AppleMusicLayoutTransform(entry: layoutEntry(.actions)))
        }
        .padding(.horizontal, 24)
        .padding(.top, 10)
        .padding(.bottom, max(14, bottomInset + 4))
    }

    private func referenceActionButton(icon: String, active: Bool = false, tint: Color = .white, action: @escaping () -> Void) -> some View {
        Button {
            BeansHaptics.tap()
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(active ? accentColor : primaryColor.opacity(0.78))
                .frame(width: 58, height: 58)
                .background { BeansGlass(shape: Circle(), forceLiquid: true) }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func compactActionButton(icon: String, active: Bool = false, action: @escaping () -> Void) -> some View {
        Button {
            BeansHaptics.tap()
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(active ? accentColor : primaryColor.opacity(0.78))
                .frame(width: 38, height: 38)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var emptyLyricsView: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "quote.bubble")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(.white.opacity(0.42))
            Text("暂无歌词")
                .font(BeansFont.appFont(15, .semibold))
                .foregroundStyle(.white.opacity(0.86))
            Text("点击封面区域返回歌曲页面")
                .font(BeansFont.appFont(12))
                .foregroundStyle(.white.opacity(0.46))
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            BeansHaptics.tap()
            showLyrics = false
        }
    }

    private var previewLyrics: [LyricLine] {
        guard !lyrics.isEmpty else { return [] }
        let current = currentPlaybackLyricIndex ?? 0
        let start = max(current - 1, 0)
        let end = min(start + 3, lyrics.count)
        return Array(lyrics[start..<end])
    }

    private var currentPlaybackLyricIndex: Int? {
        guard !lyrics.isEmpty else { return nil }
        let progress = LyricTiming.effectiveProgress(clock.progress, userOffset: lyricOffset)
        var low = 0
        var high = lyrics.count - 1
        var answer: Int?
        while low <= high {
            let mid = (low + high) / 2
            if lyrics[mid].time <= progress {
                answer = mid
                low = mid + 1
            } else {
                high = mid - 1
            }
        }
        return answer
    }

    private var currentPlaybackLyricID: UUID? {
        guard let index = currentPlaybackLyricIndex, lyrics.indices.contains(index) else { return nil }
        return lyrics[index].id
    }

    private var currentVisualLyricID: UUID? {
        isDraggingLyrics ? focusedLyricID : (focusedLyricID ?? currentPlaybackLyricID)
    }

    private var subtitle: String {
        guard let song else { return "" }
        let parts = [song.artists, song.album].filter { !$0.isEmpty }
        return parts.isEmpty ? "未知歌曲" : parts.joined(separator: " · ")
    }

    private var lyricDisplayMode: LyricDisplayMode {
        LyricDisplayMode(rawValue: lyricDisplayModeRaw) ?? .classic
    }

    /// 当前行在整行时长里的进度（0–1），逐字高亮用
    private func lyricLineProgress(for line: LyricLine) -> Double {
        guard let index = lyrics.firstIndex(where: { $0.id == line.id }) else { return 0 }
        let nextTime = index + 1 < lyrics.count ? lyrics[index + 1].time : line.time + 4
        let span = max(0.4, nextTime - line.time)
        let now = LyricTiming.effectiveProgress(clock.progress, userOffset: lyricOffset)
        return min(1, max(0, (now - line.time) / span))
    }

    /// 逐字高亮：按进度把每个字着色，用 Text 拼接保证长句自动换行
    private func composedKaraokeText(_ text: String, progress: Double) -> Text {
        let chars = Array(text)
        let lit = Int((Double(chars.count) * progress).rounded())
        var composed = Text("")
        for (index, ch) in chars.enumerated() {
            composed = composed + Text(String(ch))
                .foregroundColor(index < lit ? primaryColor : primaryColor.opacity(0.28))
        }
        return composed
    }

    /// 当前行的大字 / 逐字高亮渲染（与经典播放页同一套观感）
    @ViewBuilder
    private func focusedLyricContent(_ line: LyricLine) -> some View {
        if lyricDisplayMode == .bigWord {
            Text(line.text.isEmpty ? " " : line.text)
                .font(BeansFont.appFont(36 * lyricScale, .bold))
                .foregroundStyle(primaryColor)
                .shadow(color: primaryColor.opacity(0.45), radius: 12)
                .lineSpacing(2)
        } else {
            composedKaraokeText(line.text.isEmpty ? " " : line.text, progress: lyricLineProgress(for: line))
                .font(BeansFont.appFont(32 * lyricScale, .bold))
                .shadow(color: primaryColor.opacity(0.35), radius: 8)
                .lineSpacing(2)
        }
    }

    private func lyricLine(_ line: LyricLine, isFocused: Bool) -> some View {
        Button {
            BeansHaptics.tap()
            player.seek(to: LyricTiming.seekTime(for: line, userOffset: lyricOffset))
        } label: {
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    if isFocused, lyricDisplayMode != .classic {
                        focusedLyricContent(line)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text(line.text.isEmpty ? " " : line.text)
                            .font(BeansFont.appFont((isFocused ? 27 : 23) * lyricScale, isFocused ? .bold : .semibold))
                            .foregroundStyle(primaryColor.opacity(isFocused ? 1 : 0.36))
                            .shadow(color: isFocused ? primaryColor.opacity(lyricGlowLevel > 0 ? 0.30 : 0) : .clear,
                                    radius: isFocused ? CGFloat(lyricGlowLevel) * 5 : 0)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if isFocused && isDraggingLyrics {
                        Spacer(minLength: 8)
                        Text(beansTimeString(line.time))
                            .font(BeansFont.appFont(11, .semibold, .monospaced))
                            .foregroundStyle(secondaryColor.opacity(0.82))
                    }
                }
                if isFocused, lyricTranslation, let translation = line.translation, !translation.isEmpty {
                    Text(translation)
                        .font(BeansFont.appFont(15 * lyricScale, .medium))
                        .foregroundStyle(secondaryColor.opacity(0.72))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .scaleEffect(isFocused ? 1.06 : 0.84, anchor: .leading)
            .blur(radius: isFocused ? 0 : 0.7)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.28, dampingFraction: 0.88), value: isFocused)
    }

    private func updateFocusedLyric(from centers: [UUID: CGFloat]) {
        guard lyricsViewportHeight > 0, !centers.isEmpty else { return }
        let center = lyricsViewportHeight / 2
        focusedLyricID = centers.min { abs($0.value - center) < abs($1.value - center) }?.key
    }

    private func scrollToPlaybackLyric(proxy: ScrollViewProxy, animated: Bool) {
        guard let id = currentPlaybackLyricID else { return }
        let action = { proxy.scrollTo(id, anchor: .center) }
        if animated {
            withAnimation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.38)) { action() }
        } else {
            action()
        }
    }

    private func lyricsDragGesture(proxy: ScrollViewProxy) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { _ in
                isDraggingLyrics = true
                resumeTask?.cancel()
                updateFocusedLyric(from: lyricCenters)
            }
            .onEnded { _ in
                resumeTask?.cancel()
                if let id = focusedLyricID {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                        proxy.scrollTo(id, anchor: .center)
                    }
                }
                resumeTask = Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 2_500_000_000)
                    guard !Task.isCancelled else { return }
                    isDraggingLyrics = false
                }
            }
    }

    /// 封面页手势（按用户口径）：左滑=从左往右(dx>0)返回、右滑=从右往左(dx<0)看歌词、上滑下一曲、下滑上一曲
    private var coverSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 20)
            .onEnded { value in
                let dx = value.translation.width
                let dy = value.translation.height
                let vx = value.predictedEndTranslation.width
                let vy = value.predictedEndTranslation.height
                guard max(abs(dx), abs(dy)) > 34 || max(abs(vx), abs(vy)) > 80 else { return }
                if abs(dx) > abs(dy) {
                    BeansHaptics.tap()
                    if dx > 0 || vx > 130 {
                        // 左滑（从左往右）：返回
                        onClose()
                    } else if lyrics.isEmpty {
                        ToastCenter.shared.show("暂无歌词")
                    } else {
                        withAnimation(.easeInOut(duration: 0.22)) { showLyrics = true }
                    }
                } else {
                    switchSong(up: dy < 0)
                }
            }
    }

    /// 上下切歌：封面先滑出屏幕，换歌后从另一侧滑回，符合 iOS 的「翻页」手感
    private func switchSong(up: Bool) {
        BeansHaptics.medium()
        let travel: CGFloat = 420
        let out: CGFloat = up ? -travel : travel
        withAnimation(.easeIn(duration: 0.16)) {
            coverSwitchOffset = out
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            if up { player.next() } else { player.previous() }
            coverSwitchOffset = -out
            DispatchQueue.main.async {
                withAnimation(.spring(response: 0.36, dampingFraction: 0.88)) {
                    coverSwitchOffset = 0
                }
            }
        }
    }

    /// 歌词页手势：左滑（从左往右 dx>0）回到专辑封面
    private var lyricsSwipeBackGesture: some Gesture {
        DragGesture(minimumDistance: 18)
            .onEnded { value in
                let dx = value.translation.width
                let vx = value.predictedEndTranslation.width
                guard abs(dx) >= abs(value.translation.height),
                      dx > 52 || vx > 110 else { return }
                BeansHaptics.tap()
                withAnimation(.easeInOut(duration: 0.22)) { showLyrics = false }
            }
    }

    private var primaryColor: Color {
        if lyricStageActive { return .white }
        if primaryHex.hasPrefix("#"), let color = Color(hex: primaryHex) { return color }
        return .white
    }

    private var secondaryColor: Color {
        if lyricStageActive { return .white.opacity(0.62) }
        if secondaryHex.hasPrefix("#"), let color = Color(hex: secondaryHex) { return color }
        return .white.opacity(0.58)
    }

    private var accentColor: Color {
        if accentHex.hasPrefix("#"), let color = Color(hex: accentHex) { return color }
        return Color(red: 1.0, green: 0.28, blue: 0.36)
    }

    private var volumeColor: Color {
        if volumeHex.hasPrefix("#"), let color = Color(hex: volumeHex) { return color }
        return primaryColor
    }
}

private struct ReferenceScrubber: View {
    @EnvironmentObject private var player: PlayerManager
    @EnvironmentObject private var clock: PlaybackClock
    /// 与其它方案共用同一套进度条样式与颜色，避免「设置里改了没反应」
    @AppStorage("beans.progressBarStyle") private var progressBarStyle = 0
    @AppStorage("beans.progressAccentHex") private var progressAccentHex = ""
    @AppStorage("beans.appleMusic.accentHex") private var appleAccentHex = ""

    private var accent: Color {
        if progressAccentHex.hasPrefix("#"), let color = Color(hex: progressAccentHex) { return color }
        if appleAccentHex.hasPrefix("#"), let color = Color(hex: appleAccentHex) { return color }
        return .white.opacity(0.92)
    }

    var body: some View {
        VStack(spacing: 4) {
            SeekBar(accent: accent, track: .white.opacity(0.18), style: progressBarStyle)
                .frame(height: 30)

            HStack {
                Text(beansTimeString(clock.progress))
                Spacer()
                Text(beansTimeString(max(clock.duration, player.currentSong?.duration ?? 0)))
            }
            .font(BeansFont.appFont(11, .regular, .monospaced))
            .foregroundStyle(.white.opacity(0.52))
        }
        .frame(maxWidth: 420)
    }
}

private struct ReferenceVolumeControl: View {
    let accent: Color
    let secondary: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "speaker.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(secondary.opacity(0.84))
            ReferenceSystemVolumeView(accent: accent, secondary: secondary)
                .frame(height: 32)
            Image(systemName: "speaker.wave.2.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(secondary.opacity(0.84))
        }
        .frame(height: 34)
    }
}

private struct ReferenceSystemVolumeView: UIViewRepresentable {
    let accent: Color
    let secondary: Color

    func makeUIView(context: Context) -> MPVolumeView {
        let view = MPVolumeView(frame: .zero)
        view.showsRouteButton = false
        styleVolumeSlider(in: view)
        return view
    }

    func updateUIView(_ uiView: MPVolumeView, context: Context) {
        styleVolumeSlider(in: uiView)
    }

    private func styleVolumeSlider(in view: MPVolumeView) {
        let applyStyle = {
            let sliders = allSubviews(in: view).compactMap { $0 as? UISlider }
            sliders.forEach { slider in
                slider.minimumTrackTintColor = UIColor(accent.opacity(0.88))
                slider.maximumTrackTintColor = UIColor(secondary.opacity(0.32))
                slider.thumbTintColor = UIColor(accent)
            }
        }

        // MPVolumeView creates its internal slider during layout, so apply the tint once more after it settles.
        applyStyle()
        DispatchQueue.main.async {
            applyStyle()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                applyStyle()
            }
        }
    }

    private func allSubviews(in view: UIView) -> [UIView] {
        view.subviews + view.subviews.flatMap { allSubviews(in: $0) }
    }
}

private struct MiniLyricsPreview: View {
    let lines: [LyricLine]
    let primary: Color
    let secondary: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                if lines.isEmpty {
                    Text("暂无歌词")
                        .font(BeansFont.appFont(15, .semibold))
                        .foregroundStyle(secondary.opacity(0.54))
                } else {
                    ForEach(Array(lines.enumerated()), id: \.element.id) { index, line in
                        Text(line.text.isEmpty ? " " : line.text)
                            .font(BeansFont.appFont(index == 1 ? 17 : 15, index == 1 ? .semibold : .medium))
                            .foregroundStyle((index == 1 ? primary : secondary).opacity(index == 1 ? 0.86 : 0.5))
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }
                }
            }
            .frame(maxWidth: 420, minHeight: 92)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
