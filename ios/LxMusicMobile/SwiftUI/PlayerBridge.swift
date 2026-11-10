import Foundation
import Combine
import UIKit

/// 播放页桥接所需的最小状态集合。
/// 由 RN 侧 JS 通过 `SwiftUIPlayerModule.updateState` 推送过来，
/// SwiftUI 只负责渲染 + 下发命令，业务逻辑仍全部留在 RN。
final class PlayerBridge: ObservableObject {
  static let shared = PlayerBridge()

  // MARK: - 状态（RN 推送）
  @Published var title: String = ""
  @Published var artist: String = ""
  @Published var picUrl: String = ""
  @Published var isPlaying: Bool = false
  @Published var favorited: Bool = false

  @Published var currentTime: Double = 0
  @Published var duration: Double = 0
  @Published var progress: Double = 0
  @Published var buffered: Double = 0
  @Published var currentTimeText: String = "00:00"
  @Published var durationText: String = "00:00"

  /// 三行歌词：上一句 / 当前句 / 下一句
  @Published var lyricPrev: String = ""
  @Published var lyricCurrent: String = ""
  @Published var lyricNext: String = ""

  /// 当前自定义音源名称
  @Published var sourceName: String = ""
  /// 当前音质展示文案，例如 320kbps
  @Published var qualityText: String = ""

  /// 弹窗数据：可选音源列表 / 可选音质列表（由 RN 推来，SwiftUI 直接渲染）
  @Published var sourceOptions: [[String: String]] = []
  @Published var currentSourceId: String = ""
  @Published var currentQuality: String = ""
  @Published var playModeText: String = ""
  /// 音质可选列表（[{value,label}]）
  @Published var qualityOptionList: [[String: String]] = []

  /// 主题语义色（由 RN 换算好推过来，避免 Swift 端再实现一套主题系统）
  @Published var backgroundColor: String = "#0D0D0C"
  @Published var cardColor: String = "#121111"
  @Published var primaryColor: String = "#EB4D44"
  @Published var fontColor: String = "#FEFEFE"
  @Published var fontLabelColor: String = "rgba(255,255,255,0.65)"
  @Published var isDark: Bool = true

  /// 歌词预览外观
  @Published var lyricColor: String = "#ffffff"
  @Published var lyricFontSize: Double = 15

  // MARK: - 命令（Swift → RN）
  /// 由原生视图创建时注入，用于把命令回传给 JS
  var commandHandler: ((String, [String: Any]) -> Void)?

  func send(_ command: String, payload: [String: Any] = [:]) {
    commandHandler?(command, payload)
  }

  /// 用 RN 推来的字典更新全部状态
  func apply(_ dict: [String: Any]) {
    if let v = dict["title"] as? String { title = v }
    if let v = dict["artist"] as? String { artist = v }
    if let v = dict["picUrl"] as? String { picUrl = v }
    if let v = dict["isPlaying"] as? Bool { isPlaying = v }
    if let v = dict["favorited"] as? Bool { favorited = v }

    if let v = dict["currentTime"] as? Double { currentTime = v }
    if let v = dict["duration"] as? Double { duration = v }
    if let v = dict["progress"] as? Double { progress = v }
    if let v = dict["buffered"] as? Double { buffered = v }
    if let v = dict["currentTimeText"] as? String { currentTimeText = v }
    if let v = dict["durationText"] as? String { durationText = v }

    if let v = dict["lyricPrev"] as? String { lyricPrev = v }
    if let v = dict["lyricCurrent"] as? String { lyricCurrent = v }
    if let v = dict["lyricNext"] as? String { lyricNext = v }

    if let v = dict["sourceName"] as? String { sourceName = v }
    if let v = dict["qualityText"] as? String { qualityText = v }
    if let v = dict["currentSourceId"] as? String { currentSourceId = v }
    if let v = dict["currentQuality"] as? String { currentQuality = v }
    if let v = dict["playModeText"] as? String { playModeText = v }
    if let v = dict["sourceOptions"] as? [[String: String]] { sourceOptions = v }
    if let v = dict["qualityOptionList"] as? [[String: String]] {
      qualityOptionList = v
    }

    if let v = dict["backgroundColor"] as? String { backgroundColor = v }
    if let v = dict["cardColor"] as? String { cardColor = v }
    if let v = dict["primaryColor"] as? String { primaryColor = v }
    if let v = dict["fontColor"] as? String { fontColor = v }
    if let v = dict["fontLabelColor"] as? String { fontLabelColor = v }
    if let v = dict["isDark"] as? Bool { isDark = v }

    if let v = dict["lyricColor"] as? String { lyricColor = v }
    if let v = dict["lyricFontSize"] as? Double { lyricFontSize = v }
  }

  /// 音质可选列表（[{value,label}]）
  @Published var qualityOptionList: [[String: String]] = []
}

/// 轻量震动反馈封装：统一走系统 Taptic Engine。
enum Haptics {
  /// 切歌：中等力度
  static func trackChange() {
    let gen = UIImpactFeedbackGenerator(style: .medium)
    gen.prepare()
    gen.impactOccurred()
  }

  /// 收藏：成功提示感
  static func favorite() {
    UINotificationFeedbackGenerator().notificationOccurred(.success)
  }

  /// 按钮点击：轻触
  static func tap() {
    let gen = UIImpactFeedbackGenerator(style: .light)
    gen.impactOccurred()
  }

  /// 拖动进度条：选项变化
  static func select() {
    UISelectionFeedbackGenerator().selectionChanged()
  }
}
