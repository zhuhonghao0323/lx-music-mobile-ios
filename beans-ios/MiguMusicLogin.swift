import Foundation
import SwiftUI
import WebKit

// MARK: - 咪咕账号

/// 咪咕音乐登录态。咪咕没有开放平台，网页版登录走 `passport.migu.cn` 的 iframe，
/// App 侧只保存完整 Cookie（由 WKWebView 里的真实登录产生），不会上传账号密码。
final class MiguMusicAuth: ObservableObject {
    static let shared = MiguMusicAuth()

    @Published private(set) var isLoggedIn = false
    @Published private(set) var nickname = ""
    @Published private(set) var playlists: [Playlist] = []
    @Published private(set) var savedAt: Date = .distantPast

    private let authKey = "beans.migu.auth.v1"
    private let playlistsKey = "beans.migu.playlists.v1"
    private var cookie = ""

    private init() {
        if let saved = UserDefaults.standard.dictionary(forKey: authKey) as? [String: String] {
            cookie = saved["cookie"] ?? ""
            nickname = saved["nickname"] ?? ""
            isLoggedIn = !cookie.isEmpty
        }
        if let data = UserDefaults.standard.data(forKey: playlistsKey),
           let list = try? JSONDecoder().decode([Playlist].self, from: data) {
            playlists = list
        }
        if let t = UserDefaults.standard.object(forKey: playlistsKey + ".at") as? Date {
            savedAt = t
        }
    }

    var cookieHeader: String { cookie }

    func saveLogin(cookie: String, nickname: String) {
        guard !cookie.isEmpty else { return }
        self.cookie = cookie
        self.nickname = nickname.isEmpty ? "咪咕用户" : nickname
        isLoggedIn = true
        UserDefaults.standard.set([
            "cookie": self.cookie,
            "nickname": self.nickname
        ], forKey: authKey)
        NotificationCenter.default.post(name: .beansMiguLoginDidUpdate, object: nil)
    }

    func savePlaylists(_ list: [Playlist]) {
        playlists = list
        savedAt = Date()
        if let data = try? JSONEncoder().encode(list) {
            UserDefaults.standard.set(data, forKey: playlistsKey)
            UserDefaults.standard.set(savedAt, forKey: playlistsKey + ".at")
        }
    }

    func logout() {
        cookie = ""
        nickname = ""
        isLoggedIn = false
        playlists = []
        UserDefaults.standard.removeObject(forKey: authKey)
        UserDefaults.standard.removeObject(forKey: playlistsKey)
        UserDefaults.standard.removeObject(forKey: playlistsKey + ".at")
        WebLoginDataCleaner.clearMigu()
        NotificationCenter.default.post(name: .beansMiguLoginDidUpdate, object: nil)
    }
}

// MARK: - 咪咕登录页

struct MiguLoginSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var theme: ThemeStore
    @ObservedObject private var auth = MiguMusicAuth.shared

    @State private var status = "正在打开咪咕音乐网页…"
    @State private var busy = false
    @State private var loginPromptToken = 0
    @State private var manualCookie = ""
    @State private var showManualCookie = false
    @State private var manualLink = ""
    @State private var imported: [Playlist] = []

    var body: some View {
        BeansNavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if auth.isLoggedIn {
                        loggedInCard
                    } else {
                        webCard
                    }
                    if !auth.playlists.isEmpty {
                        playlistCard
                    }
                    Text("咪咕音乐网页版使用 passport.migu.cn 登录（手机号 / 扫码 / 第三方）。App 只保存登录后的 Cookie，用于读取「我的歌单」与会员状态，不会上传账号信息。\n咪咕暂不支持按链接导入歌单，登录后会自动同步。")
                        .font(BeansFont.appFont(11))
                        .foregroundStyle(Color.beansComment)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
                .padding(.bottom, 30)
            }
            .background {
                GlassBackdrop(customColor: theme.backgroundSyncAll ? theme.customBackground : nil)
            }
            .navigationTitle("咪咕音乐")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    LibraryBackButton { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    private var loggedInCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Color(red: 0.93, green: 0.30, blue: 0.35))
                VStack(alignment: .leading, spacing: 2) {
                    Text(auth.nickname)
                        .font(BeansFont.appFont(15, .semibold))
                        .foregroundStyle(Color.beansLabel)
                    Text("已登录 · \(auth.playlists.count) 个歌单")
                        .font(BeansFont.appFont(11))
                        .foregroundStyle(Color.beansComment)
                }
                Spacer(minLength: 0)
                Button("退出") {
                    auth.logout()
                    status = "已退出咪咕账号"
                }
                .font(BeansFont.appFont(12, .semibold))
                .foregroundStyle(.red)
            }
            Text(status)
                .font(BeansFont.appFont(11))
                .foregroundStyle(Color.beansComment)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                Task { await refreshPlaylists() }
            } label: {
                HStack {
                    if busy { ProgressView().controlSize(.small) }
                    Text(busy ? "正在读取歌单…" : "刷新我的歌单")
                    Spacer()
                    Image(systemName: "arrow.clockwise")
                }
                .font(BeansFont.appFont(13, .semibold))
                .foregroundStyle(Color(red: 0.93, green: 0.30, blue: 0.35))
                .padding(12)
                .background(Color(red: 0.93, green: 0.30, blue: 0.35).opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background { BeansSurface(shape: RoundedRectangle(cornerRadius: 20, style: .continuous)) }
    }

    private var webCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "person.crop.circle.badge.checkmark")
                    .foregroundStyle(Color(red: 0.93, green: 0.30, blue: 0.35))
                Text("登录咪咕账号")
                    .font(BeansFont.appFont(14, .semibold))
                    .foregroundStyle(Color.beansLabel)
                Spacer()
                if busy { ProgressView().controlSize(.mini) }
            }
            Text(status)
                .font(BeansFont.appFont(11))
                .foregroundStyle(Color.beansComment)
                .fixedSize(horizontal: false, vertical: true)

            MiguLoginWebView(loginPromptToken: loginPromptToken) { cookie, nickname, playlists in
                guard !cookie.isEmpty else { return }
                auth.saveLogin(cookie: cookie, nickname: nickname)
                if !playlists.isEmpty {
                    auth.savePlaylists(playlists)
                    status = "已登录，读到 \(playlists.count) 个歌单"
                } else {
                    status = "已登录；网页没有返回歌单，可稍后点「刷新我的歌单」"
                }
            }
            .frame(height: 460)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            Button {
                loginPromptToken += 1
            } label: {
                Text("没看到登录框？点这里重新打开")
                    .font(BeansFont.appFont(11.5, .semibold))
                    .foregroundStyle(Color(red: 0.93, green: 0.30, blue: 0.35))
            }
            .buttonStyle(.plain)

            Button {
                showManualCookie.toggle()
            } label: {
                Text(showManualCookie ? "收起手动 Cookie" : "已在浏览器登录？粘贴 Cookie")
                    .font(BeansFont.appFont(11.5, .semibold))
                    .foregroundStyle(Color(red: 0.93, green: 0.30, blue: 0.35))
            }
            .buttonStyle(.plain)

            if showManualCookie {
                VStack(alignment: .leading, spacing: 8) {
                    TextEditor(text: $manualCookie)
                        .font(.system(size: 11, design: .monospaced))
                        .frame(height: 86)
                        .padding(8)
                        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
                    Button("保存 Cookie") {
                        let raw = manualCookie.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard raw.contains("=") else {
                            status = "Cookie 格式不对，请复制完整的 Cookie 字符串"
                            return
                        }
                        auth.saveLogin(cookie: raw, nickname: "咪咕用户")
                        status = "Cookie 已保存，正在读取歌单…"
                        Task { await refreshPlaylists() }
                    }
                    .font(BeansFont.appFont(12, .semibold))
                    .foregroundStyle(Color(red: 0.93, green: 0.30, blue: 0.35))
                }
            }
        }
        .padding(14)
        .background { BeansSurface(shape: RoundedRectangle(cornerRadius: 20, style: .continuous)) }
    }

    private var manualCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("手动导入歌单")
                .font(BeansFont.appFont(13, .semibold))
                .foregroundStyle(Color.beansLabel)
            Text("粘贴咪咕歌单分享链接，无需登录即可导入到本地歌单。")
                .font(BeansFont.appFont(11))
                .foregroundStyle(Color.beansComment)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                TextField("歌单链接", text: $manualLink)
                    .font(BeansFont.appFont(12))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 10)
                    .padding(.vertical, 9)
                    .background(Color.primary.opacity(0.05), in: Capsule())
                Button("导入") {
                    Task { await importManual() }
                }
                .font(BeansFont.appFont(12, .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(Color(red: 0.93, green: 0.30, blue: 0.35), in: Capsule())
                .disabled(busy || manualLink.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(14)
        .background { BeansSurface(shape: RoundedRectangle(cornerRadius: 20, style: .continuous)) }
    }

    private var playlistCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("我的咪咕歌单")
                .font(BeansFont.appFont(13, .semibold))
                .foregroundStyle(Color.beansLabel)
            ForEach(auth.playlists) { playlist in
                HStack(spacing: 10) {
                    CoverImage(url: playlist.coverURL, size: 40, cornerRadius: 9)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(playlist.name)
                            .font(BeansFont.appFont(13, .medium))
                            .foregroundStyle(Color.beansLabel)
                            .lineLimit(1)
                        Text(beansSongCountText(playlist.trackCount))
                            .font(BeansFont.appFont(10.5))
                            .foregroundStyle(Color.beansComment)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 3)
            }
        }
        .padding(14)
        .background { BeansSurface(shape: RoundedRectangle(cornerRadius: 20, style: .continuous)) }
    }

    private func refreshPlaylists() async {
        guard !busy else { return }
        busy = true
        defer { busy = false }
        let list = await MiguWebPlaylistLoader.load(cookie: auth.cookieHeader)
        if list.isEmpty {
            status = auth.playlists.isEmpty
                ? "没有读到歌单：咪咕网页接口需要有效登录态，可退出后重新登录一次"
                : "刷新失败，继续显示上次读到的 \(auth.playlists.count) 个歌单"
        } else {
            auth.savePlaylists(list)
            status = "已读取 \(list.count) 个歌单"
        }
    }

    private func importManual() async {
        let raw = manualLink.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return }
        busy = true
        defer { busy = false }
        do {
            let payload = try await PlaylistImportService.fetch(text: raw, preferred: .migu)
            ImportedPlaylistStore.shared.upsert(
                name: payload.playlist.name,
                source: .migu,
                sourceID: payload.sourceID,
                coverURL: payload.playlist.coverURL,
                trackCount: payload.songs.count,
                songs: payload.songs
            )
            manualLink = ""
            status = "已导入「\(payload.playlist.name)」\(payload.songs.count) 首"
        } catch {
            status = "导入失败：\(error.localizedDescription)"
        }
    }
}

// MARK: - 咪咕登录 WKWebView

private struct MiguLoginWebView: UIViewRepresentable {
    var loginPromptToken: Int = 0
    let onLogin: (String, String, [Playlist]) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onLogin: onLogin) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        webView.load(URLRequest(url: URL(string: "https://music.migu.cn/v5/")!))
        context.coordinator.start(webView: webView)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard context.coordinator.lastPromptToken != loginPromptToken else { return }
        context.coordinator.lastPromptToken = loginPromptToken
        if loginPromptToken > 0 {
            webView.evaluateJavaScript(Coordinator.openLoginJS, completionHandler: nil)
        }
    }

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        coordinator.stop()
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        private let onLogin: (String, String, [Playlist]) -> Void
        private weak var webView: WKWebView?
        private var timer: Timer?
        private var reported = false
        private var openedLoginPanel = false
        private var delivered = false
        var lastPromptToken = 0

        init(onLogin: @escaping (String, String, [Playlist]) -> Void) {
            self.onLogin = onLogin
        }

        func start(webView: WKWebView) {
            self.webView = webView
            timer?.invalidate()
            let timer = Timer(timeInterval: 1.5, repeats: true) { [weak self] _ in
                self?.probe()
            }
            RunLoop.main.add(timer, forMode: .common)
            self.timer = timer
        }

        func stop() {
            timer?.invalidate()
            timer = nil
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard !openedLoginPanel, !reported else { return }
            openedLoginPanel = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak webView] in
                webView?.evaluateJavaScript(Self.openLoginJS, completionHandler: nil)
            }
        }

        private func probe() {
            guard !reported, let webView else { return }
            // 咪咕 v5 顶栏的「登录」是 div.login，登录成功后会被昵称替换
            webView.evaluateJavaScript("(function(){var e=document.querySelector('div.login');return e&&(e.innerText||'').indexOf('登录')>=0?'0':'1';})()") { [weak self] result, _ in
                guard let self, !self.reported else { return }
                guard (result as? String) == "1" else { return }
                webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
                    guard !self.reported else { return }
                    let migu = cookies.filter { $0.domain.contains("migu.cn") }
                    guard !migu.isEmpty else { return }
                    let header = migu.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
                    let name = migu.first { $0.name.lowercased().contains("nickname") || $0.name.lowercased().contains("username") }?.value ?? ""
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        guard !self.reported else { return }
                        self.reported = true
                        self.collectPlaylists(cookie: header, nickname: name)
                    }
                }
            }
        }

        private func collectPlaylists(cookie: String, nickname: String) {
            guard let webView else {
                deliver(cookie: cookie, nickname: nickname, list: [])
                return
            }
            webView.load(URLRequest(url: URL(string: "https://music.migu.cn/v5/#/my")!))
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                self?.scrape(cookie: cookie, nickname: nickname, attempt: 0)
            }
        }

        private func scrape(cookie: String, nickname: String, attempt: Int) {
            guard let webView, !delivered else { return }
            webView.evaluateJavaScript(Self.scrapeJS) { [weak self] result, _ in
                guard let self, !self.delivered else { return }
                let list = Self.parse(result)
                if !list.isEmpty {
                    self.deliver(cookie: cookie, nickname: nickname, list: list)
                } else if attempt < 2 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                        self.scrape(cookie: cookie, nickname: nickname, attempt: attempt + 1)
                    }
                } else {
                    self.deliver(cookie: cookie, nickname: nickname, list: [])
                }
            }
        }

        private func deliver(cookie: String, nickname: String, list: [Playlist]) {
            guard !delivered else { return }
            delivered = true
            onLogin(cookie, nickname, list)
        }

        static let openLoginJS = """
        (function(){
          var n = 0;
          var t = setInterval(function(){
            var el = document.querySelector('div.login');
            if (el && (el.innerText || '').indexOf('登录') >= 0) {
              el.click();
              clearInterval(t);
            }
            if (++n > 100) { clearInterval(t); }
          }, 300);
          return 'ok';
        })()
        """

        private static let scrapeJS = #"""
        (function(){
          var out=[],seen={};
          var sel='a[href*="playlist"], a[href*="playList"], a[href*="gedan"]';
          document.querySelectorAll(sel).forEach(function(a){
            var href=a.getAttribute('href')||'';
            var m=href.match(/(?:playlist|playList|gedan)[^0-9]*(\d{5,})/i) || href.match(/(\d{8,})/);
            if(!m) return;
            var id=m[1];
            if(seen[id]) return;
            var name=(a.innerText||a.textContent||'').replace(/\s+/g,' ').trim();
            if(!name || name.length<1) return;
            if(name.indexOf('登录')>=0) return;
            seen[id]=1;
            var img=a.querySelector('img');
            out.push({id:id,name:name.slice(0,60),cover:img?img.src:''});
          });
          return JSON.stringify(out);
        })()
        """#

        static func parse(_ result: Any?) -> [Playlist] {
            guard let text = result as? String,
                  let data = text.data(using: .utf8),
                  let raw = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                return []
            }
            return raw.compactMap { item in
                guard let idText = item["id"] as? String, let pid = Int(idText), pid > 0 else { return nil }
                let name = (item["name"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { return nil }
                let cover = item["cover"] as? String ?? ""
                return Playlist(id: pid, name: name,
                                coverURL: cover.hasPrefix("http") ? URL(string: cover) : nil,
                                trackCount: 0, source: .migu, externalID: "\(pid)")
            }
        }
    }
}

// MARK: - 已保存 Cookie 的兜底读取

/// 登录态已经存在时（重开 App），用保存的 Cookie 在后台跑一次无界面 WKWebView：
/// 咪咕接口签名依赖真实浏览器环境，原生 URLSession 很难通过，所以仍然借网页上下文。
enum MiguWebPlaylistLoader {
    static func load(cookie: String) async -> [Playlist] {
        guard !cookie.isEmpty else { return [] }
        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                let loader = MiguHeadlessLoader(cookie: cookie) { list in
                    continuation.resume(returning: list)
                }
                loader.start()
            }
        }
    }
}

private final class MiguHeadlessLoader: NSObject, WKNavigationDelegate {
    /// 必须持有自己：WKWebView 的 delegate 是 weak，闭包里也只用 weak self，
    /// 没有这个数组的话 loader 会在 await 期间被释放，continuation 永远不返回。
    private static var running: [MiguHeadlessLoader] = []

    private let cookie: String
    private let completion: ([Playlist]) -> Void
    private var webView: WKWebView?
    private var finished = false
    private var attempts = 0

    init(cookie: String, completion: @escaping ([Playlist]) -> Void) {
        self.cookie = cookie
        self.completion = completion
    }

    func start() {
        Self.running.append(self)
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        self.webView = webView
        let store = webView.configuration.websiteDataStore.httpCookieStore
        let group = DispatchGroup()
        for pair in cookie.split(separator: ";") {
            let parts = pair.split(separator: "=", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }
            let properties: [HTTPCookiePropertyKey: Any] = [
                .name: parts[0].trimmingCharacters(in: .whitespaces),
                .value: parts[1],
                .domain: ".migu.cn",
                .path: "/"
            ]
            if let httpCookie = HTTPCookie(properties: properties) {
                group.enter()
                store.setCookie(httpCookie) { group.leave() }
            }
        }
        group.notify(queue: .main) {
            webView.load(URLRequest(url: URL(string: "https://music.migu.cn/v5/#/my")!))
            DispatchQueue.main.asyncAfter(deadline: .now() + 6.5) { [weak self] in
                self?.scrape()
            }
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {}

    private func scrape() {
        guard !finished, let webView else { return }
        attempts += 1
        webView.evaluateJavaScript(Self.scrapeJS) { [weak self] result, _ in
            guard let self, !self.finished else { return }
            let list = MiguLoginWebView.Coordinator.parse(result)
            if !list.isEmpty || self.attempts >= 3 {
                self.finished = true
                Self.running.removeAll { $0 === self }
                self.completion(list)
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { self.scrape() }
            }
        }
    }

    private static let scrapeJS = #"""
    (function(){
      var out=[],seen={};
      document.querySelectorAll('a[href*="playlist"], a[href*="playList"]').forEach(function(a){
        var href=a.getAttribute('href')||'';
        var m=href.match(/(\d{5,})/);
        if(!m) return;
        var id=m[1];
        if(seen[id]) return;
        var name=(a.innerText||a.textContent||'').replace(/\s+/g,' ').trim();
        if(!name || name.indexOf('登录')>=0) return;
        seen[id]=1;
        var img=a.querySelector('img');
        out.push({id:id,name:name.slice(0,60),cover:img?img.src:''});
      });
      return JSON.stringify(out);
    })()
    """#
}
