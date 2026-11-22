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
            id: "1.19.1",
            version: "1.19.1",
            title: "真实平台图标 + 酷我登录可用 + 播放页收藏",
            features: [
                "平台下拉菜单、搜索与音乐库的平台标识全部换成真实品牌图标，新增酷我、咪咕官方图标",
                "酷我登录改为桌面版网页并自动打开登录框：支持手机号快捷登录、账号密码、微信 / QQ，不再停在只有「下载 APP」的移动版页面",
                "粘贴 Cookie 增加真实验证：会用这份 Cookie 打开酷我网页确认登录态，验证通过才保存",
                "播放封面页底部新增收藏按钮，实心 / 空心实时反映收藏状态，与歌词页头部、播放设置共用同一份收藏",
                "歌词全屏舞台顶部新增播放设置入口，控制层呼出后 3.2 秒自动淡出，不挡歌词；从左往右滑仍回到封面页"
            ],
            fixes: [
                "进入歌词全屏舞台时先露出 3 秒控制层，避免找不到返回、设置等入口"
            ]
        ),
        VersionLog(
            id: "1.19.0",
            version: "1.19.0",
            title: "舞台全屏沉浸 + 68 种舞台 + 酷我登录",
            features: [
                "舞台开启后进入真·全屏：顶部信息条、底部进度条与播放按钮、上下两块毛玻璃全部收掉，歌词画面铺满整块屏幕；轻点屏幕呼出极简控制层，再点收起，左滑仍可回到封面",
                "歌词舞台补齐到 68 种（liziair 全量）：新增 Cobalt Grid、超扁平糖果、棱镜阈限、未来已来、烟雨江南、体素街机厅、末日高架桥、星轨跟拍等 38 种，选择器支持搜索",
                "新增酷我音乐：支持网页登录、读取「我的歌单」、搜索、歌单导入、播放与歌词；未登录也可直接粘贴酷我歌单链接导入",
                "音乐库新增「置顶歌单」区，最多置顶 6 个；歌单可按自定义顺序拖拽排列"
            ],
            fixes: [
                "曲库云同步不再卡：点云朵按钮立即弹出面板，各平台歌单在后台并行补齐；展开上千个歌单时改为懒加载与分页渲染，不再一次性卡住主线程",
                "云同步面板后台补齐到新歌单时会自动勾选，用户手动取消过的不会被重新选上"
            ]
        ),
        VersionLog(
            id: "1.18.0",
            version: "1.18.0",
            title: "歌词舞台真正可用 + 导入歌单直显",
            features: [
                "「手动导入音源」更名为「手动导入歌单」，入口文案与功能一致",
                "导入歌单区块直接列出所有已导入歌单（不再受当前平台筛选影响），点进去读本机副本，离线也能看"
            ],
            fixes: [
                "彻底修复歌词舞台不生效：30 个舞台 HTML 之前根本没打进安装包（构建配置的 resources 字段无效、源码又排除了该目录），现在随包拷贝；设置页可见「舞台资源已就绪 30/30」",
                "舞台加载失败时不再替用户关掉开关——之前一失败就把 enabled 写回 false，表现就是「打开后又自己关上」",
                "舞台资源缺失时不再挂空 WebView，直接回到原生歌词，避免歌词被顶成空白"
            ]
        ),
        VersionLog(
            id: "1.17.0",
            version: "1.17.0",
            title: "酷狗概念版歌单导入 + 歌单管理升级 + 歌词特效真正生效",
            features: [
                "导入歌单支持酷狗概念版分享短链（t1.kugou.com/…）：自动跟随跳转解析歌单，歌单名、封面、曲目数一并带回",
                "全部歌单页管理升级：支持搜索名称、平台筛选、按名称/歌曲数排序，批量隐藏与单个删除",
                "新增「已隐藏歌单」页：列出被隐藏的歌单，可逐个恢复、滑动移除或一键全部恢复",
                "歌词展示方式（逐字高亮 / 大字聚焦）同步到 Apple Music 播放方案，两套播放器观感一致",
                "逐字高亮改为富文本拼接，长句自动换行，不再横向溢出屏幕"
            ],
            fixes: [
                "修复歌词舞台「集成了却看不到」：ready 兜底只改了内部状态、没有回调 SwiftUI，导致舞台被永久挡在门外；现在兜底会正常放行，并新增 2.4 秒超时强制显示",
                "舞台透明度由 0 改为 0.001，避免 WebKit 被判定为不可见后暂停出帧、切换时首帧发黑",
                "酷狗云歌单条目补「歌手 - 歌名」拆分，概念版歌单不再把整串当歌名、歌手留空"
            ]
        ),
        VersionLog(
            id: "1.16.0",
            version: "1.16.0",
            title: "音乐库管理增强 + 原生歌词新样式 + 舞台黑屏兜底",
            features: [
                "音乐库左上角改为大图标 + 小名称，去掉与副标题重复的大字，更简洁美观",
                "歌单分类新增「本地」（手工导入 + 本机自建）与「收藏」（主页收藏的歌单转入）",
                "全部歌单页右上角新增「管理」：可批量隐藏歌单、一键恢复全部隐藏歌单",
                "云端/第三方歌单可「保存到本地」：复制全部歌曲到已有或新建本地歌单，随意增删",
                "全部歌曲页新增批量管理：多选加入播放列表 / 存入本地歌单，并可清除本地歌单重复歌曲",
                "原生歌词新增「逐字高亮」「大字聚焦」两种展示方式，可在设置-歌词显示里切换"
            ],
            fixes: [
                "歌词舞台黑屏兜底：WebView 首帧未成功绘制时自动保留原生歌词，不再出现纯黑页；补强尺寸监听与多次 resize",
                "全部歌曲分页、隐藏歌单显示等交互细节优化"
            ]
        ),
        VersionLog(
            id: "1.15.0",
            version: "1.15.0",
            title: "手势修正 + 沉浸式重做 + 同步可选",
            features: [
                "播放页与歌词页手势按直觉统一：从左往右返回、从右往左进歌词，歌词页从左往右返回播放页",
                "曲库同步支持按平台、按具体歌单勾选，只同步你需要的部分；封面默认只缓存每个歌单的封面图",
                "音乐库左上角默认「全部歌单」，图标与主页一致，可切换到单一平台或「手动导入音源」类别",
                "「全部歌单 / 全部歌曲」改为全屏新页面打开，左上角返回按钮 + 从左往右滑动返回",
                "主页歌单板块更名「热门歌单」，首屏新增「今日推荐」标题",
                "播放控制按钮加入液态玻璃高光与描边，玻璃质感更明显"
            ],
            fixes: [
                "修复沉浸式封面与歌词横向溢出屏幕的问题：封面宽度严格贴屏、四周羽化融入背景",
                "修复歌词舞台（liziair）全黑不出词的问题：补全 WebView 尺寸并在首帧后触发重建",
                "修复已登录平台在同步面板里显示「未登录 / 无歌单」的问题：打开面板前先拉取全部平台歌单"
            ]
        ),
        VersionLog(
            id: "1.14.0",
            version: "1.14.0",
            title: "歌词舞台 + 同步提速",
            features: [
                "新增「歌词舞台」：移植 liziair 的 30 种动态歌词演出（粒子 / 星际 / 静雪 / 余烬 / 代码雨 / 深海 / 雷暴…），歌词页实时跟随播放进度，可在播放设置或歌词页右上角随时切换",
                "歌曲缓存改为按歌单分文件保存：同步只写当前歌单，不再每次把整个曲库重新编码一遍",
                "云同步改为 3 个歌单并发拉取，进度与耗时实时可见，结果面板新增「平均 x 秒/歌单」",
                "封面缩略图改为可选：默认只同步歌曲信息（最快），需要时可在同步面板打开，并在后台慢慢补",
                "迷你播放栏新增横向进度：横向填充（右侧带流动波纹）与底部细线条两种，和原有纵向水位一起在播放设置里切换",
                "音乐库歌单区默认展示全部平台的歌单，封面角标标注来源平台，副标题显示歌曲数量；「全部歌单」支持按平台筛选",
                "沉浸式播放重做：封面放大到全屏宽、上下溢出，四边羽化并叠一层模糊光晕，标题压在封面下缘的渐隐区里"
            ],
            fixes: [
                "云同步「很久才同步一首歌」：旧实现每同步一个歌单都要把全部已缓存歌曲重新 JSON 编码写进 UserDefaults，曲库越大越慢；现已改为单歌单单文件",
                "同步时封面下载会阻塞歌曲信息落盘，导致进度长时间停在同一首；现在封面完全不参与关键路径",
                "播放页手势统一为：播放页左滑返回、右滑进歌词；歌词页左滑回播放页（四种播放方案一致，并加入快速轻扫识别）"
            ]
        ),
        VersionLog(
            id: "1.13.0",
            version: "1.13.0",
            title: "沉浸式播放 + 曲库云同步",
            features: [
                "新增「沉浸式」播放方案：封面羽化边缘溶进整屏背景，只保留最必要的控制层",
                "播放方案合并为一个入口：经典 / Apple Music / 黑胶 / 沉浸，按钮外观随方案自动切换，不再有两套「按钮样式」互相覆盖",
                "进度条样式（流光 / 辉光 / 极光 / 波浪）与颜色现在对四种方案都生效，Apple Music 与黑胶不再固定白条",
                "背景光晕、浮尘、DJ 脉冲在 Apple Music 与沉浸式下同样生效",
                "音乐库新增「曲库云同步」：逐个歌单拉取歌曲并写入本机缓存，同时下载封面缩略图",
                "同步有结果面板（歌单数 / 歌曲数 / 封面数 / 用时 / 失败列表），下次打开还能看到上次同步时间",
                "封面统一走磁盘缩略图缓存：列表只下载一次，之后秒开且离线可见，进歌曲详情或手动同步才更新",
                "迷你播放器用卡片内水位填充显示进度，水面带波浪，按四种 UI 风格 × 深浅色分别配色",
                "应用图标换成猫头照片，边缘羽化融入暖色背景"
            ],
            fixes: [
                "播放器设置里「左右滑动切歌」开关与新手势冲突，已删除；上滑下一曲 / 下滑上一曲 / 封面左滑返回 / 右滑歌词 / 歌词页左滑返回统一生效",
                "「全部歌曲」改为分页加载（首屏 60 首，滑到底再加），几千首也不再一次性渲染卡顿",
                "音乐库歌单墙文字被下一行封面遮挡：行高按封面 + 标题 + 副标题实际高度计算",
                "「我的」页面移除更新地址、检查更新、交流群与赞助入口"
            ]
        ),
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
