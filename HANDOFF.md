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

### 0.3 当前状态（2026-11-20 23:5x，版本 **1.12.0 (82)**）

1.11.1 之后这一轮按用户 12 条反馈改：

| # | 反馈 | 处理 |
|---|---|---|
| 1 | 主页「全部」连点闪退 | `DiscoverView.openRoute` 加连点保护（同一路由 0.8s 内只入栈一次）+ 推迟到下一 runloop 入栈，避免视图更新中改导航栈 |
| 2 | 主页波点无歌单 | 根因：推荐歌单接口是分组结构 `data.lists[].playLists[]`，旧解析把分组当歌单、全被丢弃。`BodianMusicAPI.playlists(from:)` 已加分组分支 |
| 3 | 播放手势 | 统一为：封面左滑返回、右滑歌词、上滑下一曲、下滑上一曲；左/右滑切歌全部删除（经典 `handleSwipeEnd`、AM `coverSwipeGesture`、黑胶 `VinylTurntableView`） |
| 4 | 切歌动画 | 新增 `switchSongAnimated`（PlayerView）+ `coverSwitchOffset`（AM）：内容先滑出、换歌后从另一侧滑回 |
| 5 | 搜索默认全部 | `SearchProvider.all` 进入搜索页平台选择器，默认 `beans.search.provider = 全部平台`，`SearchAggregator.songs` 并行聚合 + 轮转交错 + 歌名/歌手去重 |
| 6 | 音乐库到底部晃动 | 加 `beansScrollBounceBasedOnSize()`（iOS 16.4+ `scrollBounceBehavior(.basedOnSize)`）；仍未确认是否彻底 |
| 7 | 音乐库歌单墙 | 新增 `LibraryWall.swift`：3 列 × 2 行横向歌单墙 + 「全部」3 列网格；长按可更新/重命名/隐藏/删除，隐藏记在 `HiddenPlaylistStore` |
| 8 | 歌单歌曲汇总 | 同一文件：`LibraryAllSongsSection` + `LibraryAllSongsSheet`，按「歌名+歌手」去重，默认露 8 首，全部页可按语言（按字符脚本粗判）/歌手筛选 + 搜索 |
| 9 | 波点热搜空白 | `BodianMusicAPI.hotWords()` 走酷我热词服务 `hotword.kuwo.cn/hotword.s`，失败回退内置词表 |
| 10 | 主页删我的歌单 | `personalizedSection` 移除 `myPlaylistsSection` |
| 11 | 图标/名称 | `CFBundleDisplayName` → `Z Music`；AppIcon 换成 LX Music 官方图标（仓库里没有「猫头」素材，待用户提供后替换） |
| 12 | 品牌词 | 可见文案 `Beans Music` → `Z Music`，单独 `Beans` → `Zhu`；**目录名（BeansData/BeansLogs…）未动，避免丢数据** |

注意：`LibraryView` 里旧的 `playlistsSection / qqSection / kugouSection / bodianSection` 已不再被渲染（保留代码，咪咕仍用 `miguSection`），后续可删。

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
