import SwiftUI

/// 导入歌单：粘贴平台歌单链接或 id，把歌单和歌曲一起存到本地。
/// 对应原版 LX Music 的「打开歌单 / 收藏歌单」，导入后可以随时更新。
struct ImportPlaylistSheet: View {
    @EnvironmentObject private var theme: ThemeStore
    @Environment(\.dismiss) private var dismiss

    /// 默认平台（当前音乐库选中的平台）
    let defaultSource: SongSource
    /// 直接导入已知歌单（从歌单广场 / 排行榜 / 搜索结果进入）
    var presetPlaylist: Playlist? = nil

    @State private var text = ""
    @State private var source: SongSource
    @State private var loading = false
    @State private var message: String?

    private static let importableSources: [SongSource] = [.netease, .qq, .kugou, .bodian, .kuwo]

    init(defaultSource: SongSource, presetPlaylist: Playlist? = nil) {
        self.defaultSource = defaultSource
        self.presetPlaylist = presetPlaylist
        let resolved = presetPlaylist?.source ?? defaultSource
        _source = State(initialValue: resolved == .migu ? .netease : resolved)
    }

    var body: some View {
        let _ = theme.accent
        BeansNavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    intro
                    if let presetPlaylist {
                        presetCard(presetPlaylist)
                    } else {
                        sourcePicker
                        linkField
                    }
                    if let message {
                        Text(message)
                            .font(BeansFont.appFont(13))
                            .foregroundStyle(Color.beansComment)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    actionButton
                }
                .padding(18)
            }
            .navigationTitle("导入歌单")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("导入到「我的歌单 · 导入歌单」")
                .font(BeansFont.appFont(15, .semibold))
                .foregroundStyle(Color.beansLabel)
            Text("支持网易云、QQ音乐、酷狗（含概念版分享短链，如 t1.kugou.com/…）、波点的歌单链接或歌单 id。导入后歌曲会保存在本机，可随时手动更新，不依赖账号同步。")
                .font(BeansFont.appFont(12.5))
                .foregroundStyle(Color.beansComment)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var sourcePicker: some View {
        HStack(spacing: 8) {
            ForEach(Self.importableSources, id: \.self) { item in
                Button {
                    BeansHaptics.tap()
                    source = item
                } label: {
                    Text(LocalizedStringKey(providerTitle(item)))
                        .font(BeansFont.appFont(13, .semibold))
                        .foregroundStyle(source == item ? Color.white : Color.beansComment)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background {
                            Capsule().fill(source == item ? Color.beansAmber : Color.beansComment.opacity(0.12))
                        }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var linkField: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("歌单链接或 id", text: $text)
                .font(BeansFont.appFont(14))
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .padding(12)
                .background { BeansSurface(shape: RoundedRectangle(cornerRadius: 14, style: .continuous)) }
            Text(hint)
                .font(BeansFont.appFont(11.5))
                .foregroundStyle(Color.beansComment)
        }
    }

    private func presetCard(_ playlist: Playlist) -> some View {
        HStack(spacing: 12) {
            CoverImage(url: playlist.coverURL, size: 60, cornerRadius: 12)
            VStack(alignment: .leading, spacing: 4) {
                Text(playlist.name)
                    .font(BeansFont.appFont(15, .semibold))
                    .foregroundStyle(Color.beansLabel)
                    .lineLimit(2)
                Text(beansSongCountText(playlist.trackCount))
                    .font(BeansFont.appFont(12))
                    .foregroundStyle(Color.beansComment)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background { BeansGlass(shape: RoundedRectangle(cornerRadius: 18, style: .continuous)) }
    }

    private var actionButton: some View {
        Button {
            Task { await runImport() }
        } label: {
            HStack(spacing: 8) {
                if loading {
                    ProgressView().tint(.white)
                }
                Text(loading ? "正在导入…" : "导入")
                    .font(BeansFont.appFont(15, .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(Color.beansAmber, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(loading || (presetPlaylist == nil && text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
        .opacity(loading || (presetPlaylist == nil && text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) ? 0.5 : 1)
    }

    private var hint: String {
        switch source {
        case .netease: return "例如 https://music.163.com/#/playlist?id=123456789"
        case .qq: return "例如 https://y.qq.com/n/ryqq/playlist/7890123456"
        case .kugou: return "例如 https://www.kugou.com/songlist/gcid_xxxx/ 或 https://www.kugou.com/yy/special/single/123456.html"
        case .bodian: return "填写波点歌单 id（纯数字）"
        case .kuwo: return "粘贴酷我歌单链接，例如 https://www.kuwo.cn/playlist_detail/2947959139"
        case .migu: return "咪咕暂不支持导入歌单"
        }
    }

    private func providerTitle(_ source: SongSource) -> String {
        switch source {
        case .netease: return "网易云"
        case .qq: return "QQ音乐"
        case .kugou: return "酷狗"
        case .bodian: return "波点"
        case .kuwo: return "酷我"
        case .migu: return "咪咕"
        }
    }

    private func runImport() async {
        guard !loading else { return }
        loading = true
        message = nil
        do {
            let payload: PlaylistImportPayload
            if let presetPlaylist {
                payload = try await PlaylistImportService.fetch(playlist: presetPlaylist)
            } else {
                payload = try await PlaylistImportService.fetch(text: text, preferred: source)
            }
            ImportedPlaylistStore.shared.upsert(
                name: payload.playlist.name,
                source: payload.playlist.source,
                sourceID: payload.sourceID,
                coverURL: payload.playlist.coverURL,
                trackCount: payload.songs.count,
                songs: payload.songs
            )
            BeansHaptics.success()
            ToastCenter.shared.show("已导入「\(payload.playlist.name)」\(payload.songs.count) 首")
            dismiss()
        } catch {
            message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        loading = false
    }
}
