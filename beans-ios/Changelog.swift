import SwiftUI

// MARK: - 版本更新日志（设置页与首次更新弹窗使用）

struct VersionLog: Identifiable {
    let id: String
    let version: String
    let title: String
    let notices: [String]
    let features: [String]
    let fixes: [String]
    let imageURL: URL?
    let textColorHex: String?

    init(id: String, version: String, title: String, notices: [String] = [], features: [String], fixes: [String], imageURL: URL? = nil, textColorHex: String? = nil) {
        self.id = id
        self.version = version
        self.title = title
        self.notices = notices
        self.features = features
        self.fixes = fixes
        self.imageURL = imageURL
        self.textColorHex = textColorHex
    }
}

enum ChangelogStore {
    static let lastSeenKey = "beans.lastSeenVersion"

    static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    static var lastSeenVersion: String {
        UserDefaults.standard.string(forKey: lastSeenKey) ?? ""
    }

    static func markSeen() {
        UserDefaults.standard.set(currentVersion, forKey: lastSeenKey)
        UserDefaults.standard.synchronize()
    }

    static var shouldShowWhatsNew: Bool {
        lastSeenVersion != currentVersion
    }

    static var latest: VersionLog? { logs.first }

    static let logs: [VersionLog] = [
        VersionLog(
            id: "1.12.0",
            version: "1.12.0",
            title: "Z Music：搜索全部平台 + 音乐库改版",
            features: [
                "搜索默认「全部平台」，一次搜完所有已启用平台并按歌名+歌手去重",
                "音乐库改为「歌单墙 + 全部歌曲」：3 列 × 2 行可一直右滑，全部按钮进 3 列网格",
                "歌单长按可更新 / 重命名 / 隐藏 / 删除；隐藏只影响音乐库展示",
                "全部歌曲汇总所有歌单，歌手名 + 歌名相同只留一首，可按语言、歌手筛选",
                "播放页手势：封面左滑返回、右滑歌词、上滑下一曲、下滑上一曲，切歌带滑出滑入动画",
                "波点音乐补上热搜词，首页也能取到推荐歌单",
                "应用名改为 Z Music，图标换成 LX Music 图标"
            ],
            fixes: [
                "主页连点「全部」重复入栈导致闪退：同一入口 0.8s 内只入栈一次",
                "波点首页空白：推荐歌单接口是分组结构（data.lists[].playLists[]），之前当成歌单数组解析全被丢弃",
                "音乐库滑到底部整页上下晃：内容不足一屏时不再回弹"
            ]
        ),
        VersionLog(
            id: "1.11.1",
            version: "1.11.1",
            title: "歌单导入与手势打磨",
            features: [
                "导入歌单点进去直接读本机副本，离线也能看，右上角新增「更新」按钮随时拉最新",
                "Apple Music 封面样式补充左滑下一首，三种封面风格手势一致",
                "波点音乐登录后识别会员状态，我的页显示 VIP / SVIP 角标"
            ],
            fixes: [
                "酷狗云歌单分页：接口偷偷截断单页条数时，后续页码会整段跳歌，现在按真实返回条数翻页",
                "导入歌单链接识别补充酷狗 m 站 plist/list、波点分享页 id= 参数"
            ]
        ),
        VersionLog(
            id: "1.11.0",
            version: "1.11.0",
            title: "导入歌单与播放手势",
            features: [
                "每个平台的歌单分成两类：账号同步歌单，以及用链接/id 导入的本地歌单（可随时更新、重命名、删除）",
                "歌单广场长按歌单可直接「导入到我的歌单」，导入后歌曲保存在本机，不依赖账号",
                "播放页手势统一：专辑封面右滑看歌词、上划下一曲、下滑上一曲，左滑仍为下一首",
                "歌词页左滑返回专辑封面",
                "双击专辑封面收藏 / 取消收藏（三种封面风格都支持）",
                "波点音乐接入：搜索、歌单、登录同步、播放与歌词"
            ],
            fixes: [
                "修复酷狗云歌单外面显示曲目数、进入后没有歌曲的问题（gcid 反解 specialid 后走公开接口取全量歌曲）",
                "上划打开评论的手势与切歌手势冲突，评论入口改到播放页右上角菜单",
                "首页默认展示「全部」平台聚合歌单，左上角可下拉切换平台"
            ]
        ),
        VersionLog(
            id: "1.5.8",
            version: "1.5.8",
            title: "歌单同步、主页与播放器全面优化",
            features: [
                "新增网易云音乐、QQ音乐、酷狗音乐歌单一键同步到本地",
                "本地歌单支持编辑和搜索，批量选择歌曲后可添加到其他本地歌单",
                "新增 QQ 音乐热门歌单展示",
                "主页问候语支持自定义文字、颜色、大小、发光、专属字体、底部横线和上下渐变，并可逐行选择渐变颜色",
                "播放器支持左右滑动切换歌曲，新增顶部三平台排序、隐藏主页刷新/用户名/排序按钮",
                "播放器按钮图标样式新增，播放器设置界面重新整理分组和控件排版",
                "主页、音乐库、我的、设置页增加 iPad 最大宽度适配",
                "播放列表、最近播放和日志界面背景同步主页壁纸"
            ],
            fixes: [
                "修复 QQ 音乐喜欢列表不显示的问题",
                "修复最近播放、日志、本地歌单和播放列表不同步主页壁纸的问题",
                "修复设置页掉帧问题；如果本次仍然掉帧，建议更换设备",
                "修复 iOS 15 编译兼容问题"
            ]
        ),
        VersionLog(
            id: "1.5.6",
            version: "1.5.6",
            title: "播放器体验优化",
            features: [
                "封面页歌名、歌手和预览歌词支持渐变、高光及高光强度调节",
                "播放页背景浮尘新增开关，默认关闭；动态浮尘支持密度和大小调节",
                "全局上传壁纸自动同步到播放器封面页背景",
                "播放页支持从顶部下划关闭，并加入缩放、淡出动画"
            ],
            fixes: [
                "修复酷狗排行榜歌曲封面缺失或未归一化的问题",
                "提高内置音源搜索上限",
                "播放器设置打开后不再默认展开播放和歌词显示分组"
            ]
        ),
        VersionLog(
            id: "1.5.5",
            version: "1.5.5",
            title: "播放流畅度与发热优化",
            notices: [
                "从 1.5.4 版本开始，播放器设置已从右上角删除，改为点击中间歌曲正在播放的标题打开。"
            ],
            features: [
                "优化播放中全局刷新策略，移除高刷保持器的常驻空转刷新，降低设置页、我的页面和播放器页面的发热与掉帧",
                "本地壁纸、歌词背景、设置页缩略图改为复用解码缓存，减少滚动和切换设置时的重复图片解码",
                "锁屏/系统正在播放封面增加缓存，避免播放状态变化时反复下载和刷新同一张封面",
                "聆澜内置音源支持多密钥池，当前密钥未命中时自动切换下一个，并记住最近可用密钥",
                "播放器设置新增封面页歌名、歌手、预览歌词与未播放歌词颜色调节"
            ],
            fixes: [
                "修复播放中进度更新过于频繁导致非播放器页面也跟随重绘的问题",
                "修复重新上传歌词背景或恢复壁纸后，部分位置可能继续显示旧图片缓存的问题",
                "修复酷狗排行榜详情歌曲封面链接未归一化，并在官网榜单缺封面时自动用移动端榜单数据补齐封面",
                "优化巨魔安装场景下播放中切换页面的刷新与解码负担"
            ]
        ),
    ]
}

// MARK: - 更新说明弹窗

struct WhatsNewSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        BeansNavigationStack {
            ZStack {
                GlassBackdrop(customColor: ThemeStore.shared.backgroundSyncAll ? ThemeStore.shared.customBackground : nil)
                ScrollView {
                    if let log = ChangelogStore.latest {
                        VersionLogCard(log: log)
                            .padding(16)
                    }
                }
                .beansScrollIndicatorsHidden()
            }
            .navigationTitle("更新说明")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("开始使用") {
                        ChangelogStore.markSeen()
                        dismiss()
                    }
                    .font(BeansFont.appFont(14, .semibold))
                    .foregroundStyle(Color.beansAmber)
                }
            }
        }
        .modifier(BeansSheetModifier(detents: [.medium, .large]))
        .onDisappear {
            ChangelogStore.markSeen()
        }
    }
}

struct ChangelogListView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        BeansNavigationStack {
            ZStack {
                GlassBackdrop(customColor: ThemeStore.shared.backgroundSyncAll ? ThemeStore.shared.customBackground : nil)
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(ChangelogStore.logs) { log in
                            VersionLogCard(log: log)
                        }
                    }
                    .padding(16)
                }
                .beansScrollIndicatorsHidden()
            }
            .navigationTitle("更新日志")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .modifier(BeansSheetModifier(detents: [.medium, .large]))
    }
}

private struct VersionLogCard: View {
    let log: VersionLog

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("v\(log.version)")
                    .font(BeansFont.appFont(16, .bold))
                    .foregroundStyle(Color.beansAmber)
                Text(log.title)
                    .font(BeansFont.appFont(14, .semibold))
                    .foregroundStyle(textColor)
            }
            if let imageURL = log.imageURL {
                AsyncImage(url: imageURL) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFit()
                    } else if phase.error != nil {
                        EmptyView()
                    } else {
                        ProgressView().frame(maxWidth: .infinity, minHeight: 80)
                    }
                }
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            if !log.notices.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(log.notices, id: \.self) { notice in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.top, 1)
                            Text(notice)
                                .font(BeansFont.appFont(13, .semibold))
                                .foregroundStyle(.white)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    LinearGradient(
                        colors: [Color.orange, Color.red.opacity(0.88)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
            }
            if !log.features.isEmpty {
                logSection(title: "新增功能", icon: "plus.circle.fill", items: log.features)
            }
            if !log.fixes.isEmpty {
                Divider().overlay(Color.beansComment.opacity(0.15))
                logSection(title: "问题修复", icon: "checkmark.circle.fill", items: log.fixes)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            BeansGlass(shape: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .beansCardShadow(radius: 9, y: 3)
    }

    private func logSection(title: String, icon: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(LocalizedStringKey(title))
                .font(BeansFont.appFont(14, .bold))
                .foregroundStyle(Color.beansAmber)
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.beansAmber)
                        .padding(.top, 2)
                    Text(LocalizedStringKey(item))
                        .font(BeansFont.appFont(13))
                        .foregroundStyle(textColor)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var textColor: Color {
        if let raw = log.textColorHex, let color = Color(hex: raw) { return color }
        return Color.beansLabel
    }
}
