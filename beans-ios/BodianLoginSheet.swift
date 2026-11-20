import SwiftUI

/// 波点音乐扫码登录。波点没有网页登录入口，只能用 App 扫码换 uid / token。
struct BodianLoginSheet: View {
    @EnvironmentObject private var theme: ThemeStore
    @Environment(\.dismiss) private var dismiss

    @ObservedObject private var bodianAuth = BodianMusicAuth.shared
    @State private var qr: BodianMusicAPI.QRLogin?
    @State private var status: QRStatus = .loading
    @State private var timer: Timer?

    enum QRStatus: Equatable {
        case loading
        case waiting
        case scanned
        case success
        case expired
        case error(String)
    }

    var body: some View {
        let _ = theme.accent
        ZStack {
            GlassBackdrop(customColor: theme.backgroundSyncAll ? theme.customBackground : nil)
            VStack(spacing: 18) {
                Capsule()
                    .fill(Color.beansComment.opacity(0.3))
                    .frame(width: 38, height: 4)
                    .padding(.top, 12)

                HStack {
                    Text("登录波点音乐")
                        .font(BeansFont.appFont(20, .bold))
                        .foregroundStyle(Color.beansLabel)
                    Spacer()
                    Button {
                        BeansHaptics.tap()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(Color.beansComment)
                    }
                    .buttonStyle(GlassPressButtonStyle(scale: 0.9))
                }
                .padding(.horizontal, 24)

                qrArea
                    .frame(width: 250, height: 250)
                    .padding(18)
                    .background { BeansSurface(shape: RoundedRectangle(cornerRadius: 30, style: .continuous)) }
                    .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                    .shadow(color: .black.opacity(0.2), radius: 20, y: 10)

                statusView

                Text("请使用波点音乐 App 扫码。未登录时波点只提供 30 秒试听，登录后才能完整播放并同步云端歌单。")
                    .font(BeansFont.appFont(11))
                    .foregroundStyle(Color.beansComment)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)

                Spacer(minLength: 0)
            }
        }
        .onAppear { startLogin() }
        .onDisappear { timer?.invalidate() }
    }

    @ViewBuilder
    private var qrArea: some View {
        ZStack {
            if let qr {
                QRCodeView(text: qr.url)
            } else {
                ProgressView().tint(Color.beansAmber)
            }
            if status == .expired || isError {
                VStack(spacing: 10) {
                    Image(systemName: "arrow.clockwise.circle.fill")
                        .font(.system(size: 34))
                    Text(isError ? errorText : "二维码已过期")
                        .font(BeansFont.appFont(13))
                    GlassButton(title: "刷新", systemName: "arrow.clockwise", prominent: true) {
                        startLogin()
                    }
                }
                .foregroundStyle(Color.beansLabel)
                .frame(width: 210, height: 210)
                .background(.black.opacity(0.55))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }

    private var statusView: some View {
        Group {
            switch status {
            case .loading:
                Text("正在生成波点二维码...")
            case .waiting:
                Label("请使用波点音乐 App 扫码", systemImage: "qrcode.viewfinder")
            case .scanned:
                Label("已扫码，请在手机上确认登录", systemImage: "checkmark.circle")
            case .success:
                Label("登录成功，正在同步歌单...", systemImage: "checkmark.seal.fill")
            case .expired:
                Text("二维码已过期")
            case .error(let message):
                Text(message)
            }
        }
        .font(BeansFont.appFont(13))
        .foregroundStyle(isError ? Color.red.opacity(0.85) : Color.beansComment)
        .multilineTextAlignment(.center)
        .frame(height: 44)
    }

    private var isError: Bool {
        if case .error = status { return true }
        return false
    }

    private var errorText: String {
        if case .error(let message) = status { return message }
        return ""
    }

    private func startLogin() {
        timer?.invalidate()
        timer = nil
        status = .loading
        qr = nil
        Task {
            do {
                let newQR = try await BodianMusicAPI.shared.qrLogin()
                await MainActor.run {
                    qr = newQR
                    status = .waiting
                    startPolling(key: newQR.key)
                }
            } catch {
                await MainActor.run { status = .error(error.localizedDescription) }
            }
        }
    }

    private func startPolling(key: String) {
        timer = Timer.scheduledTimer(withTimeInterval: 1.6, repeats: true) { _ in
            Task {
                do {
                    let state = try await BodianMusicAPI.shared.qrStatus(key: key)
                    await MainActor.run { handle(state, key: key) }
                } catch {
                    // 网络抖动时等下一次轮询，不打断用户
                }
            }
        }
    }

    private func handle(_ state: BodianMusicAPI.LoginState, key: String) {
        switch state {
        case .waiting:
            if status == .scanned { status = .waiting }
        case .scanned:
            status = .scanned
        case .expired:
            timer?.invalidate()
            timer = nil
            status = .expired
        case .confirmed:
            // qrStatus 在 status=3 时已经完成 uid / token 换取
            timer?.invalidate()
            timer = nil
            status = .success
            let name = bodianAuth.nickname.isEmpty ? bodianAuth.uid : bodianAuth.nickname
            ToastCenter.shared.show("波点音乐已登录：\(name)")
            dismiss()
        }
    }
}
