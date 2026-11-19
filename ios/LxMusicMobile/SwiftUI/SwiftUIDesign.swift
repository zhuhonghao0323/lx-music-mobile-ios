import SwiftUI

/// SwiftUI 页面通用设计 Token（8pt 栅格 + 系统字体语义）。
enum DS {
  // 间距：严格 8pt 栅格
  enum Space {
    static let xs: CGFloat = 8
    static let sm: CGFloat = 16
    static let md: CGFloat = 24
    static let lg: CGFloat = 32
  }

  // 圆角：克制，只有两档
  enum Radius {
    static let card: CGFloat = 16
    static let cover: CGFloat = 12
  }

  /// 最小可点击热区（Apple HIG）
  static let minTap: CGFloat = 44
}

/// 通用卡片：系统材质，不手写渐变/花哨阴影
struct DSCard<Content: View>: View {
  @ViewBuilder var content: Content

  var body: some View {
    content
      .padding(DS.Space.sm)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(.regularMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
  }
}

/// 分区标题
struct DSSectionHeader: View {
  let title: String
  var trailing: AnyView?

  init(_ title: String, trailing: AnyView? = nil) {
    self.title = title
    self.trailing = trailing
  }

  var body: some View {
    HStack {
      Text(title).font(.title3.weight(.semibold))
      Spacer()
      if let trailing { trailing }
    }
    .padding(.horizontal, DS.Space.sm)
    .padding(.top, DS.Space.md)
    .padding(.bottom, DS.Space.xs)
  }
}

/// 空状态
struct DSEmptyState: View {
  let symbol: String
  let title: String

  var body: some View {
    VStack(spacing: DS.Space.sm) {
      Image(systemName: symbol)
        .symbolRenderingMode(.hierarchical)
        .font(.largeTitle)
        .foregroundStyle(.tertiary)
      Text(title).font(.subheadline).foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}
