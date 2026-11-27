import SwiftUI
import UIKit

// MARK: - 沉浸式播放器（Liquid Glass）
//
// 布局分六层，但共享同一个连续空间，不做六块卡片：
//   1. 顶部状态栏 / 导航（玻璃圆钮 + 居中的播放状态与专辑名）
//   2. 专辑封面（唯一视觉焦点，尺寸随屏幕高度自适应）
//   3. 歌曲信息（歌名 / 多歌手 / 收藏）
//   4. 歌词预览（三行，仅当前行高亮）
//   5. 进度条（细轨 + 拖动放大手柄）
//   6. 播放控制（模式 / 上一首 / 播放 / 下一首 / 队列）
//
// 背景由 ImmersiveBackdrop 负责：封面取色 + 模糊交叉淡入 + 上下压暗。
// 播放能力全部走 PlayerManager，不碰播放引擎、后台播放、锁屏与耳机控制。

struct ImmersivePlayerView: View {
    @EnvironmentObject private var player: PlayerManager
    @EnvironmentObject private var clock: PlaybackClock
    @ObservedObject private var localLibrary = LocalLibraryStore.shared

    let song: Song?
    let lyrics: [LyricLine]
    @Binding var showLyrics: Bool

    let onClose: () -> Void
    let onMore: () -> Void
    let onQueue: () -> Void
    /// 顶部/歌词页红心：一键收藏进「我的收藏」
    let onQuickFavorite: () -> Void
    /// 双击封面：走歌单选择逻辑
    let onFavorite: () -> Void
    let onArtist: () -> Void
    let onLyricStage: () -> Void
    let onSettings: () -> Void

    @AppStorage("beans.lyricFontSize") private var lyricFontSize = 17
    @AppStorage("beans.lyricSpacing") private var lyricSpacing = 24
    @AppStorage("beans.lyricTranslation") private var lyricTranslation = true
    @AppStorage("beans.lyricOffset") private var lyricOffset = 0.0
    @AppStorage("beans.lyricAlignRaw") private var lyricAlignRaw = "center"
    @AppStorage("beans.lyricOffsetX") private var lyricOffsetX = 0.0
    @AppStorage("beans.lyricDisplayMode") private var lyricDisplayModeRaw = LyricDisplayMode.classic.rawValue
    @AppStorage("beans.showSongVIPBadge") private var showSongVIPBadge = true
    @AppStorage(LyricStageSettings.enabledKey) private var lyricStageEnabled = LyricStageSettings.defaultEnabled
    @AppStorage(LyricStageSettings.idKey) private var lyricStageID = LyricStageSettings.defaultID

    /// 上下切歌时整块内容滑出 / 滑回
    @State private var switchOffset: CGFloat = 0
    @State private var contentOpacity: Double = 1
    @State private var switching = false

    @State private var stageReady = false
    @State private var stageChromeVisible = false
    @State private var stageChromeTask: Task<Void, Never>?

    private let heartTint = Color(red: 0.99, green: 0.45, blue: 0.47)

    var body: some View {
        GeometryReader { geo in
            let layout = ImmersiveLayout(size: geo.size)
            // 兜底：正常情况下内容已经落在安全区内（inset 为 0），
            // 若某个呈现容器把整屏交给 GeometryReader，这里再补一次，避免顶栏再次压到状态栏。
            let extraTop = max(geo.safeAreaInsets.top, 0)
            let extraBottom = max(geo.safeAreaInsets.bottom, 0)

            ZStack(alignment: .bottom) {
                // 背景单独铺满整屏；内容仍留在安全区内，顶栏不会再压到状态栏
                ImmersiveBackdrop(songURL: song?.coverURL, isPlaying: player.isPlaying)
                    .ignoresSafeArea()

                pages(layout: layout)
                    .padding(.top, extraTop)
                    .padding(.bottom, layout.deckReserve + extraBottom)
                    .offset(y: switchOffset)
                    .opacity(contentOpacity)

                if !stageActive {
                    deck
                        .padding(.bottom, 6 + extraBottom)
                        .transition(.opacity)
                }

                // 舞台常驻：未就绪时用 0.001 透明度预热（opacity 0 会被 WebKit 判定不可见而暂停渲染），
                // 就绪后再整块顶上来，避免首次进入舞台黑屏。
                if stageConfigured {
                    stageLayer
                        .opacity(stageActive ? 1 : 0.001)
                        .allowsHitTesting(stageActive)
                        .zIndex(stageActive ? 3 : 0)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .animation(.easeInOut(duration: 0.28), value: stageActive)
        }
        .onChange(of: showLyrics) { _ in
            stageReady = false
            stageChromeVisible = false
            stageChromeTask?.cancel()
        }
        .onChange(of: lyricStageID) { _ in stageReady = false }
        .onChange(of: lyricStageEnabled) { _ in stageReady = false }
        .onChange(of: song?.identityKey) { _ in stageReady = false }
        .task(id: stageGateKey) {
            guard lyricStageEnabled, showLyrics else { return }
            guard LyricStageResources.url(for: lyricStageID) != nil, !lyrics.isEmpty else { return }
            try? await Task.sleep(nanoseconds: 2_400_000_000)
            guard !Task.isCancelled else { return }
            if !stageReady { stageReady = true }
        }
        .onDisappear { stageChromeTask?.cancel() }
    }

    // MARK: - 两个页面（封面 / 歌词）

    private func pages(layout: ImmersiveLayout) -> some View {
        ZStack {
            coverPage(layout: layout)
                .opacity(showLyrics ? 0 : 1)
                .offset(x: showLyrics ? -28 : 0)
                .allowsHitTesting(!showLyrics)

            lyricsPage
                .opacity(showLyrics ? 1 : 0)
                .offset(x: showLyrics ? 0 : 32)
                .allowsHitTesting(showLyrics)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.spring(response: 0.44, dampingFraction: 0.92), value: showLyrics)
    }

    private func coverPage(layout: ImmersiveLayout) -> some View {
        VStack(spacing: 0) {
            topBar
                .padding(.top, 4)

            Color.clear.frame(height: layout.topGap)

            coverArt(layout: layout)

            Color.clear.frame(height: layout.coverGap)

            infoBlock

            Color.clear.frame(height: 18)

            lyricPreview

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .simultaneousGesture(coverSwipeGesture)
    }

    // MARK: - 1. 顶部导航

    private var topBar: some View {
        HStack(spacing: 10) {
            GlassCircleButton(
                systemName: "chevron.down",
                size: 40,
                iconSize: 15,
                thickness: .thin,
                accessibility: "收起播放器"
            ) {
                onClose()
            }

            Spacer(minLength: 6)

            VStack(spacing: 3) {
                Text(stateText)
                    .font(BeansFont.appFont(10, .semibold))
                    .kerning(1.3)
                    .foregroundStyle(.white.opacity(0.46))
                Text(song?.album ?? "Z Music")
                    .font(BeansFont.appFont(12, .medium))
                    .foregroundStyle(.white.opacity(0.80))
                    .lineLimit(1)
            }
            .frame(maxWidth: 200)
            .contentShape(Rectangle())

            Spacer(minLength: 6)

            GlassCircleButton(
                systemName: "ellipsis",
                size: 40,
                iconSize: 15,
                thickness: .thin,
                accessibility: "更多操作"
            ) {
                onMore()
            }
        }
        .padding(.horizontal, 20)
    }

    private var stateText: String {
        if player.isBuffering { return "加载中" }
        return player.isPlaying ? "正在播放" : "已暂停"
    }

    // MARK: - 2. 封面

    private func coverArt(layout: ImmersiveLayout) -> some View {
        ImmersiveArtwork(url: song?.coverURL)
            .frame(width: layout.coverSide, height: layout.coverSide)
            .clipShape(RoundedRectangle(cornerRadius: layout.coverCorner, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: layout.coverCorner, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.24), .white.opacity(0.07), .white.opacity(0.14)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.7
                    )
            }
            .shadow(color: .black.opacity(0.42), radius: 28, y: 16)
            .contentShape(RoundedRectangle(cornerRadius: layout.coverCorner, style: .continuous))
            .onTapGesture(count: 2) {
                guard song != nil else { return }
                BeansHaptics.success()
                onFavorite()
            }
            .onTapGesture {
                openLyrics()
            }
            .scaleEffect(switching ? 0.975 : 1)
    }

    // MARK: - 3. 歌曲信息

    private var infoBlock: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 8) {
                    Text(song?.name ?? "未在播放")
                        .font(BeansFont.appFont(26, .bold))
                        .foregroundStyle(.white.opacity(0.97))
                        .lineLimit(2)
                        .minimumScaleFactor(0.72)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    if showSongVIPBadge, let badge = player.playbackSourceBadge {
                        PlaybackSourceBadge(text: badge, isSource: player.playbackBadgeIsSource)
                    }
                }

                Text(artistLine)
                    .font(BeansFont.appFont(13.5, .medium))
                    .foregroundStyle(.white.opacity(0.56))
                    .lineLimit(1)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        guard song != nil else { return }
                        BeansHaptics.tap()
                        onArtist()
                    }
            }

            Spacer(minLength: 0)

            GlassCircleButton(
                systemName: isFavorite ? "heart.fill" : "heart",
                size: 36,
                iconSize: 16,
                thickness: .thin,
                active: isFavorite,
                tint: heartTint,
                accessibility: isFavorite ? "取消收藏" : "收藏"
            ) {
                guard song != nil else { return }
                onQuickFavorite()
            }
        }
        .padding(.horizontal, 24)
    }

    private var artistLine: String {
        guard let song else { return "" }
        let names = song.artists
            .split(whereSeparator: { $0 == "/" || $0 == "&" || $0 == "、" })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return names.isEmpty ? "未知歌手" : names.joined(separator: " · ")
    }

    private var isFavorite: Bool {
        localLibrary.containsSong(song)
    }

    // MARK: - 4. 歌词预览

    private struct PreviewRow: Identifiable {
        let id: Int
        let text: String
        /// 与当前行的距离：0 = 正在唱，负数已唱过，正数还没到
        let distance: Int
    }

    private var lyricPreview: some View {
        let rows = previewRows
        return VStack(spacing: 10) {
            if rows.isEmpty {
                Text(lyrics.isEmpty ? "暂无歌词" : "轻点封面查看完整歌词")
                    .font(BeansFont.appFont(14, .regular))
                    .foregroundStyle(.white.opacity(0.28))
            } else {
                ForEach(rows) { row in
                    let gap = abs(row.distance)
                    let isCurrent = row.distance == 0
                    Text(row.text.isEmpty ? "♪" : row.text)
                        .font(BeansFont.appFont(isCurrent ? 20 : max(13.5, 16 - CGFloat(gap) * 1.2),
                                                isCurrent ? .semibold : .regular))
                        .foregroundStyle(.white.opacity(lyricPreviewOpacity(gap: gap, isCurrent: isCurrent)))
                        .shadow(color: isCurrent ? .white.opacity(0.22) : .clear, radius: 10)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                        .blur(radius: gap >= 2 ? 0.4 : 0)
                        .scaleEffect(isCurrent ? 1 : 0.985)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .frame(height: 132)
        .padding(.horizontal, 26)
        .contentShape(Rectangle())
        .onTapGesture { openLyrics() }
        .animation(.spring(response: 0.46, dampingFraction: 0.88), value: currentLyricIndex)
    }

    /// 当前行最亮，越远越淡；但保底 0.12，保证整块歌词仍有轮廓
    private func lyricPreviewOpacity(gap: Int, isCurrent: Bool) -> Double {
        if isCurrent { return 0.96 }
        return max(0.12, 0.40 - Double(gap - 1) * 0.11)
    }

    private var previewRows: [PreviewRow] {
        guard !lyrics.isEmpty else { return [] }
        let index = currentLyricIndex ?? 0
        var rows: [PreviewRow] = []
        for step in -2...2 {
            if step == 0 {
                rows.append(PreviewRow(id: index, text: lyrics[index].text, distance: 0))
                continue
            }
            guard let target = neighborIndex(from: index, step: step) else { continue }
            rows.append(PreviewRow(id: target, text: lyrics[target].text, distance: step))
        }
        return rows
    }

    private func neighborIndex(from index: Int, step: Int) -> Int? {
        var cursor = index + step
        while cursor >= 0 && cursor < lyrics.count {
            if !lyrics[cursor].text.trimmingCharacters(in: .whitespaces).isEmpty {
                return cursor
            }
            cursor += step
        }
        return nil
    }

    private var currentLyricIndex: Int? {
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

    // MARK: - 5/6. 底部：进度 + 控制

    private var deck: some View {
        VStack(spacing: 16) {
            ImmersiveScrubber()

            HStack(spacing: 0) {
                sideControl(
                    icon: player.playMode.icon,
                    active: player.playMode != .sequential,
                    accessibility: player.playMode.title
                ) {
                    player.togglePlayMode()
                }

                Spacer(minLength: 4)

                transportButton("backward.fill") {
                    switchSong(up: false)
                }

                playButton

                transportButton("forward.fill") {
                    switchSong(up: true)
                }

                Spacer(minLength: 4)

                sideControl(icon: "list.bullet", active: false, accessibility: "播放列表") {
                    onQueue()
                }
            }
            .frame(maxWidth: 396)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
    }

    /// 两侧次级控件：不做玻璃圆底，压低存在感，让视觉焦点留给封面与主播放键
    private func sideControl(
        icon: String,
        active: Bool,
        accessibility: String,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            BeansHaptics.tap()
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white.opacity(active ? 0.95 : 0.52))
                .frame(width: 46, height: 46)
                .contentShape(Rectangle())
        }
        .buttonStyle(LiquidGlassButtonStyle(scale: 0.90))
        .accessibilityLabel(accessibility)
    }

    private func transportButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button {
            BeansHaptics.tap()
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 25, weight: .semibold))
                .foregroundStyle(.white.opacity(0.88))
                .frame(width: 58, height: 72)
                .contentShape(Rectangle())
        }
        .buttonStyle(LiquidGlassButtonStyle(scale: 0.90))
    }

    private var playButton: some View {
        Button {
            BeansHaptics.tap()
            player.togglePlayPause()
        } label: {
            ZStack {
                LiquidGlassSurface(shape: Circle(), thickness: .floating)
                    .frame(width: 74, height: 74)
                PlayPauseMorphIcon(isPlaying: player.isPlaying, size: 26)
                    .foregroundStyle(.white.opacity(0.97))
                    .offset(x: player.isPlaying ? 0 : 1.5)
            }
            .shadow(color: .black.opacity(0.34), radius: 18, y: 10)
            .contentShape(Circle())
        }
        .buttonStyle(LiquidGlassButtonStyle(scale: 0.93))
        .accessibilityLabel(player.isPlaying ? "暂停" : "播放")
    }

    // MARK: - 歌词页

    private var lyricsPage: some View {
        VStack(spacing: 0) {
            lyricsHeader
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 10)

            if lyrics.isEmpty {
                emptyLyrics
            } else {
                LyricsSection(
                    lyrics: lyrics,
                    accent: .white,
                    secondary: .white.opacity(0.92),
                    gradientStart: nil,
                    gradientEnd: nil,
                    // 沉浸歌词：字号整体抬高，当前行再额外放大 8pt，形成 Apple Music 那种"一句压全场"的层次
                    baseFontSize: CGFloat(min(max(lyricFontSize, 18), 26)),
                    lineSpacing: CGFloat(min(max(lyricSpacing, 20), 40)),
                    glowRadius: 0,
                    showTranslation: lyricTranslation,
                    alignment: lyricAlignRaw == "left" ? .leading : .center,
                    offsetX: CGFloat(lyricOffsetX),
                    anchor: .center,
                    glowColorOverride: nil,
                    blurStart: 4,
                    blurAmount: 0.5,
                    tilt: 0,
                    tiltY: 0,
                    lyricOffset: CGFloat(lyricOffset),
                    displayMode: LyricDisplayMode(rawValue: lyricDisplayModeRaw) ?? .classic,
                    focusBoost: 8,
                    pendingOpacity: 0.42,
                    playedOpacity: 0.30,
                    focusScale: 1.02
                ) { line in
                    BeansHaptics.tap()
                    player.seek(to: LyricTiming.seekTime(for: line, userOffset: lyricOffset))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // 歌词页单独加一层极淡压暗：背景变得更通透后，保证长句仍然清晰
        .background {
            LinearGradient(
                colors: [.black.opacity(0.06), .black.opacity(0.20), .black.opacity(0.08)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .simultaneousGesture(lyricsSwipeBackGesture)
    }

    private var lyricsHeader: some View {
        HStack(spacing: 12) {
            Button {
                BeansHaptics.tap()
                showLyrics = false
            } label: {
                ImmersiveArtwork(url: song?.coverURL)
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .strokeBorder(.white.opacity(0.18), lineWidth: 0.7)
                    }
            }
            .buttonStyle(LiquidGlassButtonStyle(scale: 0.94))
            .accessibilityLabel("返回封面")

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 7) {
                    Text(song?.name ?? "未在播放")
                        .font(BeansFont.appFont(15, .semibold))
                        .foregroundStyle(.white.opacity(0.95))
                        .lineLimit(1)
                    if showSongVIPBadge, let badge = player.playbackSourceBadge {
                        PlaybackSourceBadge(text: badge, isSource: player.playbackBadgeIsSource)
                    }
                }
                Text(artistLine)
                    .font(BeansFont.appFont(11.5, .medium))
                    .foregroundStyle(.white.opacity(0.50))
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            GlassCircleButton(
                systemName: "sparkles",
                size: 36,
                iconSize: 14,
                thickness: .thin,
                accessibility: "歌词舞台"
            ) {
                onLyricStage()
            }

            GlassCircleButton(
                systemName: isFavorite ? "heart.fill" : "heart",
                size: 36,
                iconSize: 15,
                thickness: .thin,
                active: isFavorite,
                tint: heartTint,
                accessibility: isFavorite ? "取消收藏" : "收藏"
            ) {
                guard song != nil else { return }
                onQuickFavorite()
            }
        }
    }

    private var emptyLyrics: some View {
        VStack(spacing: 10) {
            Spacer(minLength: 0)
            Image(systemName: "quote.bubble")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(.white.opacity(0.26))
            Text("暂无歌词")
                .font(BeansFont.appFont(15, .semibold))
                .foregroundStyle(.white.opacity(0.72))
            Text("这首歌还没有可显示的歌词")
                .font(BeansFont.appFont(12))
                .foregroundStyle(.white.opacity(0.34))
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            BeansHaptics.tap()
            showLyrics = false
        }
    }

    // MARK: - 歌词舞台（全屏 WebView，轻点呼出极简控制层）

    private var stageConfigured: Bool {
        guard showLyrics, lyricStageEnabled, !lyrics.isEmpty else { return false }
        guard LyricStage.stage(id: lyricStageID) != nil else { return false }
        return LyricStageResources.url(for: lyricStageID) != nil
    }

    private var stageActive: Bool {
        stageConfigured && stageReady
    }

    private var stageGateKey: String {
        "immersive-stage-" + lyricStageID + "-" + (song?.identityKey ?? "") + "-" + (lyricStageEnabled ? "1" : "0") + "-" + (showLyrics ? "1" : "0")
    }

    @ViewBuilder
    private var stageLayer: some View {
        ZStack {
            if let stage = LyricStage.stage(id: lyricStageID) {
                LyricStageWebView(
                    stage: stage,
                    lines: lyrics,
                    progress: clock.progress,
                    isPlaying: player.isPlaying,
                    accentHex: nil,
                    onReady: { ok in
                        stageReady = ok
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { toggleStageChrome() }

            if stageChromeVisible {
                stageChrome
                    .transition(.opacity)
            }
        }
        .simultaneousGesture(lyricsSwipeBackGesture)
    }

    private var stageChrome: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                GlassCircleButton(systemName: "chevron.down", size: 38, iconSize: 15, thickness: .thin) {
                    showLyrics = false
                }
                Spacer(minLength: 0)
                GlassCircleButton(systemName: "gearshape", size: 38, iconSize: 15, thickness: .thin) {
                    onSettings()
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)

            Spacer(minLength: 0)

            VStack(spacing: 18) {
                ImmersiveScrubber()
                HStack(spacing: 34) {
                    transportButton("backward.fill") { switchSong(up: false) }
                    playButton
                    transportButton("forward.fill") { switchSong(up: true) }
                }
            }
            .padding(.horizontal, 26)
            .padding(.bottom, 18)
        }
        .background {
            VStack(spacing: 0) {
                LinearGradient(colors: [.black.opacity(0.45), .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: 140)
                Spacer(minLength: 0)
                LinearGradient(colors: [.clear, .black.opacity(0.62)], startPoint: .top, endPoint: .bottom)
                    .frame(height: 230)
            }
            .allowsHitTesting(false)
        }
    }

    private func toggleStageChrome() {
        if stageChromeVisible {
            stageChromeTask?.cancel()
            withAnimation(.easeInOut(duration: 0.18)) { stageChromeVisible = false }
        } else {
            showStageChromeTemporarily()
        }
    }

    private func showStageChromeTemporarily() {
        stageChromeTask?.cancel()
        withAnimation(.easeInOut(duration: 0.18)) { stageChromeVisible = true }
        stageChromeTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_200_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.32)) { stageChromeVisible = false }
        }
    }

    // MARK: - 交互

    private func openLyrics() {
        guard !lyrics.isEmpty else {
            ToastCenter.shared.show("暂无歌词")
            return
        }
        BeansHaptics.tap()
        showLyrics = true
    }

    /// 上下滑动 / 点按上一首下一首：内容滑出 → 换歌 → 从另一侧滑回
    private func switchSong(up: Bool) {
        guard !switching else { return }
        switching = true
        BeansHaptics.medium()
        let travel: CGFloat = 340
        let out: CGFloat = up ? -travel : travel
        withAnimation(.easeIn(duration: 0.17)) {
            switchOffset = out
            contentOpacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.17) {
            if up { player.next() } else { player.previous() }
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                switchOffset = -out
            }
            DispatchQueue.main.async {
                withAnimation(.spring(response: 0.42, dampingFraction: 0.90)) {
                    switchOffset = 0
                    contentOpacity = 1
                }
                switching = false
            }
        }
    }

    /// 封面手势：从左往右滑 = 收起；从右往左滑 = 歌词；上滑下一首、下滑上一首
    private var coverSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 20)
            .onEnded { value in
                let dx = value.translation.width
                let dy = value.translation.height
                let vx = value.predictedEndTranslation.width
                let vy = value.predictedEndTranslation.height
                guard max(abs(dx), abs(dy)) > 34 || max(abs(vx), abs(vy)) > 80 else { return }
                if abs(dx) > abs(dy) {
                    if dx > 0 || vx > 130 {
                        BeansHaptics.tap()
                        onClose()
                    } else {
                        openLyrics()
                    }
                } else {
                    switchSong(up: dy < 0)
                }
            }
    }

    /// 歌词页：从左往右滑回封面
    private var lyricsSwipeBackGesture: some Gesture {
        DragGesture(minimumDistance: 18)
            .onEnded { value in
                let dx = value.translation.width
                guard abs(dx) >= abs(value.translation.height),
                      dx > 52 || value.predictedEndTranslation.width > 110 else { return }
                BeansHaptics.tap()
                showLyrics = false
            }
    }
}

// MARK: - 布局常量

private struct ImmersiveLayout {
    let size: CGSize

    /// 封面尺寸：宽度优先，同时给信息、歌词和三段控制区留足空间。
    /// 屏幕越矮封面越小，保证任何机型都不会挤压播放控制。
    var coverSide: CGFloat {
        let widthLimit = max(size.width - 48, 132)
        let reserved: CGFloat = 44 + topGap + coverGap + 96 + 14 + 132 + deckReserve + 12
        let heightLimit = max(size.height - reserved, 132)
        return min(min(widthLimit, heightLimit), 400)
    }

    var coverCorner: CGFloat { 22 }
    var topGap: CGFloat { 14 }
    var coverGap: CGFloat { 22 }
    var deckReserve: CGFloat { 140 }
}

// MARK: - 进度条（细轨 + 拖动放大手柄，点击/拖动都可跳转）

struct ImmersiveScrubber: View {
    @EnvironmentObject private var player: PlayerManager
    @EnvironmentObject private var clock: PlaybackClock

    @State private var dragging = false
    @State private var dragRatio: Double = 0

    private var duration: Double {
        max(max(clock.duration, player.currentSong?.duration ?? 0), 1)
    }

    private var ratio: Double {
        if dragging { return dragRatio }
        return min(max(clock.progress / duration, 0), 1)
    }

    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                let width = max(geo.size.width, 1)
                let trackHeight: CGFloat = dragging ? 4 : 3
                let thumbSize: CGFloat = dragging ? 13 : 9
                let thumbX = min(max(width * CGFloat(ratio) - thumbSize / 2, 0), width - thumbSize)

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.15))
                        .frame(height: trackHeight)

                    Capsule()
                        .fill(Color.white.opacity(0.92))
                        .frame(width: max(width * CGFloat(ratio), trackHeight), height: trackHeight)

                    Circle()
                        .fill(Color.white)
                        .frame(width: thumbSize, height: thumbSize)
                        .offset(x: thumbX)
                        .shadow(color: .black.opacity(0.28), radius: 2, y: 1)
                }
                .frame(height: geo.size.height)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if !dragging {
                                dragging = true
                                BeansHaptics.tap()
                            }
                            dragRatio = min(max(Double(value.location.x / width), 0), 1)
                        }
                        .onEnded { value in
                            let target = min(max(Double(value.location.x / width), 0), 1)
                            player.seek(to: target * duration)
                            dragging = false
                        }
                )
                .animation(.easeOut(duration: 0.16), value: dragging)
            }
            .frame(height: 24)

            HStack(spacing: 0) {
                Text(beansTimeString(dragging ? dragRatio * duration : clock.progress))
                Spacer(minLength: 8)
                Text(beansTimeString(duration))
            }
            .font(BeansFont.appFont(10.5, .medium, .monospaced))
            .monospacedDigit()
            .foregroundStyle(.white.opacity(0.42))
        }
        .frame(maxWidth: 396)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 歌词元信息过滤
//
// LRC 里常见「作词 : xxx / 作曲 : xxx / 编曲 : xxx」，它们不是歌词。
// 直接混在歌词流里会破坏阅读节奏，这里在解析后统一剔除；若整首歌只有元信息则保留原文。

enum LyricCreditFilter {
    private static let roles: [String] = [
        "作词", "作曲", "编曲", "制作人", "监制", "出品", "录音", "混音", "母带",
        "和声", "吉他", "贝斯", "鼓", "键盘", "弦乐", "人声", "统筹", "企划", "发行",
        "Lyricist", "Composer", "Arranger", "Producer", "Mixing", "Mastering",
        "Written by", "Music by", "Lyrics by", "Produced by", "Mixed by"
    ]

    static func isCredit(_ raw: String) -> Bool {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text.count <= 90 else { return false }

        for separator in [":", "："] {
            if let range = text.range(of: separator) {
                let head = String(text[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
                guard head.count <= 14 else { continue }
                for role in roles where head.caseInsensitiveCompare(role) == .orderedSame || head.hasPrefix(role) {
                    return true
                }
            }
        }

        for role in roles where role.count >= 2 {
            if text.hasPrefix(role) { return true }
        }
        return false
    }

    static func sanitize(_ lines: [LyricLine], title: String? = nil, artist: String? = nil) -> [LyricLine] {
        var filtered = lines.filter { !isCredit($0.text) }
        filtered = dropLeadingMetadata(filtered, title: title, artist: artist)
        return filtered.isEmpty ? lines : filtered
    }

    /// 有些音源会在最前面塞一行「歌名 - 歌手」或残留 [ti:]/[ar:] 标签，同样不是歌词。
    /// 只看前两行，避免误删正文里出现歌名的句子。
    private static func dropLeadingMetadata(_ lines: [LyricLine], title: String?, artist: String?) -> [LyricLine] {
        let name = (title ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let singer = (artist ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let tags = ["[ti:", "[ar:", "[al:", "[by:", "[offset:", "ti:", "ar:"]

        var result = lines
        var dropped = 0
        while dropped < 2, let first = result.first {
            let text = first.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if text.isEmpty {
                result.removeFirst()
                dropped += 1
                continue
            }
            let lower = text.lowercased()
            let isTag = tags.contains { lower.hasPrefix($0) }
            let hasName = !name.isEmpty && lower.contains(name)
            let hasSinger = singer.isEmpty || lower.contains(singer)
            let isTitleLine = hasName && hasSinger && text.count <= 80
            guard isTag || isTitleLine else { break }
            result.removeFirst()
            dropped += 1
        }
        return result
    }
}
