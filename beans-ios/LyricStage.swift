import SwiftUI
import WebKit

// MARK: - 歌词舞台（移植自 liziair 的实时歌词演出）

/// 一个舞台对应一个打包进 App 的 HTML（WebGL / Canvas / CSS 动画）。
/// 舞台内部认 `{__c100: 1, type: 'init' | 'tick'}` 的 postMessage 协议，
/// 所以原生侧只需要把歌词与播放进度喂进去，效果完全保真。
struct LyricStage: Identifiable, Hashable {
    let id: String
    let name: String
    let group: String

    static let all: [LyricStage] = [
        .init(id: "001-particle-lyrics", name: "粒子歌词", group: "经典"),
        .init(id: "002-starfield-lyrics", name: "星际歌词", group: "经典"),
        .init(id: "008-snow-lyrics", name: "静雪歌词", group: "经典"),
        .init(id: "010-embers-lyrics", name: "余烬歌词", group: "经典"),
        .init(id: "012-cave-lyrics", name: "光行洞穴", group: "经典"),
        .init(id: "020-grid-horizon-lyrics", name: "网格地平线", group: "经典"),
        .init(id: "027-code-rain-lyrics", name: "代码雨", group: "经典"),
        .init(id: "031-css-cube-lyrics", name: "立方体", group: "经典"),
        .init(id: "048-sierpinski-lyrics", name: "谢尔宾斯基", group: "经典"),
        .init(id: "066-thrown-splat", name: "泼墨黏墙", group: "图形"),
        .init(id: "067-arc-etch", name: "电蚀刻痕", group: "图形"),
        .init(id: "083-frost", name: "霜花结晶", group: "图形"),
        .init(id: "099-bioluma", name: "生物荧光", group: "图形"),
        .init(id: "304-kidcore", name: "超扁童心", group: "图形"),
        .init(id: "306-bauhaus-target", name: "靶心构成", group: "图形"),
        .init(id: "353-acid-lime", name: "酸性青柠", group: "图形"),
        .init(id: "359-midnight-visitor", name: "午夜访客", group: "图形"),
        .init(id: "366-neon-cartridge", name: "霓虹卡匣", group: "图形"),
        .init(id: "368-stock-meltdown", name: "图库事故", group: "图形"),
        .init(id: "370-scissor-riot", name: "剪刀暴动", group: "图形"),
        .init(id: "396-crate-label", name: "七寸留声", group: "图形"),
        .init(id: "398-mirrorball-glitz", name: "银球夜", group: "图形"),
        .init(id: "408-audio-crystal-bloom", name: "音生晶簇", group: "图形"),
        .init(id: "413-thorn-glass-heart", name: "熔心棘冠", group: "图形"),
        .init(id: "428-thermal-cctv", name: "热像监控", group: "图形"),
        .init(id: "429-sunlit-diary", name: "晴日手记", group: "图形"),
        .init(id: "443-silk-cavern", name: "沉纱", group: "图形"),
        .init(id: "522-abyssal-echo", name: "深海回响", group: "影像"),
        .init(id: "542-thunderhead-cumulonimbus", name: "雷暴云砧", group: "影像"),
        .init(id: "588-trigger-impact-frames", name: "扳机闪光帧", group: "影像"),
    ]

    static func stage(id: String) -> LyricStage? {
        all.first { $0.id == id }
    }

    /// 选择器里的代表色（舞台本身是动态的，这里只做卡片底色）
    var tint: Color {
        switch id {
        case "001-particle-lyrics": return Color(red: 0.35, green: 0.45, blue: 0.95)
        case "002-starfield-lyrics": return Color(red: 0.20, green: 0.26, blue: 0.55)
        case "008-snow-lyrics": return Color(red: 0.46, green: 0.66, blue: 0.82)
        case "010-embers-lyrics": return Color(red: 0.85, green: 0.38, blue: 0.16)
        case "012-cave-lyrics": return Color(red: 0.30, green: 0.58, blue: 0.60)
        case "020-grid-horizon-lyrics": return Color(red: 0.85, green: 0.28, blue: 0.55)
        case "027-code-rain-lyrics": return Color(red: 0.12, green: 0.68, blue: 0.34)
        case "031-css-cube-lyrics": return Color(red: 0.52, green: 0.40, blue: 0.85)
        case "048-sierpinski-lyrics": return Color(red: 0.90, green: 0.55, blue: 0.20)
        case "066-thrown-splat": return Color(red: 0.62, green: 0.16, blue: 0.20)
        case "067-arc-etch": return Color(red: 0.30, green: 0.32, blue: 0.40)
        case "083-frost": return Color(red: 0.60, green: 0.78, blue: 0.90)
        case "099-bioluma": return Color(red: 0.20, green: 0.80, blue: 0.62)
        case "304-kidcore": return Color(red: 0.95, green: 0.55, blue: 0.70)
        case "306-bauhaus-target": return Color(red: 0.88, green: 0.30, blue: 0.22)
        case "353-acid-lime": return Color(red: 0.62, green: 0.82, blue: 0.12)
        case "359-midnight-visitor": return Color(red: 0.18, green: 0.20, blue: 0.30)
        case "366-neon-cartridge": return Color(red: 0.20, green: 0.85, blue: 0.95)
        case "368-stock-meltdown": return Color(red: 0.55, green: 0.50, blue: 0.45)
        case "370-scissor-riot": return Color(red: 0.90, green: 0.20, blue: 0.35)
        case "396-crate-label": return Color(red: 0.72, green: 0.60, blue: 0.40)
        case "398-mirrorball-glitz": return Color(red: 0.80, green: 0.78, blue: 0.62)
        case "408-audio-crystal-bloom": return Color(red: 0.36, green: 0.72, blue: 0.88)
        case "413-thorn-glass-heart": return Color(red: 0.78, green: 0.18, blue: 0.30)
        case "428-thermal-cctv": return Color(red: 0.95, green: 0.42, blue: 0.16)
        case "429-sunlit-diary": return Color(red: 0.95, green: 0.78, blue: 0.48)
        case "443-silk-cavern": return Color(red: 0.55, green: 0.42, blue: 0.52)
        case "522-abyssal-echo": return Color(red: 0.08, green: 0.24, blue: 0.46)
        case "542-thunderhead-cumulonimbus": return Color(red: 0.28, green: 0.34, blue: 0.45)
        case "588-trigger-impact-frames": return Color(red: 0.95, green: 0.25, blue: 0.55)
        default: return Color.beansAmber
        }
    }
}

enum LyricStageSettings {
    static let enabledKey = "beans.lyricStage.enabled"
    static let idKey = "beans.lyricStage.id"
    static let defaultID = "001-particle-lyrics"
    /// 舞台是重效果，默认关，让用户自己在播放设置里开
    static let defaultEnabled = false
}

// MARK: - WKWebView 桥接

struct LyricStageWebView: UIViewRepresentable {
    let stage: LyricStage
    let lines: [LyricLine]
    let progress: Double
    let isPlaying: Bool
    let accentHex: String?

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        let controller = WKUserContentController()
        controller.add(context.coordinator, name: "liziStage")
        // 舞台用 parent.postMessage 上报 ready；这里把它转给原生，收到后再喂歌词
        let hook = """
        (function(){
          function forward(data){
            try {
              if (data && data.type === 'ready') {
                window.webkit.messageHandlers.liziStage.postMessage({type:'ready'});
              }
            } catch(e) {}
          }
          window.addEventListener('message', function(e){ forward(e.data); }, true);
        })();
        """
        controller.addUserScript(WKUserScript(source: hook, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        config.userContentController = controller

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        // 手势要留给 SwiftUI（左滑回封面），舞台本身不需要交互
        webView.isUserInteractionEnabled = false
        webView.allowsBackForwardNavigationGestures = false

        context.coordinator.attach(webView: webView, stage: stage)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.update(
            lines: lines,
            progress: progress,
            isPlaying: isPlaying,
            accentHex: accentHex
        )
    }

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        coordinator.stop()
        uiView.configuration.userContentController.removeScriptMessageHandler(forName: "liziStage")
        uiView.stopLoading()
        uiView.loadHTMLString("", baseURL: nil)
    }

    final class Coordinator: NSObject, WKScriptMessageHandler {
        private weak var webView: WKWebView?
        private var timer: Timer?
        private var ready = false
        private var stageID = ""
        private var linesPayload: [[String: Any]] = []
        private var linesKey = ""
        private var latestTime: Double = 0
        private var latestPlaying = false
        private var accentHex: String?

        func attach(webView: WKWebView, stage: LyricStage) {
            self.webView = webView
            self.stageID = stage.id
            loadStage(stage)

            timer?.invalidate()
            let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
                self?.sendTick()
            }
            RunLoop.main.add(timer, forMode: .common)
            self.timer = timer

            // 兜底：个别舞台的 ready 可能被 CSP / 时序吞掉，1 秒后直接喂数据
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                guard let self, !self.ready else { return }
                self.ready = true
                self.sendInit()
            }
        }

        func stop() {
            timer?.invalidate()
            timer = nil
        }

        private func loadStage(_ stage: LyricStage) {
            guard let webView else { return }
            let url = Bundle.main.url(forResource: stage.id, withExtension: "html", subdirectory: "LyricStages")
                ?? Bundle.main.url(forResource: stage.id, withExtension: "html")
            guard let url else {
                BeansLogger.shared.log("歌词舞台：找不到资源 \(stage.id).html", level: .warn)
                return
            }
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }

        func update(lines: [LyricLine], progress: Double, isPlaying: Bool, accentHex: String?) {
            latestTime = progress
            latestPlaying = isPlaying

            let key = "\(lines.count)|\(lines.first?.time ?? -1)|\(lines.last?.time ?? -1)"
            if key != linesKey {
                linesKey = key
                var payload: [[String: Any]] = []
                payload.reserveCapacity(lines.count)
                for line in lines {
                    let text = line.text.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !text.isEmpty else { continue }
                    // 30 个舞台的协议略有差异：主流读 t/text，少数读 time/s/txt。
                    // 同一行里把别名一起塞进去，保证每个舞台都能拿到歌词。
                    payload.append([
                        "t": line.time,
                        "time": line.time,
                        "text": text,
                        "s": text,
                        "txt": text,
                        "dur": 4.0
                    ])
                }
                linesPayload = payload
                if ready { sendInit() }
            }

            if accentHex != self.accentHex {
                self.accentHex = accentHex
                if ready { sendInit() }
            }
        }

        private func sendInit() {
            guard let webView else { return }
            var payload: [String: Any] = ["lines": linesPayload]
            if let accentHex, !accentHex.isEmpty {
                payload["accent"] = accentHex
            }
            guard let json = Self.jsonString(payload) else { return }
            // init 后补一个 resize：不少舞台在 WebGL/Canvas 尺寸为 0 时建场会失败，
            // WKWebView 首帧布局完成后派发一次 resize 让它们按真实尺寸重建。
            let js = """
            window.postMessage({__c100:1,type:'init',payload:\(json)},'*');
            setTimeout(function(){
              try { window.dispatchEvent(new Event('resize')); } catch(e) {}
              window.postMessage({__c100:1,type:'tick',payload:{time:\(latestTime),playing:\(latestPlaying ? "true" : "false")}},'*');
            }, 120);
            """
            webView.evaluateJavaScript(js, completionHandler: nil)
        }

        private func sendTick() {
            guard ready, let webView else { return }
            let time = String(format: "%.3f", latestTime)
            let playing = latestPlaying ? "true" : "false"
            let js = "window.postMessage({__c100:1,type:'tick',payload:{time:\(time),playing:\(playing)}},'*');"
            webView.evaluateJavaScript(js, completionHandler: nil)
        }

        private static func jsonString(_ object: [String: Any]) -> String? {
            guard JSONSerialization.isValidJSONObject(object),
                  let data = try? JSONSerialization.data(withJSONObject: object, options: []),
                  let text = String(data: data, encoding: .utf8) else {
                return nil
            }
            return text
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "liziStage" else { return }
            ready = true
            sendInit()
        }
    }
}

// MARK: - 舞台选择器

struct LyricStagePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(LyricStageSettings.idKey) private var selectedID = LyricStageSettings.defaultID
    @AppStorage(LyricStageSettings.enabledKey) private var stageEnabled = LyricStageSettings.defaultEnabled

    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    private var groups: [(title: String, stages: [LyricStage])] {
        var order: [String] = []
        var map: [String: [LyricStage]] = [:]
        for stage in LyricStage.all {
            if map[stage.group] == nil { order.append(stage.group) }
            map[stage.group, default: []].append(stage)
        }
        return order.map { ($0, map[$0] ?? []) }
    }

    var body: some View {
        BeansNavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Toggle(isOn: $stageEnabled) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("在歌词页启用舞台")
                                .font(BeansFont.appFont(14, .semibold))
                                .foregroundStyle(Color.beansLabel)
                            Text("开启后歌词页由动态舞台演出，左右滑动返回仍然可用。")
                                .font(BeansFont.appFont(11))
                                .foregroundStyle(Color.beansComment)
                        }
                    }
                    .tint(Color.beansAmber)
                    .padding(14)
                    .background { BeansSurface(shape: RoundedRectangle(cornerRadius: 18, style: .continuous)) }

                    Button {
                        BeansHaptics.tap()
                        stageEnabled = false
                    } label: {
                        HStack {
                            Image(systemName: "music.note.list")
                            Text("使用原生歌词（不使用舞台）")
                            Spacer()
                            if !stageEnabled {
                                Image(systemName: "checkmark")
                            }
                        }
                        .font(BeansFont.appFont(13, .medium))
                        .foregroundStyle(!stageEnabled ? Color.beansAmber : Color.beansLabel)
                        .padding(14)
                        .background {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(!stageEnabled ? Color.beansAmber.opacity(0.12) : Color.primary.opacity(0.04))
                        }
                    }
                    .buttonStyle(.plain)

                    ForEach(Array(groups.enumerated()), id: \.offset) { _, group in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(group.title)
                                .font(BeansFont.appFont(13, .bold))
                                .foregroundStyle(Color.beansComment)
                                .padding(.horizontal, 2)
                            LazyVGrid(columns: columns, spacing: 10) {
                                ForEach(group.stages) { stage in
                                    stageCard(stage)
                                }
                            }
                        }
                    }

                    Text("共 \(LyricStage.all.count) 种舞台效果，移植自开源项目 liziair（原项目为 Web 实现，这里打包进 App 离线运行）。效果较吃性能，低电量或发热时建议关掉。")
                        .font(BeansFont.appFont(11))
                        .foregroundStyle(Color.beansComment)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 4)
                }
                .padding(16)
                .padding(.bottom, 30)
            }
            .navigationTitle("歌词舞台")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    private func stageCard(_ stage: LyricStage) -> some View {
        let active = stageEnabled && selectedID == stage.id
        return Button {
            BeansHaptics.select()
            selectedID = stage.id
            stageEnabled = true
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [stage.tint.opacity(0.95), stage.tint.opacity(0.45)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 42, height: 42)
                    Image(systemName: "waveform")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                }
                Text(stage.name)
                    .font(BeansFont.appFont(12, .semibold))
                    .foregroundStyle(Color.beansLabel)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                if active {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.beansAmber)
                }
            }
            .padding(9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(active ? Color.beansAmber.opacity(0.12) : Color.primary.opacity(0.04))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(active ? Color.beansAmber.opacity(0.55) : .clear, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}
