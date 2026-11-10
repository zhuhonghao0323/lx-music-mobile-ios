import SwiftUI

/// 支持 "#RRGGBB" 与 "rgba(r,g,b,a)" 两种写法（RN 侧主题色就是这两种格式）
enum ColorParser {
  static func color(_ value: String, fallback: Color = .white) -> Color {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    if trimmed.hasPrefix("#") {
      var hex = String(trimmed.dropFirst())
      if hex.count == 3 {
        hex = hex.map { "\($0)\($0)" }.joined()
      }
      guard hex.count == 6, let intValue = UInt32(hex, radix: 16) else { return fallback }
      let r = Double((intValue >> 16) & 0xFF) / 255.0
      let g = Double((intValue >> 8) & 0xFF) / 255.0
      let b = Double(intValue & 0xFF) / 255.0
      return Color(red: r, green: g, blue: b)
    }
    if trimmed.hasPrefix("rgba(") || trimmed.hasPrefix("rgb(") {
      let inner = trimmed
        .replacingOccurrences(of: "rgba(", with: "")
        .replacingOccurrences(of: "rgb(", with: "")
        .replacingOccurrences(of: ")", with: "")
      let parts = inner.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
      if parts.count >= 3,
         let r = Double(parts[0]), let g = Double(parts[1]), let b = Double(parts[2]) {
        let a = parts.count >= 4 ? (Double(parts[3]) ?? 1.0) : 1.0
        return Color(red: r / 255.0, green: g / 255.0, blue: b / 255.0, opacity: a)
      }
    }
    return fallback
  }
}
