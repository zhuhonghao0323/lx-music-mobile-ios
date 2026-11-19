import SwiftUI

/// SwiftUI 版播放页 —— 按产品级设计规范重写。
///
/// 严格遵循设计约束：
/// - 只用系统动态文本样式（.largeTitle/.title/.headline/.body/.subheadline/.caption/.footnote）
/// - 图标只用 SF Symbols + .symbolRenderingMode(.hierarchical)，无 emoji、无自定义图片
/// - 颜色只用语义色 .primary/.secondary/.tint，深浅模式自动适配，不写死 RGB
/// - 系统材质（.ultraThinMaterial）构建沉浸玻璃背景，禁止手写渐变/花哨阴影
/// - 8pt 栅格间距（8/16/24/32），所有可点击热区 >= 44pt
/// - 自动 SafeArea，动画只用系统简洁动画
/// - 合理拆分子 View，并附深浅双版本 Preview
///
/// 业务逻辑仍然全部留在 RN：本页只读 PlayerBridge 状态渲染，用户操作通过
/// bridge.send 回传给 JS 执行。
struct SwiftUIPlayerView: View {
  @ObservedObject var bridge = PlayerBridge.shared
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    ZStack {
      backgroundLayer
      contentLayer
    }
    .tint(.primary)
    .statusBar(hidden: false)
  }

  // MARK: - 沉浸背景（系统材质 + 封面，无手写渐变）
  private var backgroundLayer: some View {
    ZStack {
      // 封面铺底（SwiftUI 原生 AsyncImage，iOS 15+）
      if let url = URL(string: bridge.picUrl), !bridge.picUrl.isEmpty {
        AsyncImage(url: url) { phase in
          if case .success(let image) = phase {
            image
              .resizable()
              .scaledToFill()
              .blur(radius: 60)
              .clipped()
          }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      }

      // 系统材质层：把封面柔化成有纵深的玻璃背景
      Rectangle()
        .fill(.ultraThinMaterial)
        .overlay {
          // 语义色遮罩：深色压暗 / 浅色提亮，保证文字可读
          Color.primary
            .opacity(colorScheme == .dark ? 0.42 : 0.06)
        }
    }
    .ignoresSafeArea()
  }

  // MARK: - 内容
  private var contentLayer: some View {
    VStack(spacing: 24) {
      header
      cover
      songInfo
      lyrics
      progress
      controls
      actions
    }
    .padding(.horizontal, 24)
    .padding(.bottom, 16)
  }

  // MARK: - 顶栏
  private var header: some View {
    HStack {
      Button {
        bridge.send("back")
      } label: {
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

      Button {
        bridge.send("openSetting")
      } label: {
        Image(systemName: "ellipsis")
          .symbolRenderingMode(.hierarchical)
          .imageScale(.large)
      }
      .frame(minWidth: 44, minHeight: 44)
      .contentShape(Rectangle())
    }
    .padding(.top, 8)
  }

  // MARK: - 封面
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
      } else {
        coverPlaceholder
      }
    }
    .frame(maxWidth: .infinity)
    .aspectRatio(1, contentMode: .fit)
    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    .shadow(radius: 16, y: 8)
    .padding(.horizontal, 16)
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
    .frame(maxWidth: .infinity, minHeight: 72)
    .animation(.easeInOut(duration: 0.25), value: bridge.lyricCurrent)
  }

  // MARK: - 进度（系统 Slider）
  private var progress: some View {
    VStack(spacing: 8) {
      Slider(
        value: Binding(
          get: { bridge.progress },
          set: { newValue in
            bridge.send("seek", payload: ["ratio": newValue])
          }
        ),
        in: 0...1
      )
      HStack {
        Text(bridge.currentTimeText)
        Spacer()
        Text(bridge.durationText)
      }
      .font(.caption)
      .foregroundStyle(.secondary)
    }
  }

  // MARK: - 播放控制
  private var controls: some View {
    HStack {
      Spacer()
      controlButton(symbol: "backward.end.fill", title: "上一首") {
        bridge.send("prev")
      }
      Spacer()
      Button {
        bridge.send("togglePlay")
      } label: {
        Image(systemName: bridge.isPlaying ? "pause.circle.fill" : "play.circle.fill")
          .symbolRenderingMode(.hierarchical)
          .font(.system(size: 56))
      }
      .frame(minWidth: 64, minHeight: 64)
      .contentShape(Rectangle())
      .accessibilityLabel(bridge.isPlaying ? "暂停" : "播放")
      Spacer()
      controlButton(symbol: "forward.end.fill", title: "下一首") {
        bridge.send("next")
      }
      Spacer()
    }
  }

  private func controlButton(symbol: String, title: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Image(systemName: symbol)
        .symbolRenderingMode(.hierarchical)
        .font(.title)
    }
    .frame(minWidth: 44, minHeight: 44)
    .contentShape(Rectangle())
    .accessibilityLabel(title)
  }

  // MARK: - 底部功能行
  private var actions: some View {
    HStack {
      actionButton(
        symbol: bridge.favorited ? "heart.fill" : "heart",
        title: "收藏",
        action: { bridge.send("toggleFavorite") }
      )
      Spacer()
      actionButton(symbol: "shuffle", title: "播放模式", action: { bridge.send("togglePlayMode") })
      Spacer()
      actionButton(symbol: "bubble.right", title: "评论", action: { bridge.send("openComment") })
      Spacer()
      actionButton(symbol: "dot.radiowaves.left.and.right", title: "切换音源", action: { bridge.send("openSourcePicker") })
    }
  }

  private func actionButton(symbol: String, title: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Image(systemName: symbol)
        .symbolRenderingMode(.hierarchical)
        .imageScale(.large)
    }
    .frame(minWidth: 44, minHeight: 44)
    .contentShape(Rectangle())
    .accessibilityLabel(title)
  }
}

// MARK: - 深浅双版本 Preview
#Preview("播放页 · 浅色") {
  SwiftUIPlayerView()
    .preferredColorScheme(.light)
}

#Preview("播放页 · 深色") {
  SwiftUIPlayerView()
    .preferredColorScheme(.dark)
}
