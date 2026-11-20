import SwiftUI

/// 可视化诊断层：把真机上的真实尺寸直接画在屏幕上。
/// 用于定位 SwiftUI 嵌入 RN 时的布局问题（首帧尺寸、安全区、可用高度等）。
/// 截图即可读到数值，不需要连 Xcode。
struct LXDebugOverlay: View {
  let lines: [String]

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      ForEach(lines, id: \.self) { line in
        Text(line)
          .font(.system(size: 9, weight: .medium, design: .monospaced))
          .foregroundStyle(.white)
      }
    }
    .padding(6)
    .background(Color.red.opacity(0.85))
    .cornerRadius(6)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
    .padding(.trailing, 4)
    .padding(.top, 4)
    .allowsHitTesting(false)
  }
}

/// 读取 window 的 safeAreaInsets（供诊断显示）
func LXDiagInsets() -> String {
  guard let w = UIApplication.shared.connectedScenes
    .compactMap({ $0 as? UIWindowScene })
    .flatMap({ $0.windows })
    .first(where: { $0.isKeyWindow }) else { return "no-window" }
  let i = w.safeAreaInsets
  return String(format: "safe t%.0f b%.0f l%.0f r%.0f", i.top, i.bottom, i.left, i.right)
}
