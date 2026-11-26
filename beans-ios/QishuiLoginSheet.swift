import SwiftUI
import UIKit

/// 汽水音乐账号：粘贴网页 Cookie 登录。
/// 汽水扫码要求官方 `bdms.js` 生成签名，这里先用 Cookie 方案，说明写清楚避免误以为要账号密码。
struct QishuiLoginSheet: View {
    @EnvironmentObject private var theme: ThemeStore
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var qishuiAuth = QishuiMusicAuth.shared
    private let api = QishuiMusicAPI.shared

    @State private var cookieText = ""
    @State private var signerURL = ""
    @State private var signerToken = ""
    @State private var showAdvanced = false
    @State private var saving = false
    @State private var message: String?

    var body: some View {
        BeansNavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    intro
                    cookieField
                    if qishuiAuth.isLoggedIn { loggedInCard }
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
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(qishuiAuth.isLoggedIn ? "更新" : "登录") { save() }
                        .disabled(saving || QishuiMusicAuth.normalize(cookieText).isEmpty)
                }
            }
            .onAppear {
                cookieText = qishuiAuth.cookieHeader
                signerURL = api.signerURL
                signerToken = api.signerToken
            }
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("用网页 Cookie 登录")
                .font(.system(size: 17, weight: .semibold))
            Text("1. 在电脑浏览器打开 music.douyin.com 并登录汽水音乐\n2. 按 F12 → Network → 任选一个请求 → 复制请求头里的 Cookie\n3. 粘贴到下面保存\n\nCookie 只保存在本机，不会上传到任何服务器。不登录也能在主页浏览推荐歌单；登录后个人歌单会同步到音乐库「全部歌单」。")
                .font(.system(size: 13))
                .foregroundStyle(Color.beansComment)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { BeansGlass(shape: RoundedRectangle(cornerRadius: 18, style: .continuous)) }
    }

    private var cookieField: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Cookie")
                    .font(.system(size: 13, weight: .medium))
                Spacer()
                Button("从剪贴板粘贴") {
                    if let text = UIPasteboard.general.string {
                        cookieText = text
                    }
                }
                .font(.system(size: 12.5))
            }
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.primary.opacity(0.06))
                TextEditor(text: $cookieText)
                    .font(.system(size: 12, design: .monospaced))
                    .frame(minHeight: 96)
                    .padding(8)
                    .background(Color.clear)
            }
            if !qishuiAuth.cookieHeader.isEmpty {
                Text("当前已保存的 Cookie 含 \(QishuiMusicAuth.parseCookie(qishuiAuth.cookieHeader).count) 个字段")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Color.beansComment)
            }
        }
        .padding(14)
        .background { BeansGlass(shape: RoundedRectangle(cornerRadius: 18, style: .continuous)) }
    }

    private var loggedInCard: some View {
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
        .padding(14)
        .background { BeansGlass(shape: RoundedRectangle(cornerRadius: 18, style: .continuous)) }
    }

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
