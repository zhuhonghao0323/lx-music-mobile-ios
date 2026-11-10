import SwiftUI

/// SwiftUI 版播放页（与 RN 版 Vertical 播放页保持一致的视觉结构）：
/// 顶栏 → 封面 → 三行歌词 → 进度条 → 音源 → 播放控制 → 底部功能行。
/// 所有业务逻辑仍走 RN，本页面只负责渲染与下发命令。
struct SwiftUIPlayerView: View {
  @ObservedObject var bridge = PlayerBridge.shared

  /// 切歌翻动动画的驱动值：-1 向下翻（上一曲），1 向上翻（下一曲）
  @State private var flipDirection: CGFloat = 0
  @State private var dragOffset: CGFloat = 0
  @State private var showSourceSheet = false
  @State private var showQualitySheet = false

  private var backgroundColor: Color { ColorParser.color(bridge.backgroundColor, fallback: .black) }
  private var fontColor: Color { ColorParser.color(bridge.fontColor, fallback: .white) }
  private var fontLabelColor: Color { ColorParser.color(bridge.fontLabelColor, fallback: .gray) }
  private var primaryColor: Color { ColorParser.color(bridge.primaryColor, fallback: .red) }
  private var lyricHighlight: Color { ColorParser.color(bridge.lyricColor, fallback: .white) }
  private var cardColor: Color { ColorParser.color(bridge.cardColor, fallback: Color.white.opacity(0.08)) }

  var body: some View {
    ZStack {
      // 背景：主色 + 深色底的一层柔和渐变，让画面有纵深
      ZStack {
        backgroundColor
        LinearGradient(
          gradient: Gradient(colors: [
            primaryColor.opacity(bridge.isDark ? 0.18 : 0.12),
            Color.clear,
            backgroundColor.opacity(0.9),
          ]),
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
      }
      .edgesIgnoringSafeArea(.all)

      VStack(spacing: 0) {
        header
        coverArea
        lyricArea
        progressArea
        sourceRow
        controlRow
        bottomRow
      }

      // 选项弹层：.sheet 需要 iOS 14+，这里用自绘遮罩 + 底部卡片，
      // 保证 iOS 13.4 上也能正常弹出。
      if showSourceSheet || showQualitySheet {
        ZStack(alignment: .bottom) {
          Color.black.opacity(0.45)
            .edgesIgnoringSafeArea(.all)
            .onTapGesture {
              withAnimation(.easeOut(duration: 0.2)) {
                showSourceSheet = false
                showQualitySheet = false
              }
            }
          Group {
            if showSourceSheet {
              OptionSheet(
                title: "切换音源",
                options: bridge.sourceOptions,
                currentValue: bridge.currentSourceId,
                primaryColor: primaryColor,
                textColor: fontColor,
                onSelect: { value in
                  Haptics.select()
                  bridge.send("selectSource", payload: ["sourceId": value])
                  showSourceSheet = false
                }
              )
            } else {
              OptionSheet(
                title: "切换音质",
                options: bridge.qualityOptionList,
                currentValue: bridge.currentQuality,
                primaryColor: primaryColor,
                textColor: fontColor,
                onSelect: { value in
                  Haptics.select()
                  bridge.send("selectQuality", payload: ["quality": value])
                  showQualitySheet = false
                }
              )
            }
          }
          .background(cardColor)
          .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
          .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
              .stroke(Color.white.opacity(0.18), lineWidth: 0.8)
          )
          .padding(.bottom, 12)
          .padding(.horizontal, 8)
        }
        .transition(.opacity)
      }
    }
    // 全屏上下轻滑切歌：拖拽时封面跟手，松手触发翻动
    .gesture(
      DragGesture(minimumDistance: 20)
        .onChanged { value in
          guard !(showSourceSheet || showQualitySheet) else { return }
          guard abs(value.translation.height) > abs(value.translation.width) * 1.5 else { return }
          dragOffset = value.translation.height
        }
        .onEnded { value in
          // 弹层打开时不响应，避免与弹层的点击/滚动冲突
          guard !(showSourceSheet || showQualitySheet) else { return }
          let dy = value.translation.height
          let isVertical = abs(dy) > abs(value.translation.width) * 1.5
          defer {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) { dragOffset = 0 }
          }
          guard isVertical, abs(dy) > 60 else { return }
          performSwitch(isNext: dy < 0)
        }
    )
  }

  /// 切歌：先播放震动与翻动动画，再下发命令
  private func performSwitch(isNext: Bool) {
    Haptics.trackChange()
    withAnimation(.easeOut(duration: 0.18)) {
      flipDirection = isNext ? 1 : -1
    }
    bridge.send(isNext ? "next" : "prev")
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
      withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) {
        flipDirection = 0
      }
    }
  }

  // MARK: - 顶栏
  private var header: some View {
    HStack(spacing: 12) {
      Button {
        Haptics.tap()
        bridge.send("back")
      } label: {
        Image(systemName: "chevron.left").font(.system(size: 20, weight: .semibold))
      }
      VStack(alignment: .leading, spacing: 2) {
        Text(bridge.title).font(.system(size: 16, weight: .semibold)).lineLimit(1)
        Text(bridge.artist).font(.system(size: 12)).foregroundColor(fontLabelColor).lineLimit(1)
      }
      Spacer()
      Button {
        Haptics.tap()
        bridge.send("openSetting")
      } label: {
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
      let size = min(geo.size.width * 0.76, geo.size.height * 0.84)
      HStack {
        Spacer()
        coverImage(width: size, height: size)
          .offset(y: dragOffset * 0.35)
          // 翻动效果：沿竖直方向滑出 + 轻微缩放与旋转
          .offset(y: flipDirection == 0 ? 0 : -flipDirection * size * 0.55)
          .scaleEffect(flipDirection == 0 ? 1 : 0.86)
          .rotation3DEffect(
            .degrees(Double(flipDirection) * 12),
            axis: (x: 1, y: 0, z: 0)
          )
          .opacity(flipDirection == 0 ? 1 : 0.25)
        Spacer()
      }
      .frame(maxHeight: .infinity)
    }
    .padding(.vertical, 6)
  }

  private func coverImage(width: CGFloat, height: CGFloat) -> some View {
    Group {
      if !bridge.picUrl.isEmpty, let url = URL(string: bridge.picUrl) {
        SwiftUICoverImage(url: url).id(bridge.picUrl)
      } else {
        placeholderCover
      }
    }
    .frame(width: width, height: height)
    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    .overlay(
      // 玻璃高光：顶部一条很淡的白边，模拟反光
      RoundedRectangle(cornerRadius: 24, style: .continuous)
        .stroke(
          LinearGradient(
            gradient: Gradient(colors: [Color.white.opacity(0.55), Color.white.opacity(0.06)]),
            startPoint: .top,
            endPoint: .bottom
          ),
          lineWidth: 1
        )
    )
    .shadow(color: primaryColor.opacity(0.25), radius: 26, x: 0, y: 16)
    .shadow(color: Color.black.opacity(0.55), radius: 20, x: 0, y: 10)
  }

  private var placeholderCover: some View {
    ZStack {
      Color.white.opacity(0.06)
      Image(systemName: "music.note").font(.system(size: 44)).foregroundColor(fontLabelColor)
    }
  }

  // MARK: - 三行歌词
  private var lyricArea: some View {
    VStack(spacing: 12) {
      Text(bridge.lyricPrev.isEmpty ? " " : bridge.lyricPrev)
        .font(.system(size: bridge.lyricFontSize - 1))
        .foregroundColor(fontColor.opacity(0.42))
        .lineLimit(1)
      Text(bridge.lyricCurrent.isEmpty ? " " : bridge.lyricCurrent)
        .font(.system(size: bridge.lyricFontSize + 2, weight: .semibold))
        .foregroundColor(lyricHighlight)
        .lineLimit(1)
        .shadow(color: primaryColor.opacity(0.35), radius: 10)
      Text(bridge.lyricNext.isEmpty ? " " : bridge.lyricNext)
        .font(.system(size: bridge.lyricFontSize - 1))
        .foregroundColor(fontColor.opacity(0.42))
        .lineLimit(1)
    }
    .animation(.easeOut(duration: 0.28), value: bridge.lyricCurrent)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding(.horizontal, 24)
  }

  // MARK: - 进度条
  private var progressArea: some View {
    VStack(spacing: 4) {
      GeometryReader { geo in
        ZStack(alignment: .leading) {
          Capsule().fill(Color.white.opacity(0.14)).frame(height: 3)
          Capsule().fill(primaryColor.opacity(0.45))
            .frame(width: max(0, geo.size.width * bridge.buffered), height: 3)
          Capsule()
            .fill(
              LinearGradient(gradient: Gradient(colors: [primaryColor, primaryColor.opacity(0.75)]),
                             startPoint: .leading, endPoint: .trailing)
            )
            .frame(width: max(0, geo.size.width * bridge.progress), height: 3)
          Circle().fill(Color.white)
            .frame(width: 11, height: 11)
            .shadow(color: primaryColor.opacity(0.6), radius: 6)
            .offset(x: max(0, geo.size.width * bridge.progress - 5.5))
        }
        .frame(height: 14)
        .contentShape(Rectangle())
        .gesture(
          DragGesture(minimumDistance: 0).onEnded { value in
            let ratio = min(1, max(0, value.location.x / geo.size.width))
            Haptics.select()
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
      .font(.system(size: 11, weight: .medium))
      .foregroundColor(fontLabelColor)
    }
    .padding(.horizontal, 20)
  }

  // MARK: - 音源
  private var sourceRow: some View {
    Button {
      Haptics.tap()
      if bridge.sourceOptions.isEmpty { bridge.send("openSourcePicker") }
      else { showSourceSheet = true }
    } label: {
      HStack(spacing: 4) {
        Image(systemName: "dot.radiowaves.left.and.right").font(.system(size: 10))
        Text(bridge.sourceName.isEmpty ? "音源" : bridge.sourceName)
          .font(.system(size: 11, weight: .medium))
          .lineLimit(1)
      }
      .foregroundColor(fontLabelColor)
      .padding(.horizontal, 10)
      .padding(.vertical, 4)
      .background(cardColor)
      .clipShape(Capsule())
    }
    .padding(.top, 6)
    .padding(.bottom, 2)
  }

  // MARK: - 播放控制
  private var controlRow: some View {
    HStack(spacing: 0) {
      Spacer()
      Button {
        Haptics.trackChange()
        bridge.send("prev")
      } label: {
        Image(systemName: "backward.end.fill").font(.system(size: 30))
      }
      Spacer()
      Button {
        Haptics.tap()
        bridge.send("togglePlay")
      } label: {
        ZStack {
          Circle()
            .fill(primaryColor.opacity(0.16))
            .frame(width: 74, height: 74)
          Image(systemName: bridge.isPlaying ? "pause.fill" : "play.fill")
            .font(.system(size: 34))
            .foregroundColor(primaryColor)
        }
      }
      Spacer()
      Button {
        Haptics.trackChange()
        bridge.send("next")
      } label: {
        Image(systemName: "forward.end.fill").font(.system(size: 30))
      }
      Spacer()
    }
    .foregroundColor(fontColor)
    .padding(.vertical, 10)
  }

  // MARK: - 底部功能行（等分居中）
  private var bottomRow: some View {
    HStack(spacing: 0) {
      bottomCell {
        Button {
          Haptics.favorite()
          bridge.send("toggleFavorite")
        } label: {
          Image(systemName: bridge.favorited ? "heart.fill" : "heart")
            .font(.system(size: 20))
            .foregroundColor(bridge.favorited ? primaryColor : fontLabelColor)
            .scaleEffect(bridge.favorited ? 1.08 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: bridge.favorited)
        }
        .simultaneousGesture(
          LongPressGesture(minimumDuration: 0.6).onEnded { _ in
            Haptics.tap()
            bridge.send("openFavoriteListPicker")
          }
        )
      }
      bottomCell {
        Button {
          Haptics.tap()
          bridge.send("togglePlayMode")
        } label: {
          Image(systemName: "shuffle").font(.system(size: 20)).foregroundColor(fontLabelColor)
        }
      }
      bottomCell {
        Button {
          Haptics.tap()
          bridge.send("openComment")
        } label: {
          Image(systemName: "bubble.right").font(.system(size: 20)).foregroundColor(fontLabelColor)
        }
      }
      bottomCell {
        Button {
          Haptics.tap()
          if bridge.qualityOptionList.isEmpty { bridge.send("openQualityPicker") }
          else { showQualitySheet = true }
        } label: {
          Text(bridge.qualityText.isEmpty ? "--" : bridge.qualityText)
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(fontLabelColor)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
      }
    }
    .padding(.horizontal, 12)
    .padding(.bottom, 10)
  }

  private func bottomCell<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
    content().frame(maxWidth: .infinity)
  }
}

/// 通用选项弹窗（音源 / 音质共用）
struct OptionSheet: View {
  let title: String
  let options: [[String: String]]
  let currentValue: String
  let primaryColor: Color
  let textColor: Color
  let onSelect: (String) -> Void

  var body: some View {
    VStack(spacing: 0) {
      Capsule()
        .fill(textColor.opacity(0.3))
        .frame(width: 36, height: 5)
        .padding(.top, 8)
        .padding(.bottom, 14)
      Text(title)
        .font(.system(size: 16, weight: .semibold))
        .foregroundColor(textColor)
        .padding(.bottom, 12)
      ScrollView {
        VStack(spacing: 0) {
          ForEach(0..<options.count, id: \.self) { index in
            let item = options[index]
            let value = item["value"] ?? ""
            let label = item["label"] ?? value
            Button {
              onSelect(value)
            } label: {
              HStack {
                Text(label)
                  .font(.system(size: 15))
                  .foregroundColor(textColor)
                Spacer()
                if value == currentValue {
                  Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(primaryColor)
                }
              }
              .padding(.horizontal, 20)
              .padding(.vertical, 13)
              .contentShape(Rectangle())
            }
            Divider().opacity(0.15).padding(.leading, 20)
          }
        }
      }
    }
    .padding(.bottom, 20)
  }
}
