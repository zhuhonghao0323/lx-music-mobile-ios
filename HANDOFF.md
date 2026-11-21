# LX Music iOS 重构项目 · 交接文档

> 生成时间：2026-11-20（最后更新：2026-11-20 17:40）
> 交接时最新提交：`1d45f268`（分支 `ios-adaptation`）
> 下文「一 ~ N」为首次交接时的内容，其中提交号、Token 等已过期，仅作历史参考；
> **接手请先读下面的「零、云端继续做」**。

---

## 零、云端继续做（手机 WorkBuddy「云端工作」）

电脑关机后，手机 App 用「云端工作」执行环境接手。云端沙箱是 **Linux**，没有 Xcode，**改完必须靠 GitHub Actions 出包**。

### 0.1 快速开始（可直接粘给云端会话）

```
克隆 https://github.com/zhuhonghao0323/lx-music-mobile-ios ，切到 ios-adaptation 分支。
这是一个 SwiftUI 的 iOS 音乐 App（beans-ios/，用 XcodeGen 生成工程，beans-project.yml 定义）。
云端没有 Xcode，不要尝试本地编译；改完 push 到 ios-adaptation，GitHub Actions
(.github/workflows/beans-ipa.yml, macos-26) 会自动构建并覆盖 release tag beans-latest。
请先读 HANDOFF.md 的「零、云端继续做」，再按下面待办继续。
```

### 0.2 云端要注意的坑

| 事项 | 说明 |
|---|---|
| 沙箱不持久 | 任务结束沙箱可能被清理，**改完立刻 commit & push**，不要只留在云端 |
| 不能本地编译 | Linux 无 xcodebuild；编译错误靠 CI 的 `ci-failure.log`（失败时工作流会把 `grep "error:"` 提交回分支） |
| 推送凭据 | 仓库是 public，clone 免认证，**push 需要 PAT**（fine-grained，仅该仓库 Contents: Read and write），用完在 GitHub 撤销 |
| 不需要代理 | 云端直连 GitHub，不要再加 `http.proxy=127.0.0.1:7897`（那是本机 Windows 才需要的） |
| 网络坑 | 云端到 GitHub 的大包传输很慢且会中途 `Connection reset`：`git clone` 建议 `-c http.version=HTTP/1.1`，`--depth 1`；若反复失败，直接下 `https://codeload.github.com/.../tar.gz/refs/heads/ios-adaptation`（不支持断点续传，必须一次下完，约 11MB），推送走 GitHub REST API（`/git/blobs` → `/git/trees` → `/git/commits` → `PATCH /git/refs/heads/ios-adaptation`） |
| 只推 ios-adaptation | 默认分支 main 是上游 LX 的，**不要推 main** |
| 任务归属 | 手机发起的云端任务只在网页版/移动端的云端列表里，PC 桌面端看不到 |

### 0.3.1 最新一轮（2026-11-21，版本 **1.17.0 (87)**）

按用户 4 条反馈继续改：

| # | 反馈 | 处理（改动文件） |
|---|---|---|
| 1 | 左上角图标旁边的「全部平台 / 网易云…」标签删掉，只留右侧名称 | `LibraryView.swift`：`header` / `appleHeader` 删除 `Text(librarySubtitle)`，副标题只用于无障碍标签 |
| 2 | 歌单管理太简单，要能隐藏、过滤、删除 | `LibraryWall.swift` 重写 `LibraryAllPlaylistsSheet`：搜索框 + 平台 chips + 排序（默认/名称/歌曲数）+ 管理态多选批量隐藏 + 单个删除（走原平台删除确认）+ 右上角「已隐藏歌单」页（逐个恢复 / 滑动移除 / 全部恢复）；`HiddenPlaylistStore` 增加 id→名称存储 |
| 3 | 导入歌单不支持酷狗概念版 | `PlaylistImportService.swift`：识别 `global_specialid=collection_…`、`gcid` 参数、`t*.kugou.com` 短链，短链用 URLSession 跟随 302 取落地页参数；`KugouMusicAPI.swift` 新增 `collectionPage` / `collectionDetail`（`pubsongs/v2/get_other_list_file_nofilt` 公开接口，实测可取 1619 首与歌单名），`mapTrack` 补「歌手 - 歌名」拆分 |
| 4 | 歌词特效与集成舞台都没生效 | `LyricStage.swift`：ready 兜底改为调用 `reportReady()`（此前只置内部 ready、不回调 SwiftUI，舞台被 `lyricStageReady` 永久挡住）；`PlayerView.swift` / `ReferencePlaybackView.swift`：加 2.4s 超时强制显示舞台、舞台透明度 0→0.001 避免 WebKit 暂停出帧；`ReferencePlaybackView.swift` 新增 `focusedLyricContent`，逐字/大字同步到 Apple Music 方案；`karaokeText` 改富文本拼接避免长句溢出 |

> 舞台 HTML 已用 Chromium 实测（001 粒子歌词）：init/tick 协议正常、canvas 正常出帧，问题在原生侧的 ready 门控。

### 0.4.0 本轮（2026-11-21，版本 **1.18.0 (88)**）

用户 4 条反馈。**最重要的结论：歌词舞台 HTML 从未被打进安装包**——`beans-project.yml` 把 `LyricStages/**` 从 sources 排除，又试图用 `resources:` 补回，但 XcodeGen 的 target 没有 `resources` 字段，该段被静默忽略。CI 构建日志可验证：全程没有一行 `.html` 的 `builtin-copy`。

| # | 反馈 | 处理（改动文件） |
|---|---|---|
| 1 | 导入歌单下方不显示已导入歌单 | `LibraryView.swift` `importedItems`：`libraryShowsImported` / `libraryShowsAll` 时返回 `importedStore.items`（全部平台），不再按 `source` 过滤把人导入的酷狗歌单藏起来 |
| 2 | 舞台开关打开后没变化、回头又自动关闭 | ① `beans-project.yml`：`LyricStages` 改为 `type: folderReference` + `buildPhase: resources`，保留目录（353 舞台要引 `assets/353-grain.png`）；② `LyricStage.swift` 新增 `LyricStageResources` 直拼路径 + 存在性检查 + 缓存；③ 两个播放器删掉 `onReady(false)` 里的 `lyricStageEnabled = false`；④ 资源缺失时不挂 WebView，`task` 兜底也加资源 guard；⑤ 设置页加「舞台资源已就绪 30/30」自检 |
| 3 | 「手动导入音源」改名 | `LibraryView.swift` 菜单项改「手动导入歌单」，两处注释同步 |
| 4 | 集成酷我 / 哔哩哔哩登录与歌单 | **本轮未做**，原因见下 |

> 平台级接入的真实成本：`SongSource` 只有 5 个硬编码 case（`netease/qq/kugou/migu/bodian`），全仓 `.bodian` 相关分支 111 处；`Song` 还要为每家加专属字段（酷我 rid、B 站 bvid/cid），并各自实现「搜索 / 歌单 / 播放地址 / 歌词 / 登录态」五条链路（参考 `KugouMusicAPI.swift` 2479 行、`BodianMusicAPI.swift` 556 行）。两个平台约等于 2500~3000 行新代码 + 贯穿 20+ 文件的 switch 扩展，需要单独一轮专项做，否则极易把已稳定的播放链路改崩。另：B 站还需要 SESSDATA Cookie 与 wbi 签名，版权音轨大量不可播，体验会明显弱于现有平台。

### 0.5.0 本轮（2026-11-21，版本 **1.19.0 (90)**，提交 `c9dd4ab`）

用户 5 条反馈 + 1 图。**关键发现：舞台 HTML 虽然早在 1.18.0 就进了包，但一直被 XcodeGen 平铺到 `Beans.app/` 根目录，`assets/` 整层丢失** —— `508-future-is-here` 引 `assets/508-three.min.js`、`304-kidcore` 引 `assets/fonts/ZCOOLKuaiLe-Regular.woff2`，平铺后全部 404，这类舞台只能显示空白或退化字体。已在 `beans-project.yml` 里删掉 `type: folderReference` 的 sources 条目与 `resources:` 里的 LyricStages，改用 `postBuildScripts` 整目录 `cp -R` 到 `Beans.app/LyricStages/`（`ENABLE_USER_SCRIPT_SANDBOXING: NO`），CI 日志与 IPA 实测：`Payload/Beans.app/LyricStages/` 下 68 个 HTML + 14 个 assets 全部就位。

| # | 反馈 | 处理（改动文件） |
|---|---|---|
| 1 | 舞台模式要真全屏：底部进度/前进后退、上下两块毛玻璃全部藏掉 | `ReferencePlaybackView.swift`：舞台 WebView 常驻 + 就绪后 `zIndex(2)` 铺满，`if !lyricStageActive` 整块移除 header 与 `playbackControls`；新增 `stageCanvas(insets:)`（透明点击层 + `immersiveChrome(insets:)` 呼出式极简控制层，按安全区留白）、`stageChromeVisible` 状态。`PlayerView.swift`（经典/黑胶/沉浸三套方案）：`stageImmersive` 为真时藏 `headerBar` 与 `controlDeck`，只留 `stageExitChrome`（左上角 chevron.down，点击退回封面页），避免进了舞台出不来 |
| 2 | lizi 号称 60 多种，要完整方案 | `LyricStages/` 从 30 → **68** 个舞台（新增 305/339/361/383/406/504–510/517–525/540/552/557/559/561/563/571/572/580/582/590/603/604/614/617/621/627/628/629/631 共 38 个）+ 依赖字体/three.js/gsap；`LyricStage.swift` 的 `LyricStage.all` 重写为 68 条（经典/图形/影像/实验四组），`tint` 默认值改为按编号黄金分割取色；`LyricStagePickerSheet` 加搜索框 |
| 3 | 集成酷我登录与歌单 | 新增 `KuwoMusicAPI.swift`（约 830 行）：`KuwoMusicAuth` 存 Cookie/uid/歌单；搜索走 `www.kuwo.cn/search/searchMusicBykeyWord`，歌单详情走公开 `nplserver.kuwo.cn/pl.svc`，播放地址走 `antiserver.kuwo.cn/anti.s`，歌词复用同曲库的 `BodianMusicAPI.lyric`（酷我歌词接口已加密）；`KuwoLoginSheet` 用 `WKWebView` 轮询 Cookie，拿到 `userid` 后进 `/my/playlist` 用 `evaluateJavaScript` 抓歌单卡片，另提供「粘贴歌单链接」「粘贴 Cookie」两条兜底。`www.kuwo.cn/api/www/*` 即使带上还原的 `Secret` 签名仍返回 `The request is illegal`（实测），所以官方接口只作可选路径。全仓 `SongSource/.kuwo` 分支约 30 处：`Models`、`SearchView`、`LibraryView`、`PlayerManager`、`FavoritesStore`、`DownloadManager`、`PlaylistImportService`、`CommentsSheet`、`ArtistHomeSheet`、`UnblockService`（"kw"）、`LXScriptSourceRunner` 等 |
| 4 | 点云朵按钮卡半天不弹同步页 | 根因：`prepareAndShowCloudSync()` 必须等所有平台 `loadLibrary` 跑完才置 `showCloudSyncSheet = true`，任一平台超时就是「点了没反应」；且上千歌单一次性 `ForEach`。改为**先弹面板再后台补齐**（`Task { await refreshCloudSyncSources() }`，面板 `.task` 里再补一次并在头部显示「正在补齐各平台歌单…」），歌单列表改 `LazyVStack` + 每平台先渲染 60 个、点「显示更多」每次 +200；`mergeNewPlaylists()` 只自动勾选新增歌单，不复活用户手动取消的 |
| 5 | 歌单可排序、可置顶（最多 6 个） | 新增 `LibraryPlaylistPins.swift`：`LibraryPlaylistPrefs`（`maxPinned = 6`，`pinned`/`order` 持久化，`sorted()` 未排过的保持原相对顺序）、`LibraryPinnedPlaylistCard`、`LibraryPlaylistOrderSheet`（`List` + `EditMode.active` + `onMove` 拖拽，右侧图钉置顶并显示 `n/6`）。`LibraryView.swift` 歌单墙顶部新增横向「置顶歌单」区 + 「排序」入口；`LibraryWall.swift` 全部歌单页菜单也加「调整歌单顺序」 |

CI 第一轮（`c5e8409`）报 3 个编译错误，均已修（`ac27759`）：`ArtistHomeSheet` 的 `Artist(id:name:avatarURL:albumCount:songCount:)` 实际签名只有 `(id:name:coverURL:source:)`；`PlaylistImportService` 把 `text` 写成了 `raw`；`KuwoLoginWebView.Coordinator` 未声明 `WKScriptMessageHandler`（直接删掉未使用的 `userContentController` 注册）。

新增文件：`KuwoMusicAPI.swift`、`LibraryPlaylistPins.swift`、`LyricStages/*.html`（+38）、`LyricStages/assets/*`（+13）。

需要真机重点验证：
1. 舞台全屏后轻点呼出控制层的位置是否避开灵动岛，左滑能否回封面
2. `508-future-is-here`（three.js）、`505-metalheart-prism`、`627-ink-line-rush`、`304-kidcore` 这四个依赖 `assets/` 的舞台现在是否正常出画（本轮修的就是这个）
3. 酷我网页登录：能否拿到 Cookie、能否抓到「我的歌单」；抓不到时手动粘贴歌单链接是否可用
4. 云朵按钮是否「点了立刻弹」；上千歌单展开是否还卡
5. 置顶 6 个后第 7 个是否弹「最多置顶 6 个」提示


### 0.3.0 上一轮（2026-11-21，版本 **1.16.0 (86)**）

按用户 7 条反馈继续改（本地已改完，push 后 CI 出包覆盖 beans-latest）：

| # | 反馈 | 处理（改动文件） |
|---|---|---|
| 1 | 左上角「全部歌单」大字与小字重复，图标调大 | `LibraryView.swift` 的 `libraryTitleButton`：去掉 24/28pt 大字，图标放大到 36/40，配 13pt 小名称 |
| 2 | 全部歌单页右上角管理、隐藏/删除；分类加「本地」 | `LibraryWall.swift` `LibraryAllPlaylistsSheet` 右上角「管理」按钮：多选隐藏 + 恢复全部隐藏；`LibraryView.swift` `wallItems` 纳入本地自建歌单，本地角标改「本地」 |
| 3 | 云歌单导入/复制到本地歌单 | 新增 `CopyToLocalPlaylistSheet.swift`；`PlaylistView.swift` header 加「保存到本地」按钮；基于 `LocalLibraryStore` 追加到现有/新建本地歌单 |
| 4 | 歌单新增「收藏」分类 | `LibraryView.swift` 引入 `FavoritePlaylistStore`，`wallItems` 追加收藏歌单（platformKey=favorite，红色爱心角标） |
| 5 | 全部歌曲批量加入播放列表 + 清除重复 | `LibraryWall.swift` `LibraryAllSongsSheet` 加多选：批量 `player.appendToQueue` / 存入本地；`LocalLibraryStore.replaceSongs` + `PlayerManager.appendToQueue`；去重按「歌名+歌手」 |
| 6 | 歌词仍黑屏 | `LyricStage.swift` 注入 ResizeObserver + 多次 resize + ready 回调；`PlayerView.swift` / `ReferencePlaybackView.swift` 加 `lyricStageReady`，舞台首帧未就绪时保留原生歌词兜底，杜绝纯黑 |
| 7 | 原生歌词新展示方式 | `Models.swift` 新增 `LyricDisplayMode`（经典/逐字高亮/大字聚焦）；`PlayerView.swift` 的 `LyricsSection` 逐字上色 + 大字渐变；设置-歌词显示加分段选择器，`beans.lyricDisplayMode` 持久化 |

> 注意：本轮无本地 Xcode，未本地编译；正确性靠括号平衡 + 引用核对，最终以 CI 编译为准。若 CI 报 `error:`，看 `ci-failure.log` 回传内容定位。

### 0.3 当前状态（2026-11-21，版本 **1.13.0 (83)**）

1.12.0 之后按用户新 9 条反馈继续改：

| # | 反馈 | 处理 |
|---|---|---|
| 1 | 图标羽化 | `Assets.xcassets/AppIcon.appiconset/AppIcon.png` 换成猫头照片（1024，无 alpha）：焦糖径向背景 + 圆角羽化蒙版 + 人像景深虚化 + 暗角；`OnboardingLogo` 同步换图 |
| 2 | 手势冲突 | 删除「左右滑动切歌」开关（`beans.swipeSwitchSong`）及所有 guard、删掉死代码 `flySwipe`；手势固定为：上滑下一曲 / 下滑上一曲 / 封面左滑返回 / 右滑歌词 / 歌词页左滑返回 |
| 3 | 三套方案设置混乱 | 只保留一个「播放方案」入口：经典 / Apple Music / 黑胶 / 沉浸。删除独立的「播放器按钮样式」开关，按钮外观由方案派生（`BeansCoverPlayerStyle.buttonStyle`）；删除重复的「Apple Music 样式」卡片，AM 专属项并入播放方案卡片。设置项按方案过滤：封面文字配色只对经典，布局对经典 + AM，AM 隐藏控件取色（避免和悬浮调试互相覆盖）。进度条样式/颜色现在对四种方案都生效（AM `ReferenceScrubber`、黑胶 `vinylKumoneProgress` 都改用 `SeekBar`）；光晕/浮尘/DJ 也接进 AM 背景 |
| 4 | 沉浸式风格 | `BeansCoverPlayerStyle.immersive` + `PlayerView` 新分支：封面重度虚化铺满 + `immersiveCoverMask` 径向羽化溶进背景 + 极简底部控制（SeekBar + 三键）；沉浸式强制深色 palette，浅色模式文字也清晰 |
| 5 | 曲库云同步 | 新增 `LibraryCloudSync.swift`：`LibraryCloudSyncStore` 逐个歌单拉歌曲 → `SyncedPlaylistCache`（`pinned: true`，不参与 TTL 过期）→ `CoverThumbCache` 预下载封面。同步面板显示进度、歌单/歌曲/封面数、用时、失败列表；音乐库头部新增云同步按钮 |
| 6 | 全部歌曲卡顿 | `LibraryAllSongsSheet` 改 `LazyVStack` + 首屏 60 首、滑到底再加 60；歌手/语言标签提前算好，筛选变更重置分页 |
| 7 | 迷你播放器进度 | `MiniPlayerView` 卡片背景内新增 `MiniPlayerProgressFill`：水位式填充 + 正弦波浪（`TimelineView` 仅在播放时驱动），四种 UI 风格 × 深浅色各一套低透明度配色 |
| 8 | 音乐库文字遮挡 | `PlaylistWallView` 行高由固定 150 改为 `cellWidth + 46`（封面 + 标题 + 副标题实际高度），`LibraryAllPlaylistsSheet` 用计算好的格子边长替换 GeometryReader+aspectRatio |
| 9 | 我的页面 | 移除更新地址 / 检查更新 / 交流群 / 赞助三张卡片，仅保留版本信息 |

新增文件：`CoverThumbCache.swift`（封面缩略图磁盘缓存，`CoverImage` 全部改走它）、`LibraryCloudSync.swift`。

需要真机重点验证：
1. 沉浸式方案在 14 Pro Max 上的封面羽化观感、上/下滑切歌、左滑返回
2. 云同步面板（多个平台账号同时登录）的耗时与失败项
3. 四种方案的进度条样式是否都真的变化
4. 迷你播放器波浪填充在四种 UI 风格下的观感（浅色 / 深色各看一次）

注意：`LibraryView` 里旧的 `playlistsSection / qqSection / kugouSection / bodianSection` 已不再被渲染（保留代码，咪咕仍用 `miguSection`），后续可删。

### 0.4 本轮改动（2026-11-21，版本 **1.14.0 (84)**）

按用户 6 条反馈继续改：

| # | 反馈 | 处理 |
|---|---|---|
| 1 | 云同步特别慢，只要歌曲信息和缩略图 | 根因：`SyncedPlaylistCache` 原先把全部歌单塞进一个 UserDefaults key，每同步一个歌单都要全量解码+全量编码重写，O(n²)。改为**按歌单分文件落盘**（`songDirectory/<key>.json`）+ 内存 LRU，单歌单只写自己那一个文件；歌单拉取改 3 路并发（`withTaskGroup`）；封面缩略图改为**可选**（同步面板开关）且完全不阻塞歌曲信息，攒够 120 条才丢到 `.utility` 后台任务里预热 |
| 2 | 手势说反了 | 统一为：**播放页左滑返回、右滑进歌词；歌词页左滑回播放页**；上滑下一曲 / 下滑上一曲不变。`PlayerView.handleSwipeEnd` 与 `ReferencePlaybackView.coverSwipeGesture` 都已对齐，参考播放页新增 `onClose` 闭包由 `PlayerView` 传入 `isPresented = false` |
| 3 | 音乐库歌单默认要全部平台 | 新增 `allCloudPlaylists`（汇总网易/QQ/酷狗/波点各账号歌单）+ 本机导入歌单，卡片带**来源平台角标**（`LibraryWallBadge`）与**歌曲数量**，并支持按平台筛选；`LibraryWallItem` 增 `badge / platformKey` 字段（带默认值，兼容旧构造） |
| 4 | 沉浸式很丑，封面要放大到全屏宽、周边渐变模糊遮罩溶于背景 | 新增 `ImmersiveCoverArt`（全宽长方形封面，走 `CoverThumbCache` 按需裁剪）；`immersiveBackground(geo:)` 用 1.34 倍宽 + 56pt 模糊的封面做过渡带；主封面全屏宽 + 上下/左右双重羽化蒙版（`immersiveVerticalMask` / `immersiveHorizontalMask`）+ 底部渐变压暗；`immersiveCoverHeight` 按屏高自适应 |
| 5 | mini 进度条再做一套横向的，设置里加开关和切换方式 | `MiniPlayerProgressStyle` 枚举：`off / vertical / fill / bar`，存 `beans.miniProgressStyle`；`.fill` 是横向水位（`WaveEdgeShape` 右侧流动波纹），`.bar` 是底部细线；播放设置新增「迷你栏进度」卡片（四宫格切换 + 说明文案） |
| 6 | 集成 liziair 歌词舞台，可配置 | 打包 30 个 `public/stages/*.html` 到 `beans-ios/LyricStages/`（folder reference 资源，离线运行，共约 2.5MB）；新增 `LyricStage.swift`：`LyricStageWebView`（WKWebView + `postMessage` 桥接 `{__c100:1,type:'init'|'tick'}`）、`LyricStagePickerSheet`（按「经典/图形/影像」分组、开关、30 种可切换）。原生侧把 `LyricLine` 转成带 `t/time/text/s/txt/dur` 别名的行以兼容各舞台字段差异；歌词页右上角「舞台」按钮直达选择器；`ReferencePlaybackView` 歌词页同步接入。设置默认**关闭**，避免吃性能 |

新增文件：`LyricStage.swift`、`LyricStages/*.html`（30 个）、`LyricStages/assets/353-grain.png`。工程配置 `beans-project.yml`：`sources` 排除 `LyricStages/**`，`resources` 以 `type: folder` 打包该目录。

需要真机重点验证：
1. 云同步耗时（多平台账号同时登录）是否明显下降，封面开关关闭时是否更快
2. 三种封面方案 + 沉浸式的左滑/右滑/歌词页左滑手势
3. 沉浸式封面全屏宽 + 羽化遮罩的观感
4. 迷你栏 `.fill` / `.bar` 两种横向进度在四种 UI 风格 × 深浅色下的观感
5. 30 个歌词舞台是否都能正常出词（个别舞台字段差异已用别名兼容），WKWebView 内存与发热

### 0.5 本轮改动（2026-11-21，版本 **1.15.0 (85)**）

按用户 9 条反馈继续改：

| # | 反馈 | 处理 |
|---|---|---|
| 1 | 手势方向说反了：左滑=从左往右(dx>0)、右滑=从右往左(dx<0) | `PlayerView.handleSwipeEnd` + `lyricsSwipeBackGesture`、`ReferencePlaybackView.coverSwipeGesture` + `lyricsSwipeBackGesture` 全部翻转：播放页从左往右返回 / 从右往左进歌词；歌词页从左往右回播放页 |
| 2 | 沉浸式封面/歌词溢出屏幕 | 去掉背景里 1.34 倍放大的封面（溢出元凶）；封面宽度严格=屏宽、四周径向羽化溶进背景；歌名与歌词移到封面下方独立区；`lyricPreviewBox` 歌词 `Text` 加 `frame(maxWidth:.infinity)` 防撑破 |
| 3 | 同步面板 | 新增按平台 + 按歌单勾选（默认全选）；封面改为默认只缓存「歌单封面」一张，去掉开关；修「已登录却显示未登录」bug——打开面板前 `prepareAndShowCloudSync()` 并发拉取所有平台歌单 |
| 4 | 音乐库左上角默认全部歌单 | 新增 `libraryShowsAll=true`；标题用 BrandAll 图标 + "全部歌单"，菜单第一项「全部」，点击切换平台或手动导入；`wallItems` / `librarySubtitle` 按选择过滤 |
| 5 | 全屏页面 + 手动导入音源类别 | `LibraryAllPlaylistsSheet` / `LibraryAllSongsSheet` 由 `.sheet` 改 `.fullScreenCover`；新增 `LibraryBackButton` + `.librarySwipeBack`（从左往右滑返回）；左上角菜单新增「手动导入音源」，复用 `importedSection`（导入/更新/删除） |
| 6 | lizi 歌词舞台全黑 | 根因：`LyricStageWebView`(UIViewRepresentable) 没有 frame，WKWebView 尺寸为 0；两处挂载点补 `.frame(maxWidth:.infinity,maxHeight:.infinity)`，`sendInit` 里追加 `resize` 事件让 WebGL/Canvas 重建 |
| 7 | 播放按钮无液态玻璃感 | `playerButtonSurface` 的 glass/appleMusic 分支统一加：顶部内高光渐变 + 底部冷影 + 环形描边 + 外阴影 |
| 8 | 主页「全部平台歌单」改名 | `playlistSectionTitle` 的 `.all` → "热门歌单" |
| 9 | 主页图标下方加标题 | providerPicker 下方、板块上方新增 `todayRecommendationTitle`（"今日推荐" + "为你精选，每天更新"） |

需要真机重点验证：
1. 手势方向是否符合直觉（从左往右返回 / 从右往左进歌词）
2. 沉浸式封面是否不再溢出、四周羽化是否自然
3. 同步面板勾选是否生效、平台登录态是否正确、封面只缓存歌单封面
4. 全屏页左上角返回 + 从左往右滑返回是否都可用
5. 歌词舞台是否不再全黑、30 种是否都能出词
6. 播放按钮液态玻璃观感

---

## 一、仓库与基础信息

| 项 | 值 |
|---|---|
| 本地路径 | `D:\Document\11 deepseek\01 lxmusic\lx-music-mobile-ios` |
| 仓库 | `zhuhonghao0323/lx-music-mobile-ios` |
| 工作分支 | `ios-adaptation`（默认分支是 `main`，**不要推 main**） |
| 最新提交 | `b9b55cc2` |
| Git 可执行文件 | `C:\Users\zhuho\AppData\Local\Programs\WorkBuddy AI\resources\vendor\PortableGit\cmd` |
| Token | `<YOUR_GITHUB_PAT>`（用户 `zhuhonghao0323`） |

### 推送命令（必须这样写，普通 push 会 403）

```bash
basic=$(printf '<GITHUB_USER>:<YOUR_GITHUB_PAT>' | base64 -w0)
git -c http.sslBackend=openssl \
    -c http.proxy=http://127.0.0.1:7897 \
    -c https.proxy=http://127.0.0.1:7897 \
    -c "http.https://github.com/.extraheader=Authorization: Basic $basic" \
    push origin HEAD:ios-adaptation
```

网络不稳，需重试 3-5 次（常见 `TLS connect error` / `Recv failure`，重试即可）。

### 提交规范
```bash
git -c user.name=zhuho -c user.email=zhuho@users.noreply.github.com commit -m "..."
```
多行消息用 `-F 文件`（UTF-8 无 BOM），不要用 `-m` 传多行。

---

## 二、项目现状：两条技术线并存

### 线 1：React Native 工程（原有主体）

- 根目录：`src/`、`ios/`
- 技术栈：RN 0.73.11（旧架构）、react-native-navigation 7.39、react-native-pager-view
- 播放引擎：react-native-track-player 2.1.2（fork）+ 原生 FLAC 流式播放（`ios/LxMusicMobile/AppDelegate.mm`，~4600 行）
- **功能完整可用**，包含：音源脚本、歌单、搜索、排行榜、歌词、下载、同步备份等

### 线 2：Beans 纯 SwiftUI 工程（新基底，本次重构方向）

- 目录：`beans-ios/`（72 个 Swift 文件，35768 行）
- 来源：https://github.com/XIaodou0416/Beans-Music
- 构建：`beans-project.yml` + XcodeGen
- **已编译成功**，产出 6.29MB IPA
- 关键：**必须用 `macos-26` runner（Xcode 26）**，源码依赖 iOS 26 的 `.glassEffect` / `GlassEffectContainer` API

---

## 三、总体需求（用户原始诉求）

### 设计目标
把 App 做成**真正按 Liquid Glass 设计理念构建的现代音乐播放器**，接近 Apple Music 的体验，而非"套了个玻璃皮肤"。

### 硬性约束（用户明确列出 11 条）
1. 优先使用系统原生控件（NavigationStack、List、Section、Form、原生 ButtonStyle），禁止大量手写 RoundedRectangle 自定义卡片/按钮
2. 图标只用 SF Symbols，统一 `.renderingMode(.hierarchical)`，禁止 emoji、自定义图片
3. 字体只用系统动态文本样式（.headline/.subheadline/.body/.caption/.footnote），严禁写死 `font(.system(size:))`
4. 颜色用系统语义色 `Color.primary/.secondary/.tint`，全局配置 tintColor，禁止随意写死 RGB、滥用渐变、花哨阴影
5. 间距严格 8pt 栅格（8/16/24/32）
6. 所有可点击控件热区 >= 44pt
7. 自动处理 SafeArea，支持浅色/深色
8. 一页只保留一个主操作按钮
9. 动画克制，禁止旋转/缩放/悬浮特效
10. 合理拆分子 View，补充 Xcode Preview（深浅双版本）
11. 禁止增删业务功能

### 播放页沉浸感的具体要求（用户给的四层结构）
1. **底层背景**：专辑原图 `aspectRatio(.fill)` + `ignoresSafeArea()` 铺满 + `blur(radius: 60~90)` + 压暗
2. **融合渐变层**（最关键）：垂直渐变（透明 → 半透黑 0.35~0.55），让封面底部融入模糊背景，消除硬边
3. **实体封面**：居中圆角清晰封面，不要贴死底边
4. **UI 控件层**：歌词/进度/按钮，用 `.ultraThinMaterial` 玻璃材质

加分项：封面取色染色、微视差、呼吸微动、换歌 matched transition。

### 底部导航要求
首页、播放、我的三个按钮 + 迷你播放器胶囊，**形成一个整体悬浮玻璃托盘**，不是两个独立半透明矩形。

---

## 四、进度与已完成工作

### ✅ 已完成（Beans 线）
1. 引入完整 Beans 工程到 `beans-ios/`
2. 新建 `.github/workflows/beans-ipa.yml`（macos-26 + XcodeGen）
3. **编译成功**，Release tag `beans-latest` 产出 `beans-music-ios-unsigned.ipa`（6.29MB）
4. 确认 Beans 内置 `LXScriptSourceRunner.swift`（877 行），原生支持 LX 脚本 API：
   - `lx.request` / `lx.on` / `lx.send`
   - `lx.utils.crypto`（md5/aesEncrypt）、`lx.utils.buffer`
   - 兼容 `cerumusic` 命名空间

### ⚠️ 已完成但效果不佳（RN 线，已被放弃）
曾在 RN 上做 SwiftUI 桥接重构（`SwiftUIPlayerView.swift` 等），但**布局反复出问题**（播放页按钮被裁、顶部重叠、首帧错乱），用户明确不满意。

**教训**：在 RN 壳里用 `UIHostingController` 嵌 SwiftUI 存在系统性布局问题（safeArea 双重计算、首帧尺寸错误）。已耗时十几轮未解决。

**这些文件仍在仓库里**：`ios/LxMusicMobile/SwiftUI/`、`src/screens/SwiftUIPages/`、`src/screens/PlayDetail/SwiftUI/`。如需清理可删除，但注意 RN 侧有引用（`isSwiftUIPlayerSupported`）。

### ❌ 未开始（核心待办）
1. **把 LX 音源接入 Beans**：Beans 目前用自建 API（`NetEaseAPI.swift`/`QQMusicAPI.swift`/`KugouMusicAPI.swift`），`SearchProvider` 只支持网易云/QQ/酷狗三家，需要接入 LX 的 JS 音源脚本机制
2. 移植 LX 的音源管理（脚本导入、启用、自定义源）
3. 对接歌单、收藏、播放历史数据
4. 设置项对齐（保留 LX 常用设置）
5. 品牌替换（Beans Music → LX Music，Bundle ID、图标、名称）

---

## 五、关键技术信息

### Beans 工程结构（关键文件）
| 文件 | 行数 | 职责 |
|---|---|---|
| `PlayerView.swift` | 4738 | 播放页（含歌词、队列、封面样式） |
| `PlayerManager.swift` | 1715 | 播放引擎（AVFoundation） |
| `DiscoverView.swift` | 2185 | 首页发现 |
| `ProfileView.swift` | 3548 | 我的页 |
| `SearchView.swift` | 1194 | 搜索页 + `SearchProvider` 枚举 |
| `LibraryView.swift` | 859 | 音乐库 |
| `RootView.swift` | 889 | 根视图（TabView + 底部导航 + 播放页 presentation） |
| `Theme.swift` | 920 | 主题色/字体/材质（`Color.beansAmber` 等） |
| `Components.swift` | 916 | 通用组件（`BeansGlass` 等） |
| `Models.swift` | 572 | 数据模型 |
| `LXScriptSourceRunner.swift` | 877 | **LX 脚本运行器（已内置）** |
| `NetEaseAPI.swift` | 679 | 网易云 API |
| `BeansApp.swift` | - | `@main` 入口 |

### Beans 的设计 Token（可复用）
```swift
Color.beansBackground  // 浅 #F2F2F7 / 深 #0A0A0C
Color.beansCard        // 浅 #FFFFFF / 深 #1C1C1E
Color.beansLabel       // 主文字
Color.beansSecondary   // 次级 #6C6C70 / #98989F
Color.beansAmber       // 品牌色（当前是琥珀金）
Color.beansGlassFill   // 玻璃基底 rgba
```

### 布局正确姿势（照 Beans 的做法）
- 根视图用 `TabView`，播放页用 `fullScreenCover`
- 需要安全区数值时用 `GeometryReader { proxy in ... proxy.safeAreaInsets.top }`
- **不要**在 HostView 里手动扣 safeArea（会双重扣除）
- 背景用 `.background(.ultraThinMaterial)` 或 iOS 26 的 `.glassEffect`

---

## 六、构建与验证

### Beans 编译（本地）
```bash
brew install xcodegen
xcodegen generate --spec beans-project.yml
xcodebuild -project Beans.xcodeproj -scheme Beans \
  -configuration Release -sdk iphoneos \
  -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" \
  build
```

### RN 侧验证（如仍需改动 RN）
```bash
node node_modules/typescript/bin/tsc --noEmit -p tsconfig.json
node node_modules/eslint/bin/eslint.js <changed files>
# Metro bundle 验证
$env:TMP="$PWD\.metro-tmp"; $env:TEMP=$env:TMP
node node_modules/react-native/cli.js bundle --platform ios --dev false \
  --entry-file index.js --bundle-output .metro-bundle.js \
  --assets-dest .metro-assets --max-workers 1
```

### CI
- RN workflow：`.github/workflows/ios-ipa.yml`（macos-15）
- Beans workflow：`.github/workflows/beans-ipa.yml`（**macos-26**）
- Release：RN 用 `latest` tag，Beans 用 `beans-latest` tag

### CI 日志获取（API 直连会 302，用 curl 跟随跳转）
```bash
curl -sL -H "Authorization: Bearer ghp_..." -H "User-Agent: dsh" \
  "https://api.github.com/repos/zhuhonghao0323/lx-music-mobile-ios/actions/jobs/<JOB_ID>/logs" -o job.log
grep -n "error:" job.log | head -30
```

---

## 七、用户偏好与注意事项

### 沟通
- **必须用中文回复**
- 用户对反复失败非常不满，**不要盲目改代码**，先定位根因
- 用户会截图反馈，看图分析比猜测有效

### 交付
- **打包好后只报告，不要下载 IPA 给用户**（用户自己会下）
- 每次交付要给出 Release 下载链接
- iOS 最低版本：用户要求 **iOS 17+**（但 Beans 源码需要 iOS 26 才有完整玻璃效果，有 `#available` 降级分支）

### 已知坑
1. **CI 必须 macos-26**，否则 `GlassEffectContainer` / `.glassEffect` 编译失败
2. GitHub Release 同名资产需 `overwrite_files: true` 才会覆盖
3. `softprops/action-gh-release` 不加 overwrite 会跳过上传
4. PowerShell 操作 .tsx 文件易损坏编码（`i`→`m`），用 `write` 工具整文件重写
5. RN 壳内嵌 SwiftUI 布局不稳，是本次重构转向纯 SwiftUI 的原因

---

## 八、下一步建议（给接手的 Agent）

**优先级 1：先让用户确认 Beans 的 UI 是否满意**
- 已有 IPA：https://github.com/zhuhonghao0323/lx-music-mobile-ios/releases/download/beans-latest/beans-music-ios-unsigned.ipa
- 用户看完满意 → 继续接入 LX 音源
- 不满意 → 回退 RN 线（`79e1978d` 是稳定版本）

**优先级 2：接入 LX 音源**
- 研究 `LXScriptSourceRunner.swift` 的 `resolve()` 接口
- 参考 `UnblockService.swift:299` 的调用示例
- 需要把 `SearchProvider` 扩展为支持 LX 自定义源
- 音源脚本存储、导入、启用流程参考 RN 侧 `src/core/` 的实现

**优先级 3：数据层对接**
- 歌单/收藏/历史：Beans 有 `FavoritesStore`、`LocalLibraryStore`，需要映射 LX 的数据结构
- 或者直接沿用 LX 的存储格式，减少迁移成本

**优先级 4：品牌替换**
- `beans-project.yml`：`CFBundleDisplayName`、`PRODUCT_BUNDLE_IDENTIFIER`
- 图标：`beans-ios/Assets.xcassets/AppIcon.appiconset/`

---

## 九、LX 音源接入技术细节（重点）

### Beans 现有的 LX 脚本能力：只做了「播放链接解析」

`LXScriptSourceRunner.swift` 目前的核心用途在 `UnblockService.swift:299`：
```swift
if let resolved = await LXScriptSourceRunner.shared.resolve(...) {
    // resolved.url 是可播放的音频链接
    // resolved.source / resolved.quality
}
```
它做的是：给定一首歌（`musicInfoPayload`），调用 LX 脚本的 `musicUrl` 能力，拿到音频直链。**用于"解锁"灰色/无版权歌曲。**

### 缺失的部分：LX 的「搜索 / 歌单 / 排行榜」能力

Beans 的搜索走自建 API（`NetEaseAPI`/`QQMusicAPI`/`KugouMusicAPI`），**没有**走 LX 脚本的 `musicSearch` / `songList` / `leaderboard` 能力。

所以接入 LX 需要新增：
1. **搜索**：调用 LX 脚本的 `musicSearch.search(keyword, page, limit)`
2. **歌单**：`songList.getTags()` / `songList.getList(tagId, sortId, page)`
3. **排行榜**：`leaderboard.getBoards()` / `leaderboard.getList(boardId, page)`
4. **音源管理**：脚本的导入/存储/启用/切换

### 脚本运行时接口（`BeansLXScriptRuntime`）
```swift
// 已支持（从 LXScriptSourceRunner.swift 可见）：
- lx.request(url, options, callback)
- lx.on(event, handler)      // 接收脚本注册的能力事件
- lx.send(event, payload)
- lx.utils.crypto.md5 / aesEncrypt
- lx.utils.buffer.from / bufToString
- lx.env / lx.version / lx.currentScriptInfo
- cerumusic 命名空间兼容层
```

### `SearchProvider` 当前只有三家
`SearchView.swift:41`：
```swift
enum SearchProvider: String, CaseIterable, Identifiable, Hashable {
    case netease = "网易云音乐"
    case qq = "QQ音乐"
    case kugou = "酷狗音乐"
}
```
需要扩展为支持 LX 自定义源（动态列表，不能是固定 enum）。

### LX 侧参考实现位置（RN 工程）
| 能力 | RN 实现 |
|---|---|
| 音源脚本管理 | `src/core/init/userApi.ts`、`src/utils/musicSdk/` |
| 搜索 | `src/core/search/music.ts`、`src/core/search/songlist.ts` |
| 歌单 | `src/core/songlist.ts` |
| 排行榜 | `src/core/leaderboard.ts` |
| 音源定义 | `src/utils/musicSdk/*.js`（kw/kg/tx/wy/mg） |

### LX 脚本标准接口（协议）
LX 音源脚本通过 `lx.on('request', ...)` 注册，需实现：
```js
// 脚本必须提供的 action
'musicUrl'      // 获取播放链接
'musicSearch'   // 搜索
'songList'      // 歌单（getTags / getList）
'leaderboard'   // 排行榜（getBoards / getList）
```
返回值格式需与 `src/utils/musicSdk/` 里的定义一致。

---

## 十、重要提醒

### 关于「播放页永远是老样式」的历史问题（已定位）
之前十几轮反复失败，最终查明是两个原因叠加：
1. `isSwiftUIPlayerSupported` 用 `NativeModules.LXSwiftUIPlayerViewManager` 判断，永远 undefined（ViewManager 不进 NativeModules）
2. Swift 写的 `RCTEventEmitter` 不会自动注册（缺 `+load`），需 `RCT_EXTERN_MODULE` 桥接

即使修好这两处，RN 内嵌 SwiftUI 的布局问题仍未彻底解决 —— 这是转向纯 SwiftUI 的根本原因。

### 如果决定回退
稳定版本是 `79e1978d`（SwiftUI 重构前的 RN 版本），功能完整、布局稳定：
```bash
git checkout 79e1978d -- .
```
或新建分支从该提交继续。

### 文件清理建议（如果确定走纯 SwiftUI）
可以删除以下 RN-SwiftUI 桥接残留，减少干扰：
- `ios/LxMusicMobile/SwiftUI/`（整个目录）
- `src/screens/SwiftUIPages/`（整个目录）
- `src/screens/PlayDetail/SwiftUI/`（整个目录）

同时移除 RN 侧引用：`src/screens/PlayDetail/index.tsx`、`src/screens/Home/Views/Player/index.tsx`、`src/screens/Home/Views/Mine/index.tsx` 等处的 `isSwiftUIPlayerSupported` 分支。

**注意**：删除前确认 RN 主流程仍能编译（tsc 通过）。
