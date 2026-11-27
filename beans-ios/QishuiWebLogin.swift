import SwiftUI
import WebKit

// MARK: - 汽水音乐网页登录（应用内完成扫码 / 手机验证码）
//
// 汽水没有公开登录接口：Passport 扫码要求官方 `bdms.js` 在 WebKit 里为同源请求生成
// `a_bogus` 签名，自己实现等于重写一遍字节跳动的风控。这里换个思路：
// 直接把官方网页放进 WKWebView，让用户在网页里用抖音扫码或手机号验证码登录，
// 登录态 Cookie 由官方页面自己写进 WKWebView 的 Cookie 存储，我们再读出来。
//
// 好处：不需要逆向签名、不接触账号密码，扫码 / 验证码都是官方页面原生能力；
// Cookie 只在本机流转，与原来的粘贴方案一样不上传任何第三方。

struct QishuiWebLoginPanel: View {
    @Environment(\.dismiss) private var dismiss
    let onSuccess: () -> Void

    @State private var pageLoaded = false
    @State private var syncing = false
    @State private var message = ""
    @State private var pollTask: Task<Void, Never>?

    var body: some View {
        BeansNavigationStack {
            VStack(spacing: 10) {
                Text("在下方网页点右上角「登录」，用抖音扫码或手机号验证码登录。\n登录成功后会自动同步，无需手动操作。")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Color.beansComment)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .padding(.top, 6)

                ZStack {
                    QishuiWebView(onLoaded: { pageLoaded = true })
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.7)
                        }
                        .padding(.horizontal, 14)

                    if !pageLoaded {
                        ProgressView("正在加载汽水音乐…")
                            .tint(Color.beansAmber)
                    }
                }
                .frame(maxHeight: .infinity)

                if !message.isEmpty {
                    Text(message)
                        .font(.system(size: 12))
                        .foregroundStyle(message.hasPrefix("✓") ? Color.beansSage : Color.red.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }

                Button {
                    Task { await syncNow() }
                } label: {
                    HStack(spacing: 6) {
                        if syncing {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "checkmark.circle")
                        }
                        Text(syncing ? "正在读取登录状态…" : "我已完成登录")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.beansAmber, in: Capsule())
                }
                .buttonStyle(GlassPressButtonStyle(scale: 0.96))
                .disabled(syncing)
                .padding(.horizontal, 20)
                .padding(.bottom, 10)
            }
            .background { GlassBackdrop() }
            .navigationTitle("登录汽水音乐")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") { dismiss() }
                }
            }
        }
        .onAppear { startPolling() }
        .onDisappear { pollTask?.cancel() }
    }

    // MARK: - 自动检测

    /// 登录成功后官方页面会把 `sessionid` 写进 WKWebView 的 Cookie 存储，
    /// 这里每 1.2 秒读一次，读到就直接落库并关页，用户不用点任何按钮。
    private func startPolling() {
        pollTask?.cancel()
        pollTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                if Task.isCancelled { return }
                if let cookie = await QishuiCookieReader.sessionCookie() {
                    syncing = true
                    await complete(with: cookie)
                    return
                }
            }
        }
    }

    @MainActor
    private func syncNow() async {
        syncing = true
        message = ""
        guard let cookie = await QishuiCookieReader.sessionCookie() else {
            syncing = false
            message = "还没有检测到登录状态，请先在网页里完成扫码或验证码登录"
            return
        }
        await complete(with: cookie)
    }

    @MainActor
    private func complete(with cookie: String) async {
        message = "已检测到登录态，正在同步…"
        QishuiMusicAuth.shared.saveCookie(cookie)
        let ok = await QishuiMusicAPI.shared.refreshProfile()
        syncing = false
        if ok {
            message = "✓ 汽水音乐登录成功"
            BeansHaptics.success()
            ToastCenter.shared.show("汽水个人歌单已加入音乐库")
            onSuccess()
            dismiss()
        } else {
            message = "登录态已保存，但资料校验没通过。可以再试一次，或改用 Cookie 粘贴。"
        }
    }
}

// MARK: - Cookie 读取

enum QishuiCookieReader {
    /// 读取 WKWebView 默认存储里所有 douyin.com 的 Cookie
    static func read(completion: @escaping (String) -> Void) {
        WKWebsiteDataStore.default().httpCookieStore.getAllCookies { cookies in
            var parts: [String] = []
            for cookie in cookies {
                let domain = cookie.domain.lowercased()
                guard domain.contains("douyin.com") else { continue }
                parts.append("\(cookie.name)=\(cookie.value)")
            }
            let header = parts.joined(separator: "; ")
            DispatchQueue.main.async {
                completion(header)
            }
        }
    }

    static func read() async -> String {
        await withCheckedContinuation { continuation in
            read { header in
                continuation.resume(returning: header)
            }
        }
    }

    /// 只认真正代表登录态的 `sessionid` / `sessionid_ss`
    static func sessionCookie() async -> String? {
        let header = await read()
        guard !header.isEmpty else { return nil }
        let map = QishuiMusicAuth.parseCookie(header)
        let hasSession = !(map["sessionid"] ?? "").isEmpty || !(map["sessionid_ss"] ?? "").isEmpty
        return hasSession ? header : nil
    }
}

// MARK: - WKWebView 封装

struct QishuiWebView: UIViewRepresentable {
    let onLoaded: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onLoaded: onLoaded)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        // 登录弹窗可能是 window.open 出来的，允许在同一个 WebView 内打开
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        let webView = WKWebView(frame: .zero, configuration: config)
        // 桌面版 Safari UA：music.douyin.com 会展示带「扫码登录 / 手机号登录」的完整网页版，
        // 移动端 UA 容易被引导去下载 App。
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Safari/605.1.15"
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        if let url = URL(string: "https://music.douyin.com/") {
            webView.load(URLRequest(url: url))
        }
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        let onLoaded: () -> Void

        init(onLoaded: @escaping () -> Void) {
            self.onLoaded = onLoaded
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.onLoaded()
            }
        }

        /// 登录弹窗走 window.open 时，直接在当前 WebView 里加载，避免点了没反应
        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            if navigationAction.targetFrame == nil {
                webView.load(navigationAction.request)
            }
            return nil
        }
    }
}
