import SwiftUI

/// SwiftUI 版播放页（与 RN 版 Vertical 播放页保持一致的视觉结构）：
/// 顶栏 → 封面 → 三行歌词 → 进度条 → 音源 → 播放控制 → 底部功能行。
/// 所有业务逻辑仍走 RN，本页面只负责渲染与下发命令。
struct SwiftUIPlayerView: View {
  @ObservedObject var bridge = PlayerBridge.shared
  @State private var dragOffset: CGFloat = 0

  private var backgroundColor: Color { ColorParser.color(bridge.backgroundColor, fallback: .black) }
  private var fontColor: Color { ColorParser.color(bridge.fontColor, fallback: .white) }
  private var fontLabelColor: Color { ColorParser.color(bridge.fontLabelColor, fallback: .gray) }
  private var primaryColor: Color { ColorParser.color(bridge.primaryColor, fallback: .red) }
  private var lyricHighlight: Color { ColorParser.color(bridge.lyricColor, fallback: .white) }

  var body: some View {
    ZStack {
      backgroundColor.ignoresSafeArea()

      VStack(spacing: 0) {
        header
        coverArea
        lyricArea
        progressArea
        sourceRow
        controlRow
        bottomRow
      }
    }
    // 全屏上下轻滑切歌（与 RN 版一致：横向留给翻页，竖向才抢手势）
    .gesture(
      DragGesture(minimumDistance: 30)
        .onChanged { value in
          guard abs(value.translation.height) > abs(value.translation.width) * 1.5 else { return }
          dragOffset = value.translation.height
        }
        .onEnded { value in
          defer { withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { dragOffset = 0 } }
          guard abs(value.translation.height) > 60,
                abs(value.translation.height) > abs(value.translation.width) * 1.5 else { return }
          bridge.send(value.translation.height < 0 ? "next" : "prev")
        }
    )
  }

  // MARK: - 顶栏
  private var header: some View {
    HStack(spacing: 12) {
      Button { bridge.send("back") } label: {
        Image(systemName: "chevron.left").font(.system(size: 20, weight: .semibold))
      }
      VStack(alignment: .leading, spacing: 2) {
        Text(bridge.title).font(.system(size: 16, weight: .medium)).lineLimit(1)
        Text(bridge.artist).font(.system(size: 12)).foregroundColor(fontLabelColor).lineLimit(1)
      }
      Spacer()
      Button { bridge.send("openSetting") } label: {
        Image(systemName: "gearshape").font(.system(size: 18))
      }
    }
    .foregroundColor(fontColor)
    .padding(.horizontal, 16)
    .padding(.vertical, 10)
  }

  // MARK: - 封面
  private var coverArea: some View {
    GeometryReader { geo in
      let size = min(geo.size.width * 0.78, geo.size.height * 0.86)
      HStack {
        Spacer()
        coverImage(width: size, height: size)
          .offset(y: dragOffset * 0.35)
        Spacer()
      }
      .frame(maxHeight: .infinity)
    }
    .padding(.vertical, 8)
  }

  private func coverImage(width: CGFloat, height: CGFloat) -> some View {
    Group {
      if let url = URL(string: bridge.picUrl), !bridge.picUrl.isEmpty {
        AsyncImage(url: url) { phase in
          switch phase {
          case .success(let image):
            image.resizable().aspectRatio(contentMode: .fill)
          default:
            placeholderCover
          }
        }
      } else {
        placeholderCover
      }
    }
    .frame(width: width, height: height)
    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 22, style: .continuous)
        .stroke(Color.white.opacity(0.28), lineWidth: 0.8)
    )
    .shadow(color: Color.black.opacity(0.45), radius: 22, x: 0, y: 14)
  }

  private var placeholderCover: some View {
    ZStack {
      Color.white.opacity(0.06)
      Image(systemName: "music.note").font(.system(size: 44)).foregroundColor(fontLabelColor)
    }
  }

  // MARK: - 三行歌词（居中于封面与进度条之间）
  private var lyricArea: some View {
    VStack(spacing: 12) {
      Text(bridge.lyricPrev.isEmpty ? " " : bridge.lyricPrev)
        .font(.system(size: bridge.lyricFontSize - 1))
        .foregroundColor(fontColor.opacity(0.45))
        .lineLimit(1)
      Text(bridge.lyricCurrent.isEmpty ? " " : bridge.lyricCurrent)
        .font(.system(size: bridge.lyricFontSize + 1, weight: .semibold))
        .foregroundColor(lyricHighlight)
        .lineLimit(1)
      Text(bridge.lyricNext.isEmpty ? " " : bridge.lyricNext)
        .font(.system(size: bridge.lyricFontSize - 1))
        .foregroundColor(fontColor.opacity(0.45))
        .lineLimit(1)
    }
    .animation(.easeOut(duration: 0.26), value: bridge.lyricCurrent)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding(.horizontal, 24)
  }

  // MARK: - 进度条
  private var progressArea: some View {
    VStack(spacing: 4) {
      GeometryReader { geo in
        ZStack(alignment: .leading) {
          Capsule().fill(Color.white.opacity(0.15)).frame(height: 3)
          Capsule().fill(Color.white.opacity(0.25))
            .frame(width: max(0, geo.size.width * bridge.buffered), height: 3)
          Capsule().fill(Color.white).frame(width: max(0, geo.size.width * bridge.progress), height: 3)
          Circle().fill(Color.white)
            .frame(width: 10, height: 10)
            .offset(x: max(0, geo.size.width * bridge.progress - 5))
        }
        .frame(height: 14)
        .contentShape(Rectangle())
        .gesture(
          DragGesture(minimumDistance: 0).onEnded { value in
            let ratio = min(1, max(0, value.location.x / geo.size.width))
            bridge.send("seek", payload: ["ratio": ratio])
          }
        )
      }
      .frame(height: 14)

      HStack {
        Text(bridge.currentTimeText)
        Spacer()
        Text(bridge.durationText)
      }
      .font(.system(size: 11))
      .foregroundColor(fontLabelColor)
    }
    .padding(.horizontal, 20)
  }

  // MARK: - 音源
  private var sourceRow: some View {
    Button { bridge.send("openSourcePicker") } label: {
      Text(bridge.sourceName.isEmpty ? "音源" : bridge.sourceName)
        .font(.system(size: 11))
        .foregroundColor(fontLabelColor)
        .lineLimit(1)
    }
    .padding(.top, 6)
    .padding(.bottom, 2)
  }

  // MARK: - 播放控制
  private var controlRow: some View {
    HStack(spacing: 0) {
      Spacer()
      Button { bridge.send("prev") } label: {
        Image(systemName: "backward.end.fill").font(.system(size: 30))
      }
      Spacer()
      Button { bridge.send("togglePlay") } label: {
        Image(systemName: bridge.isPlaying ? "pause.fill" : "play.fill")
          .font(.system(size: 40))
      }
      Spacer()
      Button { bridge.send("next") } label: {
        Image(systemName: "forward.end.fill").font(.system(size: 30))
      }
      Spacer()
    }
    .foregroundColor(fontColor)
    .padding(.vertical, 12)
  }

  // MARK: - 底部功能行（等分居中）
  private var bottomRow: some View {
    HStack(spacing: 0) {
      bottomCell {
        Button { bridge.send("toggleFavorite") } label: {
          Image(systemName: bridge.favorited ? "heart.fill" : "heart")
            .font(.system(size: 20))
            .foregroundColor(bridge.favorited ? primaryColor : fontLabelColor)
        }
        .simultaneousGesture(
          LongPressGesture(minimumDuration: 0.6).onEnded { _ in
            bridge.send("openFavoriteListPicker")
          }
        )
      }
      bottomCell {
        Button { bridge.send("togglePlayMode") } label: {
          Image(systemName: "shuffle").font(.system(size: 20)).foregroundColor(fontLabelColor)
        }
      }
      bottomCell {
        Button { bridge.send("openComment") } label: {
          Image(systemName: "bubble.right").font(.system(size: 20)).foregroundColor(fontLabelColor)
        }
      }
      bottomCell {
        Button { bridge.send("openQualityPicker") } label: {
          Text(bridge.qualityText.isEmpty ? "--" : bridge.qualityText)
            .font(.system(size: 14))
            .foregroundColor(fontLabelColor)
            .lineLimit(1)
        }
      }
    }
    .padding(.horizontal, 12)
    .padding(.bottom, 8)
  }

  private func bottomCell<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
    content().frame(maxWidth: .infinity)
  }
}
