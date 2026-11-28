# LX Music iOS 重构项目 · 交接文档

> 生成时间：2026-11-20（最后更新：2026-11-20 17:40）
> 交接时最新提交：`1d45f268`（分支 `ios-adaptation`）
> 下文「一 ~ N」为首次交接时的内容，其中提交号、Token 等已过期，仅作历史参考；
> **接手请先读下面的「零、云端继续做」**。

---

## 零、云端继续做（手机 WorkBuddy「云端工作」）

电脑关机后，手机 App 用「云端工作」执行环境接手。云端沙箱是 **Linux**，没有 Xcode，**改完必须靠 GitHub Actions 出包**。

### 0.0c 本轮（2026-11-28，版本 **1.21.3 (98)**）：WebDAV 跨端同步

为桌面端铺路，先把同步做掉。协议见 `doc/webdav-sync.md`。

- 远端单文件：`<目录>/beans-sync.json`，schema `beans.sync.v1`
- 合并：歌单按 `id` 并集 + `updatedAt` LWW；删除用墓碑（`tombstones`），删除后又被编辑会复活；播放状态取 `updatedAt` 较新者
- iOS：`WebDAVSync.swift`（WebDAV 客户端 + 合并 + 自动同步）、`WebDAVSyncSettingsView.swift`（设置页），入口在「设置 → 数据同步（WebDAV）」
- 自动同步触发：启动 / 回前台 / 歌单变化 6s 防抖 / 播放中每 90s；密码存 Keychain
- 桌面端：`desktop-sync/`（零依赖 Node 18+），`src/cli.js test|sync|pull`，Electron 主进程可直接 import `sync.js`
- 注意：`PlayerManager` 新增 `static weak var current`，供同步读取播放状态

### 0.0b 本轮（2026-11-28，版本 **1.21.2 (97)**）：汽水扫码登录 + Apple Music 布局的沉浸感

**一、汽水登录：从「打不开的网页」改成原生扫码**

- 实测 `music.douyin.com` 是「汽水音乐合作平台」落地页（微前端），**没有消费级网页版**，1.21.1 的内嵌网页方案点不到登录入口
- 实测官方 Passport 两个接口**不需要 a_bogus 签名**：
  - `GET https://api.qishui.com/passport/web/get_qrcode/?aid=386088&passport_jssdk_version=2.4.13&passport_jssdk_type=normal&is_from_ttaccountsdk=1&next=…` → `data.token` / `data.qrcode`（base64 PNG）/ `data.expire_time`
  - `POST …/passport/web/check_qrconnect/`（form: token + next）→ `data.status` = new / scanned / confirmed，确认后 `Set-Cookie` 下发 `sessionid`
- 新增 `QishuiQRLogin.swift`：原生拉二维码 + 1.8s 轮询 + 自动落库 + `refreshProfile()` 校验；2046（额外安全验证）时明确提示改走 Cookie
- `QishuiLoginSheet.swift` 主入口改为「扫码登录」，删除 `QishuiWebLogin.swift`
- 未做手机号验证码：`/passport/web/send_code/` 返回 4031「当前版本过低」，需要客户端版本头/签名，暂不碰

**二、真正生效的播放页是 `appleMusic` 布局**

- 默认 `beans.coverPlayerStyle = appleMusic`，走 `ReferencePlaybackView`；1.21.1 只改了 `immersive`，所以用户看不到变化
- 不沉浸的根因：`CoverBlurView` 的渐变 62% + 黑遮罩 30% + 页面层 48% 黑，四层叠加把封面颜色洗成死灰
- 改法：渐变 62%→40%、遮罩 30%→12%、页面层 48%→18%，另加只压顶部/底部的 scrim；`AmbientGlowView` 光斑 0.16/0.13→0.30/0.24
- `MiniLyricsPreview` 3 行→5 行，当前行 20pt，按距离递减字号与透明度

### 0.0a 本轮（2026-11-28，版本 **1.21.1 (96)**）：沉浸式观感 + 汽水登录改扫码/验证码

按用户反馈改了两处，只动「沉浸式」这一套播放方案的外观，播放能力与其它三套方案不动。

**一、沉浸式播放 / 歌词"不沉浸"**

| 问题 | 根因 | 改法 |
| --- | --- | --- |
| 背景是一块死板暗色，看不出封面颜色 | `ImmersiveBackdrop` 的底色层用了 0.96/0.86 不透明度的暗色，模糊封面只有 0.64 透明度又叠了重压暗，色彩被吃掉 | 底色中间段降到 0.40、模糊封面提到 0.86、饱和度 1.38，新增两层主色 `bloom` 色团；播放时背景做 9 秒一次的极慢呼吸位移 |
| 歌词页层次扁平，和封面页没区别 | 沉浸页把 `baseFontSize` 上限压到 21、当前行只放大 4pt | `LyricsSection` 新增 `focusBoost` / `pendingOpacity` / `playedOpacity` / `focusScale` 四个参数（都有默认值，其它调用点不受影响）；沉浸页传 26pt 上限、当前行 +8pt、未唱行 0.42 |
| 播放页信息密度低、控件噪 | 三行歌词、五个玻璃圆钮 | 歌词预览扩到 5 行并按距离递减；模式 / 队列改成纯图标；封面上限 380 → 400 |

**二、汽水登录太繁琐（F12 复制 Cookie）**

- 新增 `QishuiWebLogin.swift`：`WKWebView` 内嵌 `music.douyin.com`，用桌面版 UA 拿到完整网页登录（抖音扫码 / 手机号验证码），每 1.2 秒读一次 `WKWebsiteDataStore` 里的 `sessionid`，读到即落库并关闭面板
- `QishuiLoginSheet.swift` 重排：主入口变成「扫码 / 手机号登录」，Cookie 粘贴收进折叠区作兜底，高级签名服务不变
- 与网易云 / QQ 的 `*WebLoginSheet.swift` 同一套思路，不逆向 Passport 签名、不接触账号密码

### 0.0 本轮（2026-11-26，版本 **1.21.0 (95)**）：酷狗歌单修复 + 汽水接入

参照 `https://github.com/Wow-CaiCai/Coda`（AGPL-3.0，仅作协议对照，未复制其代码）修了两件事。

**一、酷狗歌单同步不全**：三个独立原因，都在 `KugouMusicAPI.swift`。

| # | 原因 | 修法 |
| --- | --- | --- |
| 1 | `collectionPage` 用 `begin_idx = (page-1)*pageSize`，服务端把 pagesize 截断到 100/300 时整段跳歌；且 `rows.count < pageSize` 直接 break，第一页只给 100 就只剩 100 首 | `beginIdx` 改为「已收条数」；新增 `collectionSongsAll`，只在空页 / 整页重复时收尾，total 对不上再重试一次 |
| 2 | 云歌单优先 `decodeCollection → specialSongs`，概念版歌单的虚拟 specialid 只给一部分 | 顺序反过来：先公开游标接口读全量，`special/song` 降为兜底 |
| 3 | `userPlaylists` 只取第 1 页（200 个）；`mapPlaylist` 对只有 `global_collection_id` 的歌单 `int()` 得 0 直接丢弃 | 按页翻到不满一页；无数字 id 时用 `stablePlaylistID`（djb2，31 位）生成稳定 id，并保留 gcid |

自建歌单的 `v4/get_list_all_file` 兜底路径也改成只在空页结束 + 重复页检测。

**二、汽水音乐**：Coda 的实现里，搜索与 App 播放流走 `X-Helios` / `X-Medusa` 签名，签名靠一个**明文 HTTP 的第三方 IP 服务**，请求还带 Cookie。这个不能内置（凭证泄露 + ATS 拦截 + 服务随时失效），所以按能力分层接入：

- 已验证免签名可用：`POST /luna/discover/mix`（推荐歌单）、`GET /luna/pc/playlist/detail`（游标分页）、`GET /luna/h5/seo_track`（曲目 + KRC 逐字歌词 + `video_model` 播放地址）、`/luna/pc/me*`（带 Cookie 的账号资料与歌单）
- 实测匿名 `video_model` 是 **30 秒试听**（`playable_range` = 143.8s 起 35.1s），且音频**未加密**（`ftyp` M4A，无 `enca`），所以没有移植 Coda 的 MP4 解密器
- 搜索需要签名：做成「高级设置里填自部署签名服务」，默认关闭，签名请求**不携带 Cookie**
- 新增文件：`QishuiMusicAuth.swift`（Cookie 存储 + `cacheAccountID`）、`QishuiMusicAPI.swift`（接口 + KRC→LRC）、`QishuiLoginSheet.swift`（登录面板）
- **内容按 App 原有功能分区**（第一版把推荐/个人歌单塞进「我的」独立页，已废弃并删除 `QishuiHomeView.swift`）：
  - 推荐歌单 → 主页「热门歌单」，`DiscoverView.fetchSnapshot(.all)` 里和网易云/QQ/酷狗/酷我/波点一起 `interleavePlaylists`
  - 个人歌单 → 音乐库「全部歌单」：`LibraryView.allCloudPlaylists` 改为 `CloudPlaylistEntry`（歌单 + 账号 + 角标），汽水歌单挂「汽水」角标混排，不新增平台标签页
  - 个人歌单歌曲 → 音乐库「全部歌曲」：`syncSources` 增加 `.qishui`，走原有 `LibraryCloudSyncStore` 云同步
  - 「我的 → 账号 → 汽水音乐」只剩登录 / 退出，和其它平台账号卡职责一致
- 接入点：`SongSource.qishui`、`Song.qishuiTrackID`、`PlayerManager.loadCurrent` 的 `qishuiResolve`、歌词两处（PlayerView / MiniPlayerView）、下载、红心（本地）、分享链接
- **没有**并进 `LibraryProvider` / `SearchProvider`：这两个枚举各自带 15+ 处 UI 分支，并进去会把「搜索里选到汽水但没有结果」暴露给用户；音乐库靠 `CloudPlaylistEntry` 承载汽水，避免多一个默认不可用的平台 tab（顶部分段控件 7 个会挤爆）

汽水未做：扫码登录、评论、歌单编辑、云端红心、歌单导入。

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

### 0.7.0 本轮（2026-11-25，版本 **1.20.0 (93)**）

用户对沉浸式播放页提出系统性重构（不是逐项打补丁）：Apple Liquid Glass + 动态封面背景 + 高级播放器体验，仅 iOS（最低 17）。这一轮**只替换 `.immersive` 方案**，经典封面 / Apple Music / 黑胶三套布局与全部播放能力保持原样。

#### 一、代码审查结论（改前的真实实现）

| 项 | 改前 |
|---|---|
| 技术栈 | SwiftUI（`beans-ios/PlayerView.swift` 5500 行，全部四套方案塞在一个文件里），无 UIKit 播放页 |
| 播放页入口 | `PlayerView.body` 按 `coverPlayerStyle` 四分支；沉浸式在 `PlayerView.swift:463` 起 |
| 背景 | `CoverBlurBackground.swift`：封面缩 480 → CI 高斯模糊 → UIImageView；沉浸式再叠 `scaleEffect(1.35)+blur(18)+opacity(0.78)` 与五段黑渐变 |
| 封面 | `ImmersiveCoverArt`，宽度=屏宽、高度=46% 屏高，**径向羽化 mask**（`immersiveFeatherMask`）让四周渐隐 |
| 顶栏 | `headerBar`：chevron + 状态/专辑 + 红心，三个圆形 `playerButtonSurface` |
| 歌词 | `LyricsSection`（3817 行起）：二分查找当前行 + `ScrollViewReader` 滚动 + 逐字/大字/经典三种模式 |
| 进度 | `SeekBar`（3540 行起）四种样式，沉浸式传 style=用户设置 |
| 控制 | `immersiveControlBar`：模式 / 上一首 / 66pt 播放 / 下一首 / 队列 |
| 数据 | 歌名歌手来自 `Song`；进度来自 `PlaybackClock`；seek 走 `PlayerManager.seek(to:)`；歌词由 `loadLyrics()` 按平台拉取 |

截图暴露的根因：① 封面用径向 mask 直接压在模糊封面上，四周出现一圈亮边（"光晕"），中间又发灰 → 脏；② 背景只用 `CoverBlurBackground` 的上下平均色渐变，没有主色参与，封面色与背景色脱节；③ 顶栏与内容之间靠 5 段黑渐变硬压，出现色块分界；④ 所有按钮都是 `Circle().fill(.white.opacity(0.1~0.16))`，没有真实材质；⑤ 歌词预览用 `● / ·` 符号 + 12pt 正文，且把 LRC 里的「作词 : xxx」当成歌词一起排；⑥ 播放键只是灰色圆饼，控制行 5 个按钮视觉重量接近，没有焦点。

#### 二、新结构

新增 3 个文件（不动播放引擎）：

| 文件 | 职责 |
|---|---|
| `BeansGlass.swift` | Liquid Glass 材质系统：`BeansGlassThickness`（thin/regular/floating）+ `LiquidGlassSurface`（iOS 26 走 `glassEffect`，iOS 17~25 走 `ultraThinMaterial` + 顶部镜面 + 0.7pt 双层描边）+ `LiquidGlassButtonStyle` + `GlassCircleButton` |
| `ImmersiveArtwork.swift` | `ImmersivePalette`（accent/glow/base 三档，由封面主色 HSL 派生）、`ImmersiveArtworkCache`（300px 缩略 + CI 高斯模糊 + NSCache，切歌只算一次）、`ImmersiveBackdrop`（底色 + 模糊封面 + 顶部色雾 + 上下压暗，新旧两层 `fade` 交叉淡入）、`ImmersiveArtwork`（主封面，缓存命中直显 + 新图淡入） |
| `ImmersivePlayerView.swift` | 全新沉浸式播放页 + `ImmersiveScrubber` + `LyricCreditFilter` |

`PlayerView` 的改动只有 3 处：`.immersive` 分支换成 `ImmersivePlayerView(...)` 并把 9 个动作回调出去；`showLyricStagePicker` 的 sheet 提到 body 顶层（子视图也要用）；`loadLyrics` 的 `apply` 里加 `LyricCreditFilter.sanitize`。旧沉浸式私有函数保留但不再被调用（便于回滚，不影响编译）。

#### 三、设计参数（可直接对照代码）

- 封面：`min(屏宽-56, 屏高-预留, 380)`，圆角 20，`black 0.42 / r28 / y16` 单层软阴影 + 0.7pt 内描边；**不再用径向羽化**，改为背景层向封面自然过渡。
- 六层：顶栏 44 / 间距 22 / 封面 / 间距 26 / 信息（26pt bold 歌名 + 13.5 歌手 + 36pt 红心）/ 18 / 歌词预览 84（三行：16.5 当前 + 14.5 两侧，透明度 0.92 / 0.26）/ 弹性留白 / 控制区 134。
- 控制：模式 42 玻璃圆钮 · 上一首 58×72 纯图标 · **播放 74 悬浮玻璃** · 下一首 · 队列 42；间距用 Spacer 均分，最大宽 396。
- 进度：3pt 轨 / 9pt 手柄，拖动时变 4pt / 13pt，时间跟随手指，松手才 `seek`。
- 歌词页：44 小封面 + 歌名歌手 + 舞台 / 红心；`LyricsSection` 传白色 accent、glow 0、blurStart 3 / 0.6，字号行距沿用用户设置。
- 动效：封面↔歌词 `spring(0.44, 0.92)` 横向推入；切歌 0.17s 滑出 + 0.42s 弹回；背景 0.62s 交叉淡入；按压 `spring(0.26, 0.80)` 缩放。
- 安全区：`GeometryReader + .ignoresSafeArea()` 后手动加 `insets.top`，避免不同呈现容器下二次内缩。

#### 四、验证清单（真机）

1. 顶部状态栏、顶栏、背景是否同一层渐变，没有色块分界
2. 封面四周是否还有亮边/灰雾；切歌时背景是否平滑换色、不闪黑
3. 播放键是否明显高于其它按钮；模式按钮切换后图标 + 强调色是否同时变
4. 拖动进度时手柄放大、时间跟随，松手是否跳到目标位置
5. 歌词页是否只显示纯歌词（作词/作曲已剔除），当前行是否明显突出
6. 封面右滑进歌词、歌词右滑回封面、上下滑切歌、左滑收起是否都正常
7. 歌词舞台开启后是否全屏、轻点能否呼出控制层
8. iOS 17/18 与 iOS 26 的玻璃质感是否一致（26 为系统原生）

### 0.7.1 修复轮（2026-11-25，版本 **1.20.0 (93)** 重发，提交 `5f328958`）

用户真机截图反馈「布局完全乱了」，并抱怨「每次打包能不能只打包一个」。

**布局根因**：`ImmersivePlayerView.body` 的 `GeometryReader` 外面套了 `.ignoresSafeArea()`，`geo.safeAreaInsets` 因此归零 → 歌词页 header 顶进状态栏（系统时间压住歌手名、收藏按钮压住电池），封面页整体上移。经典 / Apple Music / 黑胶三套方案都只在**背景**上 ignore 安全区，内容留在安全区里，所以它们没这个问题。修法：背景单独 `.ignoresSafeArea()`，内容回到安全区；另加 `extraTop / extraBottom` 兜底（仅当某个容器仍上报非零 inset 时补，正常情况为 0，不会二次内缩）。

**同一轮顺手修的四处**：

| # | 问题 | 处理 |
|---|---|---|
| 1 | 亮封面（如 PLANET 白底图）顶部发灰，白色图标与文字糊在背景里 | `ImmersivePalette.isLight`（HSL 亮度 > 0.60）：模糊层 0.64 → 0.44、`brightness(-0.05)`、顶部压暗 0.42 → 0.58 |
| 2 | 歌词首行把「歌名 - 歌手」当歌词（截图里的 `PLANET - ラムジ`） | `LyricCreditFilter.dropLeadingMetadata`：只看前两行，要求同时含歌名与歌手才丢，避免误删正文 |
| 3 | 当前行 34pt 折成两行，把整页撑乱 | 沉浸页歌词字号上限 24 → 21（当前行约 29.8pt） |
| 4 | 歌词舞台单独 ignore 安全区，chrome 贴边 | 舞台回到安全区（WebView 透明，看不出接缝），chrome 顶部 / 底部改固定 8 / 18 |

**流水线**：`ios-ipa.yml` 增加 `paths-ignore: beans-ios/**, beans-project.yml, HANDOFF.md, **.md`；`beans-ipa.yml` 增加 `concurrency: beans-ipa`。改 beans 代码只会出一条流水线。

**Runner 的坑（重要）**：这台账号的 hosted macOS runner 并发很有限。一次 push 同时触发 `Build iOS IPA`（macos-15）与 `Build Beans SwiftUI IPA`（macos-26）时，后拿到排队的那个会在**排队 15 分钟后被 GitHub 直接取消**（run `45452620502`、`45457500761` 都是因此变红，日志里 `runner_name` 为空、`steps` 为空）。要出包时先等主工程跑完，再 `workflow_dispatch` 单独触发 Beans，就能稳定成功（run `45456591494` 即此路径）。

### 0.6.0 本轮（2026-11-22，版本 **1.19.2 (92)**，提交 `e5a15f9d`）

用户 6 条反馈 + 5 图（1.19.1 真机验证后的补充）。核心是把酷我从「只能搜索/播放」补成**有首页内容**的平台，并解决登录后 0 歌单、歌词右滑直接退出、VIP 标签误导三个体验问题。

| # | 反馈 | 处理（改动文件） |
|---|---|---|
| 1 | 首页缺酷我的歌单和排行榜（LX Music 已实现） | 照 LX Music 的 kw 源补三条公开接口：榜单 `kbangserver.kuwo.cn/ksong.s`（bangId 16/17/93/145/158/151/152/155）、推荐歌单 `wapi.kuwo.cn/api/pc/classify/playlist/getRcmPlayList`；`KuwoMusicAPI` 新增 `charts(limit:)`/`chartSongs(bangID:)`/`recommendPlaylists(limit:)`，`Models` 加 `KuwoTopInfo`，`DiscoverCache.Snapshot` 加 `kuwoTopLists`，`DiscoverRoute` 加 `.kuwoTopList` + 新页面 `KuwoTopListDetailView`，`DiscoverView` 的 `visibleRankCount/hasRankData/allRankEntries/rankRowsContent/nativeCleanTopListsSection/fetchSnapshot(.kuwo/.all)` 全部补齐；`SearchProvider.supportsHomeFeed/supportsCharts/supportsPlaylistSquare` 对 `.kuwo` 打开；`DiscoverAllViews`（全部榜单 / 歌单广场）同步支持酷我 |
| 2 | 音乐库左上角去掉平台名、方形圆角图标不要；「全部歌单」标题跟随平台 | `LibraryView.swift`：标题行改为单个图标（品牌图 `scaledToFill` + `clipShape(Circle())`，不再显示文字与方形圆角）；新增 `playlistWallTitle`，`全部歌单` → `网易云歌单 / 酷我歌单 / 咪咕歌单…`，手动导入页为「导入歌单」 |
| 3 | 酷我登录后仍是 0 个歌单，报 `The request is illegal!` | 两个根因：① `KuwoMusicAPI.secret()` 少了 JS 末尾的 8 位随机十六进制（`for(d=d.toString(16);d.length<8;)d="0"+d; return h+=d`），已补；② 登录回调里先 `saveLogin` 再抓歌单，SwiftUI 立刻把 webCard 换成 loggedInCard，WebView 销毁导致抓取中断 —— 改为**先抓后写登录态**。抓取路径改为在 `/my/playlist` 页面内 `fetch('/api/www/user/playlist?...')`（浏览器的 Cookie/Referer/设备指纹都是真的，签名在页面里用同一套 `f(cookieValue,cookieName)` 算），结果写 `window.__kuwoPlaylistPayload` 后轮询读取，失败再退回 DOM 抓取；原生 `fetchMyPlaylists` 补 `csrf: kw_token` 头，错误文案改成可操作提示 |
| 4 | 尝试增加咪咕登录 | 新增 `MiguMusicLogin.swift`：`MiguMusicAuth`（Cookie/昵称/歌单持久化 + `.beansMiguLoginDidUpdate`）、`MiguLoginSheet`、`MiguLoginWebView`（加载 `music.migu.cn/v5/`，自动点 `div.login` 唤起 `passport.migu.cn` iframe 登录，轮询 `div.login` 消失 + Cookie 抓取），登录后进 `#/my` DOM 抓歌单；`MiguWebPlaylistLoader` 是无界面 WKWebView，用于冷启动时用已存 Cookie 刷新；`ProfileView` 加咪咕卡片与退出确认，`LibraryView` 加咪咕登录引导 + `loadMiguPlaylists` + 歌单墙 + 云同步源，`PlayerManager.hasMembership(.migu)` 改为读登录态，`WebLoginDataCleaner.clearMigu()` |
| 5 | 歌词页从左往右滑直接退出播放器，应先回封面页 | 根因不在歌词手势，而在 `BeansNowPlayingPresentation` 的左边缘 26pt `highPriorityGesture`（右滑退出），它抢在歌词页手势之前。`PlayerManager` 加 `lyricsPanelOpen`，`PlayerView` 在 `showLyrics` 的 onAppear/onChange 里同步；容器新增 `lyricsOpen` 入参，歌词页打开时 `.allowsHitTesting(false)` 让出边缘 → 第一次右滑回封面（`lyricsSwipeBackGesture`），第二次右滑才退出 |
| 6 | 不要每次播放都弹「未识别到对应会员」；红底白字 VIP 改成「会员=VIP / 音源=简称」 | `PlayerManager.thirdPartyVIPNotice` 直接返回 nil（不再弹 toast）；新增 `activeThirdPartySourceName`（`setupPlayer` 记录 `resolved.sourceTitle`）与 `playbackSourceBadge` / `playbackBadgeIsSource`；新增 `Components.PlaybackSourceBadge`（金色描边「VIP」/ 青色描边音源简称，如「聆澜」），替换 `MiniPlayerView`、`PlayerView`（5 处）、`ReferencePlaybackView` 的红底白字 VIP |

CI 第一轮（`3b00aaab`）报 1 个编译错误：`PlayerManager` 不是单例，`RootView` 里不能写 `PlayerManager.shared` —— 改为 `BeansNowPlayingPresentation(lyricsOpen:)` 由 `RootView` 传 `player.lyricsPanelOpen`。第二轮 `e5a15f9d` 构建通过，release `beans-latest` 已覆盖为 1.19.2 (92)，CI 日志确认「LyricStages 打包完成：68 个 HTML，14 个资源文件」。

新增文件：`MiguMusicLogin.swift`。

需要真机重点验证：
1. 首页切「酷我音乐」：排行榜 8 个榜、歌单 18 个是否都出；点「酷我热歌榜」能否播放全部
2. 音乐库左上角只剩圆形图标，切平台后标题变「网易云歌单 / 酷我歌单」
3. 酷我重新登录：能否读到真实歌单（若仍被风控，粘贴链接兜底是否可用）
4. 咪咕登录：passport iframe 能否收到验证码、登录后歌单是否同步
5. 歌词页第一次右滑回封面、第二次退出；播放页/迷你条标签是否显示「聆澜」而不是 VIP

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
