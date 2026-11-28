import SwiftUI
import UIKit

// MARK: - 汽水音乐扫码登录
//
// 汽水没有消费级网页版（music.douyin.com 是「合作平台」落地页），
// 但官方 Passport 的二维码接口对 PC 客户端开放：
//   GET  /passport/web/get_qrcode/      取二维码 token + PNG
//   POST /passport/web/check_qrconnect/ 轮询扫码状态，确认后 Set-Cookie 下发登录态
// 两个接口都**不需要** a_bogus 签名（实测），所以这里用原生 URLSession 走完整流程，
// 不去逆向 bdms.js，也不接触账号密码。用户用抖音 App 扫一扫即可。

@MainActor
final class QishuiQRLoginStore: ObservableObject {
    enum Phase: Equatable {
        case loading
        case waiting
        case scanned
        case success
        case expired
        case failed(String)
    }

    @Published private(set) var phase: Phase = .loading
    @Published private(set) var qrImage: UIImage?
    @Published private(set) var expiresAt: Date = .distantPast

    private var token = ""
    private var cookies: [String: String] = [:]
    private var pollTask: Task<Void, Never>?
    private let session: URLSession

    private static let host = "https://api.qishui.com"
    private static let userAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36"

    init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 30
        // 自己管理 Cookie，避免污染 App 的共享 Cookie 存储
        config.httpShouldSetCookies = false
        config.httpCookieAcceptPolicy = .never
        session = URLSession(configuration: config)
    }

    // MARK: - 对外

    func start() {
        cancel()
        phase = .loading
        qrImage = nil
        token = ""
        cookies = [:]
        pollTask = Task { [weak self] in
            await self?.loadQRCode()
        }
    }

    func cancel() {
        pollTask?.cancel()
        pollTask = nil
    }

    // MARK: - 流程

    private func loadQRCode() async {
        do {
            let response = try await request(
                path: "/passport/web/get_qrcode/",
                method: "GET",
                query: [
                    "aid": "386088",
                    "passport_jssdk_version": "2.4.13",
                    "passport_jssdk_type": "normal",
                    "is_from_ttaccountsdk": "1",
                    "next": Self.host,
                    "need_logo": "false",
                    "need_short_url": "false",
                    "is_new_login": "1"
                ]
            )
            absorb(response)
            guard let data = response.json["data"] as? [String: Any],
                  let token = data["token"] as? String,
                  !token.isEmpty,
                  let qr = data["qrcode"] as? String,
                  let image = Self.decodeDataURL(qr) else {
                phase = .failed("二维码获取失败，请稍后重试")
                return
            }
            self.token = token
            self.qrImage = image
            if let number = data["expire_time"] as? NSNumber {
                self.expiresAt = Date(timeIntervalSince1970: number.doubleValue)
            } else {
                self.expiresAt = Date().addingTimeInterval(180)
            }
            self.phase = .waiting
            await poll()
        } catch {
            phase = .failed("网络连接失败，请检查网络后重试")
        }
    }

    private func poll() async {
        while !Task.isCancelled {
            if Date() > expiresAt {
                phase = .expired
                return
            }
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            if Task.isCancelled { return }

            do {
                let response = try await request(
                    path: "/passport/web/check_qrconnect/",
                    method: "POST",
                    query: [
                        "aid": "386088",
                        "passport_jssdk_version": "2.4.13",
                        "passport_jssdk_type": "normal",
                        "is_from_ttaccountsdk": "1"
                    ],
                    form: [
                        "token": token,
                        "need_logo": "false",
                        "need_short_url": "false",
                        "is_frontier": "true",
                        "is_new_login": "1",
                        "next": Self.host
                    ]
                )
                absorb(response)
                let data = response.json["data"] as? [String: Any] ?? [:]
                let errorCode = (data["error_code"] as? NSNumber)?.intValue ?? 0
                let status = ((data["status"] as? String) ?? "").lowercased()

                // 2046：官方要求额外安全验证（图形/滑块），原生流程做不了
                if errorCode == 2046 {
                    phase = .failed("本次登录需要额外安全验证，请稍后重试或改用 Cookie 导入")
                    return
                }

                switch status {
                case "new", "unscanned", "1":
                    if phase != .waiting { phase = .waiting }
                case "scanned", "scaned", "2":
                    if phase != .scanned { phase = .scanned }
                case "confirmed", "confirm", "3", "success":
                    if hasSessionCookie {
                        await finish()
                        return
                    }
                    phase = .scanned
                case "expired", "canceled", "cancelled", "timeout", "-1":
                    phase = .expired
                    return
                default:
                    break
                }
            } catch {
                // 单次网络抖动不打断轮询
            }
        }
    }

    private var hasSessionCookie: Bool {
        !(cookies["sessionid"] ?? "").isEmpty || !(cookies["sessionid_ss"] ?? "").isEmpty
    }

    private func finish() async {
        let header = cookies
            .filter { !$0.value.isEmpty }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "; ")
        guard !header.isEmpty else {
            phase = .failed("没有读取到登录态，请刷新二维码重试")
            return
        }
        QishuiMusicAuth.shared.saveCookie(header)
        let ok = await QishuiMusicAPI.shared.refreshProfile()
        if ok {
            phase = .success
            BeansHaptics.success()
            ToastCenter.shared.show("汽水音乐登录成功")
        } else {
            phase = .failed("登录态已获取，但资料校验没通过，请重试")
        }
    }

    // MARK: - 网络

    private struct Response {
        let json: [String: Any]
        let setCookies: [HTTPCookie]
    }

    private func request(
        path: String,
        method: String,
        query: [String: String],
        form: [String: String]? = nil
    ) async throws -> Response {
        var components = URLComponents(string: Self.host + path)
        components?.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        guard let url = components?.url else { throw QishuiError.invalidResponse }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue(Self.host + "/", forHTTPHeaderField: "Referer")
        request.setValue(Self.host, forHTTPHeaderField: "Origin")
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        if let form {
            var body = URLComponents()
            body.queryItems = form.map { URLQueryItem(name: $0.key, value: $0.value) }
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            request.httpBody = body.percentEncodedQuery?.data(using: .utf8)
        }
        if !cookies.isEmpty {
            request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw QishuiError.invalidResponse }
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        var parsed: [HTTPCookie] = []
        if let raw = http.value(forHTTPHeaderField: "Set-Cookie") {
            parsed = HTTPCookie.cookies(withResponseHeaderFields: ["Set-Cookie": raw], for: url)
        }
        return Response(json: json, setCookies: parsed)
    }

    private var cookieHeader: String {
        cookies.map { "\($0.key)=\($0.value)" }.joined(separator: "; ")
    }

    /// 合并 Set-Cookie 与响应体里的 session_cookie（两种下发方式都出现过）
    private func absorb(_ response: Response) {
        for cookie in response.setCookies {
            cookies[cookie.name] = cookie.value
        }
        if let data = response.json["data"] as? [String: Any],
           let raw = data["session_cookie"] as? String {
            for (key, value) in QishuiMusicAuth.parseCookie(raw) {
                cookies[key] = value
            }
        }
    }

    private static func decodeDataURL(_ raw: String) -> UIImage? {
        let base64: String
        if let comma = raw.firstIndex(of: ",") {
            base64 = String(raw[raw.index(after: comma)...])
        } else {
            base64 = raw
        }
        guard let data = Data(base64Encoded: base64, options: .ignoreUnknownCharacters) else { return nil }
        return UIImage(data: data)
    }
}

// MARK: - 扫码面板

struct QishuiQRLoginSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var store = QishuiQRLoginStore()
    let onSuccess: () -> Void

    var body: some View {
        BeansNavigationStack {
            VStack(spacing: 16) {
                Text("打开「抖音」或「汽水音乐」App → 右上角扫一扫 → 确认登录")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.beansComment)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.top, 8)

                qrCard

                statusLine

                Button {
                    BeansHaptics.tap()
                    store.start()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                        Text(store.phase == .expired || isFailed ? "刷新二维码" : "重新获取")
                    }
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundStyle(Color.beansAmber)
                }
                .buttonStyle(.plain)

                Spacer(minLength: 0)

                Text("二维码由汽水官方接口生成，登录态只保存在本机。")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Color.beansComment.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 10)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background { GlassBackdrop() }
            .navigationTitle("扫码登录汽水音乐")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") { dismiss() }
                }
            }
        }
        .onAppear { store.start() }
        .onDisappear { store.cancel() }
        .onChange(of: store.phase) { phase in
            guard phase == .success else { return }
            onSuccess()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { dismiss() }
        }
    }

    private var isFailed: Bool {
        if case .failed = store.phase { return true }
        return false
    }

    private var qrCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white)
                .frame(width: 236, height: 236)
                .shadow(color: .black.opacity(0.18), radius: 18, y: 8)

            if let image = store.qrImage {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .frame(width: 208, height: 208)
                    .opacity(store.phase == .expired ? 0.18 : 1)
            } else {
                ProgressView()
                    .tint(Color.beansAmber)
            }

            if store.phase == .expired {
                VStack(spacing: 8) {
                    Image(systemName: "qrcode.viewfinder")
                        .font(.system(size: 26, weight: .light))
                    Text("二维码已过期")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundStyle(.black.opacity(0.55))
            }

            if case .failed(let text) = store.phase, store.qrImage == nil {
                Text(text)
                    .font(.system(size: 12))
                    .foregroundStyle(.black.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .padding(24)
            }
        }
        .frame(height: 248)
    }

    @ViewBuilder
    private var statusLine: some View {
        switch store.phase {
        case .loading:
            label("正在获取二维码…", color: Color.beansComment, icon: "qrcode")
        case .waiting:
            label("等待扫码", color: Color.beansComment, icon: "qrcode.viewfinder")
        case .scanned:
            label("已扫码，请在手机上确认登录", color: Color.beansAmber, icon: "iphone.gen3")
        case .success:
            label("登录成功，正在同步歌单…", color: Color.beansSage, icon: "checkmark.circle.fill")
        case .expired:
            label("二维码已过期，点下方刷新", color: Color.red.opacity(0.75), icon: "clock.badge.exclamationmark")
        case .failed(let text):
            label(text, color: Color.red.opacity(0.8), icon: "exclamationmark.circle")
        }
    }

    private func label(_ text: String, color: Color, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
            Text(text)
                .font(.system(size: 13, weight: .medium))
        }
        .foregroundStyle(color)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 24)
    }
}
