import SwiftUI
import UIKit

/// 汽水音乐账号。
///
/// 主路径：**应用内扫码登录**。走官方 Passport 二维码接口（免签名），
/// 用抖音 / 汽水 App 扫一扫即可，登录态由轮询接口直接下发。
/// 兜底路径：网页 Cookie 粘贴，方便浏览器已登录或扫码受限的情况。
struct QishuiLoginSheet: View {
    @EnvironmentObject private var theme: ThemeStore
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var qishuiAuth = QishuiMusicAuth.shared
    private let api = QishuiMusicAPI.shared

    @State private var cookieText = ""
    @State private var signerURL = ""
    @State private var signerToken = ""
    @State private var showAdvanced = false
    @State private var showCookieFallback = false
    @State private var showQRLogin = false
    @State private var saving = false
    @State private var message: String?

    var body: some View {
        BeansNavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if qishuiAuth.isLoggedIn {
                        loggedInCard
                    } else {
                        loginHero
                    }

                    cookieFallbackSection
                    advancedSection

                    if let message {
                        Text(message)
                            .font(.system(size: 12.5))
                            .foregroundStyle(Color.beansComment)
                    }
                }
                .padding(18)
                .padding(.bottom, 30)
            }
            .background { GlassBackdrop() }
            .navigationTitle("汽水音乐")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") { dismiss() }
                }
            }
            .onAppear {
                cookieText = qishuiAuth.cookieHeader
                signerURL = api.signerURL
                signerToken = api.signerToken
            }
        }
        .sheet(isPresented: $showQRLogin) {
            QishuiQRLoginSheet {
                message = "汽水音乐登录成功"
            }
            .environmentObject(theme)
        }
    }

    // MARK: - 主入口

    private var loginHero: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.beansAmber.opacity(0.95), Color.beansAmber.opacity(0.55)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 46, height: 46)
                    Image(systemName: "music.note")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("登录汽水音乐")
                        .font(.system(size: 17, weight: .semibold))
                    Text("抖音 / 汽水 App 扫一扫，几秒完成")
                        .font(.system(size: 12.5))
                        .foregroundStyle(Color.beansComment)
                }
            }

            Text("登录后个人歌单会同步到音乐库「全部歌单」，歌曲进入「全部歌曲」云同步。不登录也可以浏览主页的推荐歌单。")
                .font(.system(size: 12.5))
                .foregroundStyle(Color.beansComment)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                BeansHaptics.tap()
                showQRLogin = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "qrcode.viewfinder")
                        .font(.system(size: 15, weight: .semibold))
                    Text("扫码登录")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(Color.beansAmber, in: Capsule())
            }
            .buttonStyle(GlassPressButtonStyle(scale: 0.96))

            Text("二维码由汽水官方接口生成，用抖音或汽水 App 扫一扫即可；登录态只保存在本机。")
                .font(.system(size: 11.5))
                .foregroundStyle(Color.beansComment.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { BeansGlass(shape: RoundedRectangle(cornerRadius: 18, style: .continuous)) }
    }

    // MARK: - 已登录

    private var loggedInCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Color.green)
                VStack(alignment: .leading, spacing: 3) {
                    Text(qishuiAuth.nickname.isEmpty ? "已保存登录状态" : qishuiAuth.nickname)
                        .font(.system(size: 14, weight: .medium))
                    Text(qishuiAuth.userId.isEmpty ? "账号 ID 会在首次刷新资料后显示" : "ID \(qishuiAuth.userId)")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Color.beansComment)
                }
                Spacer()
                Button("退出") {
                    qishuiAuth.logout()
                    cookieText = ""
                    message = "已退出汽水音乐"
                }
                .font(.system(size: 12.5))
                .foregroundStyle(.red)
            }

            Button {
                BeansHaptics.tap()
                showQRLogin = true
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text("重新登录")
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.beansAmber)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { BeansGlass(shape: RoundedRectangle(cornerRadius: 18, style: .continuous)) }
    }

    // MARK: - Cookie 兜底

    private var cookieFallbackSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { showCookieFallback.toggle() }
            } label: {
                HStack {
                    Text("网页登录不可用？粘贴 Cookie")
                        .font(.system(size: 13, weight: .medium))
                    Spacer()
                    Image(systemName: showCookieFallback ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(Color.beansLabel)
            }
            .buttonStyle(.plain)

            if showCookieFallback {
                Text("1. 在电脑浏览器打开 music.douyin.com 并登录\n2. F12 → Network → 任选一个请求 → 复制请求头里的 Cookie\n3. 粘贴到下面保存")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.beansComment)
                    .fixedSize(horizontal: false, vertical: true)

                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.primary.opacity(0.06))
                    TextEditor(text: $cookieText)
                        .font(.system(size: 12, design: .monospaced))
                        .frame(minHeight: 92)
                        .padding(8)
                        .background(Color.clear)
                }

                HStack(spacing: 12) {
                    Button("从剪贴板粘贴") {
                        if let text = UIPasteboard.general.string {
                            cookieText = text
                        }
                    }
                    .font(.system(size: 12.5))

                    Spacer()

                    Button(saving ? "保存中…" : "保存 Cookie") {
                        save()
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.beansAmber)
                    .disabled(saving || QishuiMusicAuth.normalize(cookieText).isEmpty)
                }

                if !qishuiAuth.cookieHeader.isEmpty {
                    Text("当前已保存的 Cookie 含 \(QishuiMusicAuth.parseCookie(qishuiAuth.cookieHeader).count) 个字段")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Color.beansComment)
                }
            }
        }
        .padding(14)
        .background { BeansGlass(shape: RoundedRectangle(cornerRadius: 18, style: .continuous)) }
    }

    // MARK: - 高级：搜索签名

    private var advancedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { showAdvanced.toggle() }
            } label: {
                HStack {
                    Text("高级：搜索签名服务（可选）")
                        .font(.system(size: 13, weight: .medium))
                    Spacer()
                    Image(systemName: showAdvanced ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(Color.beansLabel)
            }
            .buttonStyle(.plain)

            if showAdvanced {
                Text("汽水把搜索与 App 播放流放在 `X-Helios` / `X-Medusa` 签名后面，没有公开的本地算法。\n填写自己部署的签名服务后才会启用搜索；留空时只有浏览、歌词与曲目播放可用。签名请求不会携带 Cookie。")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.beansComment)
                    .fixedSize(horizontal: false, vertical: true)
                TextField("签名地址，例如 https://your-host/sign", text: $signerURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.system(size: 12, design: .monospaced))
                    .padding(10)
                    .background {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.primary.opacity(0.06))
                    }
                TextField("Bearer Token（可留空）", text: $signerToken)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.system(size: 12, design: .monospaced))
                    .padding(10)
                    .background {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.primary.opacity(0.06))
                    }
                Button("保存签名设置") {
                    api.signerURL = signerURL
                    api.signerToken = signerToken
                    message = api.hasSigner ? "签名服务已保存，搜索可用" : "签名地址无效，已关闭搜索"
                }
                .font(.system(size: 13, weight: .medium))
            }
        }
        .padding(14)
        .background { BeansGlass(shape: RoundedRectangle(cornerRadius: 18, style: .continuous)) }
    }

    // MARK: - Cookie 保存

    private func save() {
        let cookie = QishuiMusicAuth.normalize(cookieText)
        guard !cookie.isEmpty else { return }
        saving = true
        message = nil
        qishuiAuth.saveCookie(cookie)
        Task {
            let ok = await QishuiMusicAPI.shared.refreshProfile()
            await MainActor.run {
                saving = false
                if ok {
                    message = "登录成功：\(qishuiAuth.nickname.isEmpty ? "汽水音乐" : qishuiAuth.nickname)"
                    ToastCenter.shared.show("汽水个人歌单已加入音乐库；歌曲可在音乐库右上角云同步汇总")
                    dismiss()
                } else {
                    message = "Cookie 已保存，但资料校验没通过。若播放仍失败，请确认复制的是 music.douyin.com 的完整 Cookie。"
                }
            }
        }
    }
}
