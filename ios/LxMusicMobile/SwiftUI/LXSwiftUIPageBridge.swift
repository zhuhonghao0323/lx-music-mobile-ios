import Foundation
import Combine
import UIKit

/// 通用 SwiftUI 页面桥（多页面复用）。
///
/// 设计：所有页面共用一个 ObservableObject，用 pageId 区分数据域。
/// JS 推来的状态是扁平字典（key → 字符串/数字/布尔），SwiftUI 侧按 key 取用。
/// 这样新增页面不需要新增 Native Module，只需要新增一个 SwiftUI View。
final class PageBridge: ObservableObject {
  static let shared = PageBridge()

  /// 当前页面的状态字典（pageId → [key: value]）
  @Published private(set) var pages: [String: [String: Any]] = [:]

  /// 命令回传通道
  var commandHandler: ((String, String, [String: Any]) -> Void)?

  /// 用 RN 推来的字典整体替换某页状态
  func apply(pageId: String, state: [String: Any]) {
    pages[pageId] = state
  }

  /// 取某页状态
  func state(_ pageId: String) -> [String: Any] {
    pages[pageId] ?? [:]
  }

  /// 发命令回 RN（pageId + command + payload）
  func send(pageId: String, command: String, payload: [String: Any] = [:]) {
    commandHandler?(pageId, command, payload)
  }
}
