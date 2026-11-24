import SwiftUI

// MARK: - Beans Liquid Glass 材质系统
//
// 设计目标：一套可复用的玻璃材质，让播放器里的悬浮控件在 iOS 17~25 与 iOS 26+
// 上呈现一致的层级、透明度与边缘质感，而不是各页面自己写 `Circle().fill(.white.opacity(0.1))`。
//
// - iOS 26+：直接使用系统原生 Liquid Glass（`glassEffect`），跟随系统折射与高光。
// - iOS 17~25：用 `ultraThinMaterial` + 顶部镜面高光 + 单像素边缘描边模拟，
//   三者的参数按「厚度」统一收敛，避免每个按钮手工调数值。
//
// 注意：这里只负责"材质"，不负责布局尺寸；调用方用 frame 决定大小。

/// 玻璃厚度：决定模糊强度、填充亮度与边缘高光的强弱。
enum BeansGlassThickness {
    /// 轻薄：顶栏图标按钮等次级控件
    case thin
    /// 标准：控制行两侧的模式 / 播放列表按钮
    case regular
    /// 悬浮：主播放按钮、浮层等需要"浮起来"的控件
    case floating

    /// 旧系统上叠加的白色填充（越厚越亮）
    /// floating 与 regular 差距保持 2 倍以上，保证主播放键在深色背景上是唯一的高亮面。
    var fillWhite: Double {
        switch self {
        case .thin: return 0.055
        case .regular: return 0.075
        case .floating: return 0.150
        }
    }

    /// 旧系统上的顶部镜面高光
    var topHighlight: Double {
        switch self {
        case .thin: return 0.16
        case .regular: return 0.20
        case .floating: return 0.34
        }
    }

    var rimHighlight: Double {
        switch self {
        case .thin: return 0.20
        case .regular: return 0.24
        case .floating: return 0.36
        }
    }
}

/// 通用玻璃表面。只画材质，不处理点击。
struct LiquidGlassSurface<S: InsettableShape>: View {
    let shape: S
    var thickness: BeansGlassThickness = .regular
    /// 可选染色（跟随封面主色时传入），透明度由材质自身控制
    var tint: Color? = nil

    var body: some View {
        Group {
            if #available(iOS 26.0, *) {
                GlassEffectContainer {
                    shape
                        .fill(.clear)
                        .glassEffect(nativeGlass, in: shape)
                }
            } else {
                legacySurface
            }
        }
    }

    /// iOS 26 原生玻璃：薄/标准/悬浮分别映射到 clear / regular / regular+tint。
    @available(iOS 26.0, *)
    private var nativeGlass: Glass {
        switch thickness {
        case .thin:
            if let tint { return Glass.clear.tint(tint.opacity(0.35)) }
            return Glass.clear
        case .regular:
            if let tint { return Glass.regular.tint(tint.opacity(0.30)) }
            return Glass.regular
        case .floating:
            if let tint { return Glass.regular.tint(tint.opacity(0.22)) }
            return Glass.regular
        }
    }

    /// iOS 17~25 兼容实现：材质模糊 + 白色填充 + 顶部高光 + 细描边。
    private var legacySurface: some View {
        ZStack {
            shape.fill(.ultraThinMaterial)
            shape.fill(Color.white.opacity(thickness.fillWhite))
            if let tint {
                shape.fill(tint.opacity(0.08))
            }
            shape.fill(
                LinearGradient(
                    colors: [.white.opacity(thickness.topHighlight), .white.opacity(0.02), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            shape.strokeBorder(
                LinearGradient(
                    colors: [
                        .white.opacity(thickness.rimHighlight),
                        .white.opacity(0.10),
                        .white.opacity(thickness.rimHighlight * 0.72)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 0.7
            )
        }
    }
}

/// 控件按压反馈：轻微缩放 + 提亮，松手用短弹簧回弹。
/// 与全局 `GlassPressButtonStyle` 区分开，播放器要更"轻"的手感。
struct LiquidGlassButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.94

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .brightness(configuration.isPressed ? 0.045 : 0)
            .animation(.spring(response: 0.26, dampingFraction: 0.80), value: configuration.isPressed)
    }
}

/// 圆形玻璃图标按钮（顶栏 / 控制行两侧共用）
struct GlassCircleButton: View {
    let systemName: String
    var size: CGFloat = 40
    var iconSize: CGFloat = 15
    var thickness: BeansGlassThickness = .thin
    var active: Bool = false
    var tint: Color = .white
    var accessibility: String? = nil
    let action: () -> Void

    var body: some View {
        Button {
            BeansHaptics.tap()
            action()
        } label: {
            Image(systemName: systemName)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(active ? Color.white : Color.white.opacity(0.86))
                .frame(width: size, height: size)
                .background {
                    LiquidGlassSurface(shape: Circle(), thickness: thickness, tint: active ? tint : nil)
                }
                .overlay {
                    if active {
                        Circle().strokeBorder(tint.opacity(0.55), lineWidth: 0.8)
                    }
                }
                .contentShape(Circle())
        }
        .buttonStyle(LiquidGlassButtonStyle())
        .accessibilityLabel(accessibility ?? "")
    }
}
