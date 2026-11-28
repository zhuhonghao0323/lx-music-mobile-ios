import SwiftUI
import UIKit

// MARK: - 数据同步设置（WebDAV）

struct WebDAVSyncSettingsView: View {
    @EnvironmentObject private var theme: ThemeStore
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var sync = WebDAVSyncStore.shared

    @State private var password = ""
    @State private var testResult: String?
    @State private var testing = false

    var body: some View {
        BeansNavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    introCard
                    serverCard
                    actionCard
                    if sync.isConfigured { statusCard }
                    if let playback = sync.remotePlayback { remotePlaybackCard(playback) }
                    helpCard
                }
                .padding(16)
                .padding(.bottom, 32)
            }
            .background { GlassBackdrop() }
            .navigationTitle("数据同步")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        flushPassword()
                        ToastCenter.shared.show("同步配置已保存")
                    }
                }
            }
            .onAppear { password = sync.password }
        }
    }

    // MARK: 说明

    private var introCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("用 WebDAV 在 iPhone 与桌面端之间同步")
                .font(.system(size: 16, weight: .semibold))
            Text("同步内容：本地歌单与其歌曲、当前播放的歌曲与进度。桌面端读取同一个 beans-sync.json 即可接续播放。\n\n支持夸克网盘、坚果云、Nextcloud、Alist 等任何标准 WebDAV 服务。密码保存在系统钥匙串，不会上传到除你填写的服务器之外的地方。")
                .font(.system(size: 12.5))
                .foregroundStyle(Color.beansComment)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { BeansGlass(shape: RoundedRectangle(cornerRadius: 18, style: .continuous)) }
    }

    // MARK: 服务器

    private var serverCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("WebDAV 服务器")
                .font(.system(size: 14, weight: .semibold))

            field("服务器地址", text: $sync.baseURL, placeholder: "https://webdav.example.com", keyboard: .URL)
            field("用户名", text: $sync.username, placeholder: "账号或邮箱", keyboard: .default)

            VStack(alignment: .leading, spacing: 6) {
                Text("密码 / 应用授权码")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.beansComment)
                SecureField("••••••••", text: $password)
                    .textContentType(.password)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .font(.system(size: 13))
                    .padding(11)
                    .background {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.primary.opacity(0.06))
                    }
            }

            field("远程目录", text: $sync.directory, placeholder: "/BeansMusic", keyboard: .default)

            Toggle("自动同步", isOn: $sync.autoSync)
                .tint(Color.beansAmber)
                .font(.system(size: 13.5))

            Text("开启后：启动、回到前台、歌单变化 6 秒后、播放中每 90 秒自动同步一次。")
                .font(.system(size: 11.5))
                .foregroundStyle(Color.beansComment)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background { BeansGlass(shape: RoundedRectangle(cornerRadius: 18, style: .continuous)) }
    }

    private func field(
        _ title: String,
        text: Binding<String>,
        placeholder: String,
        keyboard: UIKeyboardType
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(Color.beansComment)
            TextField(placeholder, text: text)
                .keyboardType(keyboard)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(size: 13))
                .padding(11)
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.primary.opacity(0.06))
                }
        }
    }

    // MARK: 操作

    private var actionCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Button {
                    testConnection()
                } label: {
                    HStack(spacing: 6) {
                        if testing { ProgressView().tint(Color.beansAmber) }
                        Text(testing ? "测试中…" : "测试连接")
                    }
                    .font(.system(size: 13.5, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.primary.opacity(0.06))
                    }
                }
                .buttonStyle(.plain)
                .disabled(testing || sync.isSyncing)

                Button {
                    flushPassword()
                    Task { await sync.syncNow() }
                } label: {
                    HStack(spacing: 6) {
                        if sync.isSyncing { ProgressView().tint(.white) }
                        Text(sync.isSyncing ? "同步中…" : "立即同步")
                    }
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(Color.beansAmber, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(sync.isSyncing || !sync.isConfigured)
            }

            if let testResult {
                Text(testResult)
                    .font(.system(size: 12))
                    .foregroundStyle(testResult.hasPrefix("连接成功") ? Color.beansSage : Color.red.opacity(0.8))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(14)
        .background { BeansGlass(shape: RoundedRectangle(cornerRadius: 18, style: .continuous)) }
    }

    // MARK: 状态

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("同步状态")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Text(sync.summary)
                    .font(.system(size: 11.5))
                    .foregroundStyle(Color.beansComment)
            }
            if !sync.statusText.isEmpty {
                Text(sync.statusText)
                    .font(.system(size: 12))
                    .foregroundStyle(sync.lastError == nil ? Color.beansSage : Color.red.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text("远端文件：\(sync.directory)/beans-sync.json")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Color.beansComment.opacity(0.8))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { BeansGlass(shape: RoundedRectangle(cornerRadius: 18, style: .continuous)) }
    }

    // MARK: 远端播放

    private func remotePlaybackCard(_ playback: SyncPlayback) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("其他设备的播放")
                .font(.system(size: 14, weight: .semibold))

            if let song = playback.song {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(song.name)
                            .font(.system(size: 13.5, weight: .medium))
                            .lineLimit(1)
                        Text("\(song.artists) · \(timeText(playback.position)) / \(timeText(playback.duration))")
                            .font(.system(size: 11.5))
                            .foregroundStyle(Color.beansComment)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 8)
                    Button {
                        sync.resumeRemotePlayback()
                        dismiss()
                    } label: {
                        Text("继续播放")
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(Color.beansAmber)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Color.beansAmber.opacity(0.12), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { BeansGlass(shape: RoundedRectangle(cornerRadius: 18, style: .continuous)) }
    }

    private func timeText(_ seconds: Double) -> String {
        let total = max(0, Int(seconds))
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    // MARK: 帮助

    private var helpCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("怎么填")
                .font(.system(size: 13.5, weight: .semibold))
            Text("• 夸克网盘：先在 App 里开启 WebDAV，再填它给出的地址与账号\n• 坚果云：https://dav.jianguoyun.com/dav/（密码填应用授权码）\n• Nextcloud：https://你的域名/remote.php/dav/files/用户名\n• Alist：http://你的地址:5244/dav\n\n远程目录默认 /BeansMusic，不存在会自动创建。")
                .font(.system(size: 12))
                .foregroundStyle(Color.beansComment)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { BeansGlass(shape: RoundedRectangle(cornerRadius: 18, style: .continuous)) }
    }

    // MARK: 动作

    private func flushPassword() {
        sync.password = password
    }

    private func testConnection() {
        flushPassword()
        testing = true
        testResult = nil
        Task {
            let result = await sync.testConnection()
            await MainActor.run {
                testing = false
                testResult = result
            }
        }
    }
}
