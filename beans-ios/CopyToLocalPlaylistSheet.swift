import SwiftUI

/// 把云端/第三方歌单的歌曲复制（导入）到本地歌单。
/// 本地歌单可自由增删歌曲，用来删除不想要的歌曲或增加自己的歌曲，
/// 完全不影响平台上的原歌单。
struct CopyToLocalPlaylistSheet: View {
    @EnvironmentObject private var theme: ThemeStore
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var localLibrary = LocalLibraryStore.shared

    let songs: [Song]
    let suggestedName: String

    @State private var newName = ""
    @State private var showCreate = false

    var body: some View {
        let _ = theme.accent
        BeansNavigationStack {
            List {
                Section {
                    Text("将 \(songs.count) 首歌曲复制到本机。本地歌单可自由增删歌曲，不会影响平台上的原歌单。")
                        .font(BeansFont.appFont(12))
                        .foregroundStyle(Color.beansComment)
                }

                if !localLibrary.playlists.isEmpty {
                    Section("添加到现有本地歌单") {
                        ForEach(localLibrary.playlists) { pl in
                            Button {
                                let added = localLibrary.addSongs(songs, to: pl.id)
                                ToastCenter.shared.show(added > 0 ? "已添加 \(added) 首到「\(pl.name)」" : "这些歌曲已在「\(pl.name)」中")
                                BeansHaptics.tap()
                                dismiss()
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "music.note.list")
                                        .font(.system(size: 16))
                                        .foregroundStyle(Color.beansAmber)
                                        .frame(width: 36, height: 36)
                                        .background { BeansSurface(shape: RoundedRectangle(cornerRadius: 9, style: .continuous)) }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(pl.name)
                                            .font(BeansFont.appFont(15))
                                            .foregroundStyle(Color.beansLabel)
                                            .lineLimit(1)
                                        Text(beansSongCountText(pl.songs.count))
                                            .font(BeansFont.appFont(11))
                                            .foregroundStyle(Color.beansComment)
                                    }
                                    Spacer()
                                }
                            }
                        }
                    }
                }

                if showCreate {
                    Section("新建本地歌单") {
                        TextField("歌单名称", text: $newName)
                            .submitLabel(.done)
                        Button {
                            let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !name.isEmpty else { return }
                            let pl = localLibrary.createPlaylist(name: name)
                            let added = localLibrary.addSongs(songs, to: pl.id)
                            BeansHaptics.tap()
                            ToastCenter.shared.show("已创建「\(name)」并复制 \(added) 首")
                            dismiss()
                        } label: {
                            Text("创建并复制 \(songs.count) 首")
                                .font(BeansFont.appFont(15, .semibold))
                                .foregroundStyle(Color.beansAmber)
                        }
                    }
                } else {
                    Section {
                        Button {
                            newName = suggestedName
                            showCreate = true
                        } label: {
                            Label("新建本地歌单并复制", systemImage: "plus.circle")
                        }
                    }
                }
            }
            .navigationTitle("保存到本地")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("取消") { dismiss() }
                }
            }
            .onAppear { newName = suggestedName }
        }
    }
}
