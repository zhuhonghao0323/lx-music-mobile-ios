import SwiftUI

/// 迷你播放栏的进度呈现方式
enum MiniPlayerProgressStyle: String, CaseIterable, Identifiable {
    case off
    case vertical
    case fill
    case bar

    var id: String { rawValue }

    var title: String {
        switch self {
        case .off: return "关闭"
        case .vertical: return "纵向水位"
        case .fill: return "横向填充"
        case .bar: return "横向线条"
        }
    }

    var caption: String {
        switch self {
        case .off: return "不显示任何进度装饰"
        case .vertical: return "卡片内自下而上的水位 + 波浪"
        case .fill: return "自左往右铺满卡片，右侧带流动波纹"
        case .bar: return "卡片底部一条细进度线"
        }
    }

    var icon: String {
        switch self {
        case .off: return "slash.circle"
        case .vertical: return "rectangle.portrait.fill"
        case .fill: return "rectangle.lefthalf.inset.filled"
        case .bar: return "capsule"
        }
    }
}

struct MiniPlayerView: View {
    enum Presentation {
        case dock
        case accessory

        var showsCardSurface: Bool { self == .dock }
    }

    @EnvironmentObject private var theme: ThemeStore
    @EnvironmentObject private var player: PlayerManager
    @EnvironmentObject private var clock: PlaybackClock
    @Environment(\.colorScheme) private var colorScheme
    @Binding var showPlayer: Bool
    var presentation: Presentation = .dock
    var transitionNamespace: Namespace.ID?
    @State private var miniLyrics: [LyricLine] = []
    @AppStorage("beans.lyricOffset") private var lyricOffset = 0.0
    @AppStorage("beans.uiStyle") private var uiStyleRaw = BeansUIStyle.liquid.rawValue
    @AppStorage("beans.showSongVIPBadge") private var showSongVIPBadge = true
    @AppStorage("beans.miniProgressStyle") private var miniProgressRaw = MiniPlayerProgressStyle.vertical.rawValue

    private var miniProgressStyle: MiniPlayerProgressStyle {
        MiniPlayerProgressStyle(rawValue: miniProgressRaw) ?? .vertical
    }

    private var coverSize: CGFloat { 36 }
    private var controlSize: CGFloat { 32 }
    private var containerRadius: CGFloat { 18 }
    private var verticalPadding: CGFloat { 4 }

    /// 二分查找当前播放到的歌词行（歌词按时间升序）
    private var currentLyricLine: LyricLine? {
        guard !miniLyrics.isEmpty else { return nil }
        var low = 0
        var high = miniLyrics.count - 1
        var answer: LyricLine?
        while low <= high {
            let mid = (low + high) / 2
            if miniLyrics[mid].time <= LyricTiming.effectiveProgress(clock.progress, userOffset: lyricOffset) {
                answer = miniLyrics[mid]
                low = mid + 1
            } else {
                high = mid - 1
            }
        }
        return answer
    }

    var body: some View {
        let _ = theme.accent
        Button {
            BeansHaptics.tap()
            showPlayer = true
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(theme.accent.highlight.opacity(0.32))
                        .frame(width: 42, height: 42)
                        .blur(radius: 9)
                    CoverImage(url: player.currentSong?.coverURL, size: coverSize, cornerRadius: 7)
                }
                .frame(width: 42, height: 42)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Text(player.currentSong?.name ?? "")
                            .font(BeansFont.appFont(12, .semibold))
                            .foregroundStyle(Color.beansLabel)
                            .lineLimit(1)
                        if showSongVIPBadge, player.currentSong?.isVIP == true {
                            Text("VIP")
                                .font(BeansFont.appFont(8, .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1.5)
                                .background(Capsule().fill(Color(red: 0.93, green: 0.25, blue: 0.22)))
                        }
                    }
                    Text(currentLyricLine?.text ?? player.currentSong?.artists ?? "")
                        .font(BeansFont.appFont(10))
                        .foregroundStyle(Color.beansComment)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .animation(.easeInOut(duration: 0.25), value: currentLyricLine?.text)
                }
                Spacer(minLength: 8)
                Button {
                    BeansHaptics.tap()
                    player.previous()
                } label: {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.beansLabel)
                        .frame(width: controlSize, height: controlSize)
                        .contentShape(Circle())
                }
                .buttonStyle(GlassPressButtonStyle())
                Button {
                    BeansHaptics.tap()
                    player.togglePlayPause()
                } label: {
                    PlayPauseMorphIcon(isPlaying: player.isPlaying, size: 16)
                        .foregroundStyle(Color.beansLabel)
                        .frame(width: controlSize, height: controlSize)
                        .contentShape(Circle())
                }
                .buttonStyle(GlassPressButtonStyle())
                Button {
                    BeansHaptics.tap()
                    player.next()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.beansLabel)
                        .frame(width: controlSize, height: controlSize)
                        .contentShape(Circle())
                }
                .buttonStyle(GlassPressButtonStyle())
            }
            .padding(.leading, 10)
            .padding(.trailing, 6)
            .padding(.vertical, verticalPadding)
            .background {
                ZStack {
                    if presentation.showsCardSurface {
                        // 普通底部浮层：保留卡片质感与阴影。
                        BeansGlass(
                            shape: RoundedRectangle(cornerRadius: containerRadius, style: .continuous),
                            forceLiquid: false
                        )
                        .overlay {
                            LinearGradient(
                                colors: [.white.opacity(0.25), .clear, .white.opacity(0.05)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: containerRadius, style: .continuous)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [.white.opacity(0.45), .white.opacity(0.08)],
                                        startPoint: .top, endPoint: .bottom
                                    ),
                                    lineWidth: 0.8
                                )
                        }
                    } else {
                        // 进入底栏 accessory 时不再叠一层卡片，交给系统/底栏容器去承载。
                        RoundedRectangle(cornerRadius: containerRadius, style: .continuous)
                            .fill(.clear)
                    }

                    // 播放进度：纵向水位 / 横向填充 / 底部线条，可在播放设置里切换
                    switch miniProgressStyle {
                    case .off:
                        EmptyView()
                    case .vertical:
                        MiniPlayerProgressFill(
                            progress: clock.duration > 0 ? clock.progress / clock.duration : 0,
                            isPlaying: player.isPlaying,
                            style: BeansUIStyle(rawValue: uiStyleRaw) ?? .liquid,
                            colorScheme: colorScheme
                        )
                        .clipShape(RoundedRectangle(cornerRadius: containerRadius, style: .continuous))
                        .allowsHitTesting(false)
                    case .fill:
                        MiniPlayerProgressFill(
                            progress: clock.duration > 0 ? clock.progress / clock.duration : 0,
                            isPlaying: player.isPlaying,
                            style: BeansUIStyle(rawValue: uiStyleRaw) ?? .liquid,
                            colorScheme: colorScheme,
                            horizontal: true
                        )
                        .clipShape(RoundedRectangle(cornerRadius: containerRadius, style: .continuous))
                        .allowsHitTesting(false)
                    case .bar:
                        MiniPlayerProgressBar(
                            progress: clock.duration > 0 ? clock.progress / clock.duration : 0,
                            isPlaying: player.isPlaying,
                            style: BeansUIStyle(rawValue: uiStyleRaw) ?? .liquid,
                            colorScheme: colorScheme
                        )
                        .allowsHitTesting(false)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: containerRadius, style: .continuous))
            .shadow(color: presentation.showsCardSurface ? .black.opacity(0.16) : .clear, radius: 12, y: 6)
            .scaleEffect(showPlayer ? 0.985 : 1)
            .animation(.spring(response: 0.34, dampingFraction: 0.86), value: showPlayer)
        }
        .buttonStyle(GlassPressButtonStyle(scale: 0.97))
        .transitionSource(in: transitionNamespace)
        .padding(.horizontal, presentation.showsCardSurface ? 12 : 0)
        .task(id: player.currentSong?.identityKey) {
            await loadMiniLyrics()
        }
    }

    private func loadMiniLyrics() async {
        miniLyrics = []
        guard let song = player.currentSong else { return }
        let identity = song.identityKey
        var raw: String?
        if song.source == .kugou, let hash = song.kugouHash {
            raw = await KugouMusicAPI.shared.lyric(hash: hash, duration: song.duration)
        } else if song.source == .migu {
            raw = await MiguMusicAPI.shared.lyric(urlString: song.miguLyricUrl)
        } else if song.source == .bodian {
            raw = await BodianMusicAPI.shared.lyric(id: song.id)
        } else if song.source == .qq, let mid = song.qqMid {
            raw = try? await QQMusicAPI.shared.lyric(songmid: mid)
        } else {
            raw = try? await NetEaseAPI.shared.lyric(id: song.id)
        }
        guard let raw else { return }
        guard player.currentSong?.identityKey == identity else { return }
        miniLyrics = LyricParser.parse(raw)
    }
}

enum BeansNowPlayingTransitionID {
    static let surface = "beans-now-playing-surface"
}

private struct BeansTransitionSourceModifier: ViewModifier {
    let namespace: Namespace.ID?

    @ViewBuilder
    func body(content: Content) -> some View {
        if let namespace, #available(iOS 18.0, *) {
            content.matchedTransitionSource(
                id: BeansNowPlayingTransitionID.surface,
                in: namespace
            )
        } else {
            content
        }
    }
}

private extension View {
    @ViewBuilder
    func transitionSource(in namespace: Namespace.ID?) -> some View {
        modifier(BeansTransitionSourceModifier(namespace: namespace))
    }
}


// MARK: - 迷你播放器进度填充

/// 卡片内部的进度装饰：
/// - 纵向（默认）：高度跟随播放进度，水面用正弦波缓慢流动
/// - 横向（horizontal = true）：自左往右铺满，右侧边缘是流动的波纹
/// 配色按四种 UI 风格 + 深浅色分别调过，都是低透明度，避免抢内容。
private struct MiniPlayerProgressFill: View {
    let progress: Double
    let isPlaying: Bool
    let style: BeansUIStyle
    let colorScheme: ColorScheme
    var horizontal: Bool = false

    private var clamped: CGFloat { CGFloat(min(max(progress, 0), 1)) }

    private var fillTint: Color {
        let accent = Color.beansAmber
        switch style {
        case .liquid:
            return accent.opacity(colorScheme == .dark ? 0.26 : 0.16)
        case .clear:
            return accent.opacity(colorScheme == .dark ? 0.22 : 0.14)
        case .compact:
            return accent.opacity(colorScheme == .dark ? 0.18 : 0.11)
        case .nativeClean:
            return accent.opacity(colorScheme == .dark ? 0.24 : 0.13)
        }
    }

    private var crestColor: Color {
        switch style {
        case .liquid, .clear:
            return .white.opacity(colorScheme == .dark ? 0.16 : 0.30)
        case .compact:
            return .white.opacity(colorScheme == .dark ? 0.10 : 0.22)
        case .nativeClean:
            return Color.beansAmber.opacity(colorScheme == .dark ? 0.22 : 0.16)
        }
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: !isPlaying)) { timeline in
            let phase = CGFloat(timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 120))
            GeometryReader { geo in
                if horizontal {
                    ZStack(alignment: .leading) {
                        if clamped > 0.001 {
                            WaveEdgeShape(
                                level: geo.size.width * clamped,
                                phase: phase,
                                amplitude: isPlaying ? 2.6 : 1.1
                            )
                            .fill(
                                LinearGradient(
                                    colors: [fillTint.opacity(0.35), fillTint],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                            WaveEdgeShape(
                                level: geo.size.width * clamped,
                                phase: phase + 1.7,
                                amplitude: isPlaying ? 2.6 : 1.1
                            )
                            .stroke(crestColor, lineWidth: 0.9)
                            .blendMode(.plusLighter)
                            .opacity(0.6)
                        }
                    }
                    .frame(width: geo.size.width, height: geo.size.height, alignment: .leading)
                } else {
                    let height = geo.size.height
                    let level = height * clamped
                    ZStack(alignment: .bottom) {
                        if clamped > 0.001 {
                            WaveFillShape(level: level, phase: phase, amplitude: isPlaying ? 2.4 : 1.0)
                                .fill(
                                    LinearGradient(
                                        colors: [fillTint.opacity(0.55), fillTint],
                                        startPoint: .top, endPoint: .bottom
                                    )
                                )
                            WaveFillShape(level: level, phase: phase + 1.7, amplitude: isPlaying ? 2.4 : 1.0)
                                .stroke(crestColor, lineWidth: 0.9)
                                .blendMode(.plusLighter)
                                .opacity(0.6)
                        }
                    }
                    .frame(width: geo.size.width, height: height, alignment: .bottom)
                }
            }
        }
        .animation(.easeInOut(duration: 0.28), value: clamped)
    }
}

/// 卡片底部横向细进度线
private struct MiniPlayerProgressBar: View {
    let progress: Double
    let isPlaying: Bool
    let style: BeansUIStyle
    let colorScheme: ColorScheme

    private var clamped: CGFloat { CGFloat(min(max(progress, 0), 1)) }

    private var tint: Color {
        switch style {
        case .liquid, .clear:
            return Color.beansAmber.opacity(colorScheme == .dark ? 0.85 : 0.75)
        case .compact:
            return Color.beansAmber.opacity(colorScheme == .dark ? 0.7 : 0.62)
        case .nativeClean:
            return Color.beansAmber.opacity(colorScheme == .dark ? 0.9 : 0.8)
        }
    }

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.08))
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [tint.opacity(0.55), tint],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .frame(width: max(0, width * clamped))
                    .shadow(color: tint.opacity(isPlaying ? 0.45 : 0), radius: 4)
            }
            .frame(height: 2.5)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .padding(.horizontal, 12)
            .padding(.bottom, 3)
        }
        .animation(.easeInOut(duration: 0.28), value: clamped)
    }
}

/// 自左往右的填充形状，右边缘是一条正弦波纹
private struct WaveEdgeShape: Shape {
    var level: CGFloat
    var phase: CGFloat
    var amplitude: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        let edge = max(0, min(width, level))
        let amplitude = min(amplitude, max(0.6, edge * 0.06))
        let wavelength = max(height * 0.55, 26)

        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: edge, y: 0))
        var y: CGFloat = 0
        while y <= height {
            let x = edge + sin((y / wavelength) * .pi * 2 + phase) * amplitude
            path.addLine(to: CGPoint(x: min(max(x, 0), width), y: y))
            y += 2
        }
        path.addLine(to: CGPoint(x: 0, y: height))
        path.closeSubpath()
        return path
    }
}

private struct WaveFillShape: Shape {
    var level: CGFloat
    var phase: CGFloat
    var amplitude: CGFloat
    /// 波长占宽度的比例
    var wavelengthRatio: CGFloat = 1.15

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        let surfaceY = height - level
        let amplitude = min(amplitude, max(0.6, level * 0.5))
        let wavelength = max(width * wavelengthRatio, 40)

        path.move(to: CGPoint(x: 0, y: height))
        path.addLine(to: CGPoint(x: 0, y: surfaceY))
        var x: CGFloat = 0
        while x <= width {
            let y = surfaceY + sin((x / wavelength) * .pi * 2 + phase) * amplitude
            path.addLine(to: CGPoint(x: x, y: y))
            x += 2
        }
        path.addLine(to: CGPoint(x: width, y: height))
        path.closeSubpath()
        return path
    }
}
