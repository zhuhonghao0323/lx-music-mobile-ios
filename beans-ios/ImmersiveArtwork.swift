import SwiftUI
import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

// MARK: - 沉浸式播放器的封面配色与动态背景
//
// 背景不是"把封面放大再模糊"就算完：
// 1. 取封面主色，派生出「底色 / 雾光 / 强调色」三档；
// 2. 把封面缩到 300px 后做一次高斯模糊并缓存（整屏实时模糊是发热大头，这里只在切歌时算一次）；
// 3. 底色层 + 模糊封面层 + 顶部色雾 + 上下压暗，四层叠出"封面长在背景里"的通透感；
// 4. 切歌时新旧两层交叉淡入淡出，颜色与图片都不会硬切。

struct ImmersivePalette: Equatable {
    /// 强调色：播放按钮染色、进度条高光
    var accent: Color
    /// 雾光：顶部色雾与底部环境光
    var glow: Color
    /// 底色：整页暗部基调（保持封面色相，但压到很低亮度）
    var base: Color
    /// 封面是否偏亮：亮封面要把模糊层压下去、把顶部压暗加强，否则白色文字和玻璃按钮会糊在背景里
    var isLight: Bool = false

    static let fallback = ImmersivePalette(
        accent: Color(red: 0.96, green: 0.78, blue: 0.42),
        glow: Color(red: 0.30, green: 0.22, blue: 0.12),
        base: Color(red: 0.10, green: 0.08, blue: 0.07),
        isLight: false
    )

    static func make(from color: RGBColor?) -> ImmersivePalette {
        guard let color else { return .fallback }
        let hsl = color.toHSL()
        let base = RGBColor.fromHSL(
            h: hsl.h,
            s: min(max(hsl.s * 0.85, 0.20), 0.52),
            l: 0.16
        )
        let glow = RGBColor.fromHSL(
            h: hsl.h,
            s: min(max(hsl.s, 0.28), 0.82),
            l: 0.34
        )
        let accent = RGBColor.fromHSL(
            h: hsl.h,
            s: min(max(hsl.s * 1.05, 0.38), 0.88),
            l: 0.70
        )
        return ImmersivePalette(
            accent: accent.color,
            glow: glow.color,
            base: base.color,
            isLight: hsl.l > 0.60
        )
    }
}

// MARK: - 缓存与加载

private final class ImmersivePaletteBox: NSObject {
    let value: ImmersivePalette
    init(_ value: ImmersivePalette) { self.value = value }
}

enum ImmersiveArtworkCache {
    private static let images = NSCache<NSURL, UIImage>()
    private static let palettes = NSCache<NSURL, ImmersivePaletteBox>()
    private static let queue = DispatchQueue(label: "beans.immersive.artwork", qos: .utility)
    private static let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    static func cached(_ url: URL) -> (UIImage, ImmersivePalette)? {
        guard let image = images.object(forKey: url as NSURL),
              let palette = palettes.object(forKey: url as NSURL) else { return nil }
        return (image, palette.value)
    }

    static func load(url: URL, completion: @escaping (UIImage, ImmersivePalette) -> Void) {
        if let cached = cached(url) {
            completion(cached.0, cached.1)
            return
        }
        Task {
            guard let source = await CoverThumbCache.shared.image(for: url, maxPixel: 600) else { return }
            queue.async {
                let small = source.preparingThumbnail(of: CGSize(width: 300, height: 300)) ?? source
                let palette = ImmersivePalette.make(from: PaletteExtractor.dominantColor(in: small))
                let blurred = blur(small, radius: 22) ?? small
                images.setObject(blurred, forKey: url as NSURL)
                palettes.setObject(ImmersivePaletteBox(palette), forKey: url as NSURL)
                DispatchQueue.main.async {
                    completion(blurred, palette)
                }
            }
        }
    }

    private static func blur(_ image: UIImage, radius: Double) -> UIImage? {
        guard let input = CIImage(image: image) else { return nil }
        let filter = CIFilter.gaussianBlur()
        filter.inputImage = input
        filter.radius = Float(radius)
        guard let output = filter.outputImage else { return nil }
        let extent = output.extent
        guard extent.width > 0, extent.height > 0,
              let cg = ciContext.createCGImage(output, from: extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}

// MARK: - 动态背景

struct ImmersiveBackdrop: View {
    let songURL: URL?
    /// 播放中时背景做极慢的呼吸位移，让画面"活"起来；暂停则完全静止
    var isPlaying: Bool = false

    private struct Layer: Identifiable {
        let id: String
        let image: UIImage
        let palette: ImmersivePalette
    }

    @State private var current: Layer?
    @State private var previous: Layer?
    /// 0 → 1 的交叉淡入进度
    @State private var fade: Double = 1
    @State private var activeKey = ""
    /// 0 → 1 的呼吸进度（只驱动轻微的缩放与光晕强弱）
    @State private var breath: CGFloat = 0.5

    private var palette: ImmersivePalette {
        current?.palette ?? .fallback
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                Color.black

                if let previous {
                    baseWash(previous.palette, w: w, h: h).opacity(1 - fade)
                }
                if let current {
                    baseWash(current.palette, w: w, h: h).opacity(fade)
                }

                // 大色团：把封面主色扩散成整屏光晕，这一层决定"有没有颜色"
                if let previous {
                    bloom(previous.palette, w: w, h: h).opacity(1 - fade)
                }
                if let current {
                    bloom(current.palette, w: w, h: h).opacity(fade)
                }

                if let previous {
                    artwork(previous.image, palette: previous.palette, w: w, h: h)
                        .opacity(artworkOpacity(previous.palette) * (1 - fade))
                }
                if let current {
                    artwork(current.image, palette: current.palette, w: w, h: h)
                        .opacity(artworkOpacity(current.palette) * fade)
                }

                scrims(w: w, h: h)
            }
            .frame(width: w, height: h)
            .clipped()
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onAppear {
            load(songURL)
            startBreathing()
        }
        .onChange(of: songURL) { newValue in load(newValue) }
        .onChange(of: isPlaying) { _ in startBreathing() }
    }

    // MARK: 图层

    /// 底色：只压到"能看清白字"的程度，中间段刻意放开，让模糊封面与光晕透上来。
    private func baseWash(_ palette: ImmersivePalette, w: CGFloat, h: CGFloat) -> some View {
        ZStack {
            LinearGradient(
                stops: [
                    .init(color: palette.base.opacity(0.88), location: 0.00),
                    .init(color: palette.base.opacity(0.52), location: 0.26),
                    .init(color: palette.base.opacity(0.40), location: 0.60),
                    .init(color: palette.base.opacity(0.72), location: 0.84),
                    .init(color: .black.opacity(0.94), location: 1.00)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            RadialGradient(
                colors: [palette.glow.opacity(0.52), palette.glow.opacity(0.14), .clear],
                center: UnitPoint(x: 0.5, y: 0.12),
                startRadius: 0,
                endRadius: max(w, h) * 0.62
            )
        }
    }

    /// 主色色团：两个偏心径向渐变叠出"封面把颜色染到整个屏幕"的感觉
    private func bloom(_ palette: ImmersivePalette, w: CGFloat, h: CGFloat) -> some View {
        ZStack {
            RadialGradient(
                colors: [palette.accent.opacity(0.34 * (0.82 + 0.18 * Double(breath))),
                         palette.accent.opacity(0.10), .clear],
                center: UnitPoint(x: 0.30, y: 0.22),
                startRadius: 0,
                endRadius: max(w, h) * 0.52
            )
            RadialGradient(
                colors: [palette.glow.opacity(0.46), palette.glow.opacity(0.12), .clear],
                center: UnitPoint(x: 0.76, y: 0.62),
                startRadius: 0,
                endRadius: max(w, h) * 0.58
            )
        }
        .blendMode(.plusLighter)
    }

    /// 亮封面少给一点模糊层，让底色透出来，白字才有对比
    private func artworkOpacity(_ palette: ImmersivePalette) -> Double {
        palette.isLight ? 0.62 : 0.86
    }

    /// 模糊封面：整屏铺满、上下渐隐，是沉浸感的主体
    private func artwork(_ image: UIImage, palette: ImmersivePalette, w: CGFloat, h: CGFloat) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(width: w * 1.90, height: h * 1.06)
            .blur(radius: 14)
            .saturation(1.38)
            .contrast(1.04)
            .brightness(palette.isLight ? -0.06 : 0.01)
            .scaleEffect(1 + 0.035 * breath)
            .offset(y: -h * 0.05)
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .black.opacity(0.55), location: 0.00),
                        .init(color: .black, location: 0.18),
                        .init(color: .black, location: 0.58),
                        .init(color: .black.opacity(0.55), location: 0.80),
                        .init(color: .clear, location: 0.97)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
    }

    /// 可读性压暗：只在真正的边缘（状态栏 / 控制区）加，中间不再压黑
    private func scrims(w: CGFloat, h: CGFloat) -> some View {
        ZStack {
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(palette.isLight ? 0.62 : 0.50), location: 0.00),
                    .init(color: .black.opacity(palette.isLight ? 0.20 : 0.10), location: 0.14),
                    .init(color: .clear, location: 0.30),
                    .init(color: .clear, location: 0.56),
                    .init(color: palette.base.opacity(0.38), location: 0.72),
                    .init(color: .black.opacity(0.62), location: 0.88),
                    .init(color: .black.opacity(0.86), location: 1.00)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            RadialGradient(
                colors: [palette.accent.opacity(0.16), .clear],
                center: UnitPoint(x: 0.5, y: 0.94),
                startRadius: 0,
                endRadius: max(w, h) * 0.46
            )
        }
    }

    // MARK: 呼吸

    private func startBreathing() {
        guard isPlaying else {
            withAnimation(.easeOut(duration: 0.8)) { breath = 0.5 }
            return
        }
        breath = 0.15
        withAnimation(.easeInOut(duration: 9).repeatForever(autoreverses: true)) {
            breath = 1
        }
    }

    // MARK: 加载

    private func load(_ url: URL?) {
        let key = url?.absoluteString ?? ""
        guard key != activeKey else { return }
        activeKey = key

        guard let url else {
            current = nil
            previous = nil
            return
        }

        if let cached = ImmersiveArtworkCache.cached(url) {
            apply(image: cached.0, palette: cached.1, key: key)
            return
        }

        ImmersiveArtworkCache.load(url: url) { image, palette in
            guard activeKey == key else { return }
            apply(image: image, palette: palette, key: key)
        }
    }

    private func apply(image: UIImage, palette: ImmersivePalette, key: String) {
        let layer = Layer(id: key, image: image, palette: palette)
        guard current != nil else {
            current = layer
            fade = 1
            return
        }
        previous = current
        current = layer
        fade = 0
        withAnimation(.easeInOut(duration: 0.62)) { fade = 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.72) {
            if current?.id == key { previous = nil }
        }
    }
}

// MARK: - 大封面

/// 播放器主封面：缓存命中时直接显示（不闪黑），新图加载完后交叉淡入；尺寸由外层固定，不参与自适应。
struct ImmersiveArtwork: View {
    let url: URL?

    @State private var image: UIImage?
    @State private var key = ""

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .id(key)
                    .transition(.opacity)
            } else {
                LinearGradient(
                    colors: [Color.white.opacity(0.07), Color.white.opacity(0.02)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        .animation(.easeInOut(duration: 0.42), value: key)
        .task(id: url?.absoluteString ?? "") { await load() }
    }

    private func load() async {
        guard let url else {
            image = nil
            key = ""
            return
        }
        let target = url.absoluteString
        if let cached = CoverThumbCache.shared.memoryImage(for: url, maxPixel: 1400) {
            apply(cached, key: target)
            return
        }
        let loaded = await CoverThumbCache.shared.image(for: url, maxPixel: 1400)
        guard !Task.isCancelled, let loaded else { return }
        apply(loaded, key: target)
    }

    private func apply(_ newImage: UIImage, key target: String) {
        if key == target, image != nil {
            image = newImage
            return
        }
        key = target
        image = newImage
    }
}
