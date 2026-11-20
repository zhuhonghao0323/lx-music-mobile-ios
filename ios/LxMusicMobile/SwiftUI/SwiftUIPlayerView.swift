import SwiftUI

/// SwiftUI 播放页 —— 四层沉浸式 Liquid Glass 结构。
///
/// 层级（从底到顶）：
/// 1. 底层背景：专辑原图放大铺满全屏 + 大模糊 + 封面主色染色 + 压暗
/// 2. 融合渐变层：垂直渐变（透明 → 半透黑），让封面底部融进背景，消除硬边
/// 3. 实体封面：居中圆角清晰封面
/// 4. UI 控件层：歌词 / 进度 / 播放控制 / 底部导航，玻璃材质继承背景色
///
/// 设计约束：动态字体、SF Symbols(.hierarchical)、语义色为主、8pt 栅格、
/// 44pt 热区、SafeArea、克制动画、子 View 拆分 + 深浅双版本 Preview。
/// 业务逻辑仍全部在 RN：本页只读 PlayerBridge 状态，操作经 bridge.send 回传。
struct SwiftUIPlayerView: View {
  @ObservedObject var bridge = PlayerBridge.shared
  @Environment(\.colorScheme) private var colorScheme
  @State private var showSourceSheet = false
  @State private var showQualitySheet = false
  @State private var showPlaylistSheet = false

  /// 封面主色（用于背景染色）
  private var accent: Color {
    ColorParser.color(bridge.accentColor, fallback: .accentColor)
  }

  var body: some View {
    ZStack {
      // 层 1：模糊原图铺底
      blurredBackground
      // 层 2：垂直渐变融合蒙版
      blendGradient
      // 层 3 + 4：封面与控件
      contentLayer
    }
    .tint(.primary)
    .statusBarHidden(false)
    .sheet(isPresented: $showSourceSheet) {
      OptionSheet(title: "切换音源",
                  options: bridge.sourceOptions,
                  current: bridge.currentSourceId) { v in
        bridge.send("selectSource", payload: ["sourceId": v])
      }
      .presentationDetents([.medium])
    }
    .sheet(isPresented: $showQualitySheet) {
      OptionSheet(title: "音质",
                  options: bridge.qualityOptionList,
                  current: bridge.currentQuality) { v in
        bridge.send("selectQuality", payload: ["quality": v])
      }
      .presentationDetents([.medium])
    }
  }

  // MARK: - 层 1：底层模糊背景（原图放大铺满，不用小图拉伸）
  private var blurredBackground: some View {
    ZStack {
      // 深色兜底，避免封面加载前出现白闪
      Color.black

      if let url = URL(string: bridge.picUrl), !bridge.picUrl.isEmpty {
        AsyncImage(url: url) { phase in
          if case .success(let image) = phase {
            image
              .resizable()
              .scaledToFill()          // 原图放大铺满，而不是拉伸小图
              .blur(radius: 60)        // 大高斯模糊
              .clipped()
          }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      }

      // 封面主色染色：整张播放器色调跟随封面（每首歌氛围不同）
      accent
        .opacity(colorScheme == .dark ? 0.42 : 0.26)
        .blendMode(.plusLighter)

      // 压暗：保证歌词与按钮可读，但不过度（0.35 上下是沉浸与可读的平衡点）
      Color.black.opacity(colorScheme == .dark ? 0.35 : 0.08)
    }
    .ignoresSafeArea()
  }

  // MARK: - 层 2：融合渐变蒙版（最关键，让封面融入背景）
  private var blendGradient: some View {
    LinearGradient(
      gradient: Gradient(stops: [
        .init(color: .clear, location: 0.0),
        .init(color: .clear, location: 0.42),
        .init(color: Color.black.opacity(0.28), location: 0.62),
        .init(color: Color.black.opacity(0.62), location: 0.82),
        .init(color: Color.black.opacity(0.80), location: 1.0),
      ]),
      startPoint: .top,
      endPoint: .bottom
    )
    .ignoresSafeArea()
    .allowsHitTesting(false)
  }

  // MARK: - 层 3 + 4：内容
  //
  // 结构：顶部固定 → 封面弹性 → 底部固定。
  // 封面用 aspectRatio 自适应，绝不用 layoutPriority 抢空间，
  // 否则底部控件会被挤出屏幕（上一版就是这个错误）。
  private var contentLayer: some View {
    VStack(spacing: 0) {
      header
        .padding(.horizontal, DS.Space.md)
        .padding(.top, DS.Space.xs)

      // 封面：按屏幕高度的 34%，保证底部控件有余量
      cover
        .frame(height: UIScreen.main.bounds.height * 0.34)
        .padding(.horizontal, DS.Space.md)
        .padding(.top, DS.Space.sm)

      songInfo
        .padding(.top, DS.Space.sm)

      lyrics
        .padding(.top, DS.Space.xs)

      Spacer(minLength: 0)

      bottomControls
    }
  }

  /// 底部固定区：进度 / 播放控制 / 功能 / 导航
  private var bottomControls: some View {
    VStack(spacing: DS.Space.sm) {
      progress
      controls
      actions
      bottomNav
    }
    .padding(.horizontal, DS.Space.md)
    .padding(.top, DS.Space.xs)
    .background(
      LinearGradient(colors: [.clear, Color.black.opacity(0.35)], startPoint: .top, endPoint: .bottom)
    )
  }

  // MARK: - 顶栏
  private var header: some View {
    HStack {
      Button { bridge.send("back") } label: {
        Image(systemName: "chevron.down")
          .symbolRenderingMode(.hierarchical)
          .imageScale(.large)
      }
      .frame(minWidth: 44, minHeight: 44)
      .contentShape(Rectangle())

      Spacer()

      Text("正在播放")
        .font(.subheadline)
        .foregroundStyle(.secondary)

      Spacer()

      HStack(spacing: 4) {
        Button { if bridge.sourceOptions.isEmpty { bridge.send("openSourcePicker") } else { showSourceSheet = true } } label: {
          Image(systemName: "dot.radiowaves.left.and.right")
            .symbolRenderingMode(.hierarchical)
        }
        .frame(minWidth: 44, minHeight: 44)
        Button { bridge.send("openSetting") } label: {
          Image(systemName: "ellipsis")
            .symbolRenderingMode(.hierarchical)
        }
        .frame(minWidth: 44, minHeight: 44)
      }
    }
    .padding(.top, 8)
  }

  // MARK: - 层 3：实体封面
  @ViewBuilder
  private var cover: some View {
    Group {
      if let url = URL(string: bridge.picUrl), !bridge.picUrl.isEmpty {
        AsyncImage(url: url) { phase in
          if case .success(let image) = phase {
            image.resizable().scaledToFill()
          } else {
            coverPlaceholder
          }
        }
        .id(bridge.picUrl)
      } else {
        coverPlaceholder
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .clipped()
    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 20, style: .continuous)
        .stroke(.white.opacity(0.12), lineWidth: 0.5)
    }
  }

  private var coverPlaceholder: some View {
    ZStack {
      Color.primary.opacity(0.06)
      Image(systemName: "music.note")
        .symbolRenderingMode(.hierarchical)
        .font(.largeTitle)
    }
  }

  // MARK: - 歌曲信息
  private var songInfo: some View {
    VStack(spacing: 8) {
      Text(bridge.title.isEmpty ? "未知歌曲" : bridge.title)
        .font(.title3.weight(.semibold))
        .lineLimit(1)
      Text(bridge.artist.isEmpty ? "未知歌手" : bridge.artist)
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }
  }

  // MARK: - 歌词预览
  private var lyrics: some View {
    VStack(spacing: 8) {
      Text(bridge.lyricPrev.isEmpty ? " " : bridge.lyricPrev)
        .font(.footnote)
        .foregroundStyle(.tertiary)
        .lineLimit(1)
      Text(bridge.lyricCurrent.isEmpty ? " " : bridge.lyricCurrent)
        .font(.headline)
        .lineLimit(1)
      Text(bridge.lyricNext.isEmpty ? " " : bridge.lyricNext)
        .font(.footnote)
        .foregroundStyle(.tertiary)
        .lineLimit(1)
    }
    .frame(maxWidth: .infinity, minHeight: 64)
    .animation(.easeInOut(duration: 0.25), value: bridge.lyricCurrent)
  }

  // MARK: - 进度（系统 Slider）
  private var progress: some View {
    VStack(spacing: 4) {
      Slider(value: Binding(
        get: { bridge.progress },
        set: { bridge.send("seek", payload: ["ratio": $0]) }
      ), in: 0...1)
      .tint(.primary)

      HStack {
        Text(bridge.currentTimeText.isEmpty ? "00:00" : bridge.currentTimeText)
        Spacer()
        Text(bridge.durationText.isEmpty ? "00:00" : bridge.durationText)
      }
      .font(.caption.monospacedDigit())
      .foregroundStyle(.secondary)
    }
  }


  // MARK: - 播放控制
  private var controls: some View {
    HStack {
      Spacer()
      controlButton(symbol: "backward.end.fill", label: "上一首") { bridge.send("prev") }
      Spacer()
      Button { bridge.send("togglePlay") } label: {
        Image(systemName: bridge.isPlaying ? "pause.circle.fill" : "play.circle.fill")
          .symbolRenderingMode(.hierarchical)
          .font(.system(size: 56))
      }
      .frame(minWidth: 64, minHeight: 64)
      .contentShape(Rectangle())
      .accessibilityLabel(bridge.isPlaying ? "暂停" : "播放")
      Spacer()
      controlButton(symbol: "forward.end.fill", label: "下一首") { bridge.send("next") }
      Spacer()
    }
  }


  private func controlButton(symbol: String, label: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Image(systemName: symbol)
        .symbolRenderingMode(.hierarchical)
        .font(.title)
    }
    .frame(minWidth: 44, minHeight: 44)
    .contentShape(Rectangle())
    .accessibilityLabel(label)
  }

  // MARK: - 功能行
  private var actions: some View {
    HStack(spacing: 0) {
      actionButton(symbol: bridge.favorited ? "heart.fill" : "heart", label: "收藏") {
        bridge.send("toggleFavorite")
      }
      actionButton(symbol: "square.and.arrow.up", label: "分享") {
        bridge.send("share")
      }
      actionButton(symbol: "bubble.right", label: "评论") {
        bridge.send("openComment")
      }
      actionButton(symbol: "line.3.horizontal", label: "更多") {
        bridge.send("openMore")
      }
    }
  }


  private func actionButton(symbol: String, label: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Image(systemName: symbol)
        .symbolRenderingMode(.hierarchical)
        .imageScale(.large)
    }
    .frame(maxWidth: .infinity, minHeight: DS.minTap)
    .contentShape(Rectangle())
    .accessibilityLabel(label)
  }

  // MARK: - 底部导航（主页 / 播放键 / 我的）—— 玻璃材质继承背景
  private var bottomNav: some View {
    HStack(spacing: 0) {
      navButton(symbol: "house", label: "主页") { bridge.send("goHome") }
        .frame(width: 72)
      Spacer(minLength: 0)
      Button { bridge.send("togglePlay") } label: {
        Image(systemName: bridge.isPlaying ? "pause.fill" : "play.fill")
          .symbolRenderingMode(.hierarchical)
          .font(.title3)
          .frame(width: 76, height: 44)
          .background(.ultraThinMaterial, in: Capsule())
      }
      .frame(height: DS.minTap)
      .accessibilityLabel(bridge.isPlaying ? "暂停" : "播放")
      Spacer(minLength: 0)
      navButton(symbol: "person", label: "我的") { bridge.send("goMine") }
        .frame(width: 72)
    }
    .padding(.horizontal, DS.Space.xs)
    .padding(.vertical, 6)
    .background(.ultraThinMaterial, in: Capsule())
  }


  private func navButton(symbol: String, label: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Image(systemName: symbol)
        .symbolRenderingMode(.hierarchical)
        .imageScale(.large)
    }
    .frame(minWidth: 44, minHeight: 44)
    .contentShape(Rectangle())
    .accessibilityLabel(label)
  }
}

// MARK: - 深浅双版本 Preview
#Preview("播放页 · 浅色") {
  SwiftUIPlayerView().preferredColorScheme(.light)
}
#Preview("播放页 · 深色") {
  SwiftUIPlayerView().preferredColorScheme(.dark)
}


/// 通用选项弹层（音源 / 音质共用）—— 系统 List + 勾选
struct OptionSheet: View {
  let title: String
  let options: [[String: String]]
  let current: String
  let onSelect: (String) -> Void
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      List(options, id: \.self) { item in
        let value = item["value"] ?? ""
        let label = item["label"] ?? value
        Button {
          onSelect(value)
          dismiss()
        } label: {
          HStack {
            Text(label).foregroundStyle(.primary)
            Spacer()
            if value == current {
              Image(systemName: "checkmark").symbolRenderingMode(.hierarchical)
            }
          }
        }
      }
      .navigationTitle(title)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("完成") { dismiss() }
        }
      }
    }
  }
}
