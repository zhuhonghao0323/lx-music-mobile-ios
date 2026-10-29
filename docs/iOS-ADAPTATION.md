# 洛雪音乐 iOS 适配说明

> 目标：在 iOS 上跑起完整播放链路，产出**未签名 IPA**，用于 TrollStore 巨魔侧载或自签安装。
> 不涉及：开发者证书、描述文件、推送、App Store 上架。

---

## 0. 一句话结论

核心链路（音源解析 → 在线播放 → 缓存 → 歌单/收藏 → 同步 → 自定义音源脚本 → 后台播放 → 锁屏控件）**全部保留**；
**桌面歌词**因 iOS 沙盒不允许跨应用绘制，被整体移除；
另有三处 Android 系统能力在 iOS 上天然不存在（装 APK、电池优化白名单、SAF 目录授权），已按「无此概念」降级处理。

改动全部落在 `ios/`、`src/` 的少量平台适配文件、构建脚本与 CI 中，**Android 侧行为零变更**。

### 已验证 / 未验证

| 项目 | 状态 | 说明 |
|---|---|---|
| TypeScript 类型检查 | ✅ 通过 | 本次改动涉及的文件 0 错误（项目原有 5 处历史错误仍在，均在未改动文件中） |
| ESLint | ✅ 通过 | 本次改动的 10 个文件全部通过项目既有规则 |
| iOS JS bundle 打包 | ✅ 通过 | `react-native bundle --platform ios` 成功产出 9.9MB bundle + 13 个资源 |
| Android JS bundle 打包 | ✅ 通过 | 交叉验证未被破坏 |
| 平台隔离正确性 | ✅ 通过 | iOS bundle 含 `LXDocumentPickerModule`/`LocalMediaMetadata`，**不含** `AndroidScoped`/`openDocumentTree`；Android bundle 反之 |
| **Xcode 编译 / pod install** | ❌ **未验证** | 本次工作在 Windows 上完成，`.m` 文件未经 clang 与 CocoaPods 校验。首次在 macOS 上构建大概率需要修 1~3 处编译问题 |
| 真机运行 | ❌ 未验证 | 需在 iOS 设备上按 §8 的清单逐项验证 |

---

## 1. 先看这里：项目原本的 iOS 状态

仓库里虽然有 `ios/` 目录，但它只是 `react-native init` 生成的**空骨架**，从未跑通过：

| 检查项 | 原始状态 | 说明 |
|---|---|---|
| `ios/Podfile` | RN 官方模板原文 | 没有任何自定义 pod，未引入 RNN/RNTP 所需配置 |
| `ios/LxMusicMobile/Info.plist` | RN 模板 | 没有 `UIBackgroundModes`，后台播放必失效 |
| 自研原生模块 | 只有 `android/.../java/` 下的 Java 实现 | iOS 侧完全缺失 |
| `react-native-file-system` | 只有 `android/` | 带 podspec 但没有 ios 目录，`pod install` 会失败 |
| `react-native-local-media-metadata` | 只有 `android/` | 同上 |
| 缓存 API | `TrackPlayer.isCached/getCacheSize/clearCache` | 这三个方法 **iOS 原生桥里根本没导出** |
| `TrackPlayer.updateNowPlayingTitles` | 仅 Android | iOS 调用会抛 `not a function` |

所以本次不是「修修补补」，而是把 iOS 侧从零补完。

---

## 2. 四个关键架构决策

### 2.1 用本地 CocoaPods pod 承载所有 iOS 原生代码

**做法**：新建 `ios/LXMobileNative/`，作为一个 `:path` 引入的本地 pod，装下全部新增的 `.m` 文件与资源。

**为什么**：往 Xcode 工程里加源文件必须手工维护 `project.pbxproj` 里 `PBXBuildFile` / `PBXFileReference` / `PBXGroup` / `PBXSourcesBuildPhase` 四组 UUID，写错一个就整个工程打不开，而且 diff 完全不可读。用 pod 之后，`project.pbxproj` 只需要改 build settings（bundle id、签名、版本），新增/删除文件都不碰工程文件。

### 2.2 用系统内置 JavaScriptCore 替代 Android 的 QuickJS

**背景**：`android/.../userApi/QuickJS.java` 用 `com.whl.quickjs` 在原生侧跑自定义音源脚本。iOS 上没有任何现成实现。

**做法**：`LXUserApiModule.m` 用 `JavaScriptCore.framework`（系统自带）重建同一个沙箱：

- 接口契约 1:1 对齐：`loadScript` / `sendAction` / `destroy` / `api-action` 事件
- 注入的 7 个原生函数与 `QuickJS.java` 逐个对应：
  `__lx_native_call__`、`utils_str2b64`、`utils_b642buf`、`utils_str2md5`、
  `utils_aes_encrypt`、`utils_rsa_encrypt`、`set_timeout`
- **`user-api-preload.js` 原样复用**（podspec 直接引用 `android/app/src/main/assets/script/` 下那一份），
  保证两端脚本行为完全一致，且以后上游更新 preload 时 iOS 自动同步

**为什么不打包 QuickJS**：quickjs-ng 需要引入 C 源码、处理 iOS 的 bitcode/arm64 交叉编译，在 CI 上是额外的失败源；而 JSC 是系统库，零编译成本，ES 语法支持比 QuickJS 更好，跑音源脚本绰绰有余。

**线程模型**：Android 为脚本单开 `JavaScriptThread`；iOS 用一条串行 `dispatch_queue`，所有 `JSContext` 操作都在这条队列上（JSC 不允许跨线程并发访问）。定时器用「generation 计数器」失效，切歌/换脚本时旧定时器自动丢弃。

### 2.3 歌曲缓存：自建文件缓存层

**问题**：`react-native-track-player` 的缓存 API 在 iOS 上**不存在**。已核对 fork 的
`ios/RNTrackPlayer/RNTrackPlayerBridge.m`，导出的方法里没有 `isCached` / `getCacheSize` / `clearCache`。
而 JS 侧 `player/utils.ts`、`PreloadNextMusic`、`ResourceCache` 设置页都在直接调它们 —— 不处理的话，
一进「资源缓存」设置页就崩。

**做法**：新增 `src/plugins/player/cache.ts`，做平台分派：

| 能力 | Android | iOS |
|---|---|---|
| 判断是否已缓存 | `TrackPlayer.isCached` | 查 `Documents/TrackPlayer/<md5(url)>.<ext>` 是否存在 |
| 缓存大小 | `TrackPlayer.getCacheSize` | 遍历目录累加 |
| 清空缓存 | `TrackPlayer.clearCache` | 删除目录内容 |
| 播放时的 URL | 原样交给播放器 | 命中则用 `file://`，未命中则原 URL + 后台预取 |

**行为差异（重要）**：
Android 是「边播边缓存」，播到哪缓存到哪；iOS 是「先流播、同时后台整首下载」。
所以 iOS 上**第一次播放某首歌时不会产生缓存**，要等后台下载完成，第二次播放才走本地文件。
这是没有原生缓存支持下的最优折中——首播速度与 Android 一致，不会为了缓存而延迟起播。

容量上限沿用设置项 `player.cacheSize`，超限后按文件修改时间从旧到新淘汰。

### 2.4 文件系统：用 `react-native-fs` 重写，不动 Android

**问题**：`react-native-file-system` 只有 Android 实现。它被 `src/utils/fs.ts` 直接 import，
并且 `NativeModules.FileSystemModule` 缺失时上游代码用 `Proxy` 抛错 —— 意味着 iOS 上一 import 就炸。

**做法**：
1. `react-native.config.js` 里对 iOS 关闭这两个包的 autolinking（否则 `pod install` 直接失败）
2. 新增 `src/utils/fs.ios.ts`，用 `react-native-fs`（RNFS，两端都支持）重写**同一套导出**
3. Metro 按平台后缀自动优先解析 `.ios.ts`，`fs.ts` 保持原样 → **Android 完全不受影响**

接口契约严格对齐原包（`FileType` 结构、`Dirs`、各方法返回类型），包括几个容易踩的细节：

- `gzipString` 必须返回 `base64(gzip(bytes))` —— 同步功能靠这个格式与桌面端互通，格式错一个字节就同步失败
- `hash` 的 `sha224` / `sha384` iOS 的 RNFS 不支持，显式抛错而不是静默返回错值
- `readDir` 要补 `mimeType`（本地音乐扫描靠 `audio/*` 过滤）

---

## 3. 改动文件清单

### 3.1 新增 · iOS 原生代码（`ios/LXMobileNative/`）

| 文件 | 作用 | 为什么需要 |
|---|---|---|
| `LXMobileNative.podspec` | 本地 pod 描述 | 让 CocoaPods 接管原生代码与资源，避免手改 pbxproj；`resources` 直接引用 Android 侧的 `user-api-preload.js` 和 `icomoon.ttf`，保证单一数据源 |
| `Classes/LXUserApiModule.m` | 自定义音源脚本沙箱 | Android QuickJS 的 iOS 等价实现，见 §2.2。**这是整个适配最关键的文件** |
| `Classes/LXCryptoUtil.h/.m` | AES / RSA / MD5 / SHA1 + 最小 DER 编解码 | Android `AES.java` / `RSA.java` 的 iOS 实现。DER 编解码是必需的：Android 用 X.509(公钥)/PKCS#8(私钥)，而 iOS 的 `SecKeyCreateWithData` 只认裸 PKCS#1，必须自己拆装 |
| `Classes/LXCryptoModule.m` | `CryptoModule` 桥接 | 对齐 `CryptoModule.java` 的 9 个方法，含 4 个 `RCT_EXPORT_BLOCKING_SYNCHRONOUS_METHOD`（同步模块握手是同步调用的） |
| `Classes/LXUtilsModule.m` | `UtilsModule` 桥接 | 对齐 `UtilsModule.java`：退出、屏幕常亮、设备名、语言、窗口尺寸、分享、通知权限、Wi-Fi IP、`screen-state`/`screen-size-changed` 事件 |
| `Classes/LXCacheModule.m` | `CacheModule` 桥接 | 统计/清理 `NSCachesDirectory`，**刻意不碰** `Documents/TrackPlayer`，否则会误删用户的音乐缓存 |
| `Classes/LXMediaMetadataModule.m` | 本地音乐元数据 | 替代只有 Android 的 `react-native-local-media-metadata`，用 `AVURLAsset` 读标题/歌手/专辑/封面/时长 |
| `Classes/LXDocumentPickerModule.m` | 文件选择器 | iOS 没有 SAF，用 `UIDocumentPickerViewController` 实现 `selectFile`，供导入音源脚本/歌单备份 |

### 3.2 修改 · iOS 工程配置

| 文件 | 改动 | 原因 |
|---|---|---|
| `ios/Podfile` | platform 固定 14.0；关闭 Flipper；引入 `LXMobileNative`；`post_install` 统一关签名与 bitcode | ① TrollStore 覆盖 iOS 14+；② Flipper 只在 DEBUG 用，CI 上极易编译失败；③ 未签名构建必须整体关闭签名要求 |
| `ios/LxMusicMobile/Info.plist` | 加 `UIBackgroundModes=audio`、ATS 全开、`UIAppFonts`、文件共享、`CFBundleDocumentTypes`、`NSLocalNetworkUsageDescription`、`CFBundleURLTypes`、`ITSAppUsesNonExemptEncryption`；删 `armv7` | 逐项见 §3.5 |
| `ios/LxMusicMobile/AppDelegate.mm` | 启动时配置 `AVAudioSession`；补 `openURL` / `continueUserActivity` 转发给 `RCTLinkingManager` | ① 兜底保证后台音频会话在 `setupPlayer` 之前就是 playback；② 深链 `lxmusic://` 在 iOS 上需要显式转发 |
| `ios/LxMusicMobile.xcodeproj/project.pbxproj` | bundle id → `cn.toside.music.mobile`；版本 → 1.9.1(78)；`CODE_SIGNING_ALLOWED=NO`；deployment target → 14.0 | 模板里的 `org.reactjs.native.example.*` 不能用于安装；签名设置必须清空才能产出未签名包 |

### 3.3 新增 · JS 层

| 文件 | 作用 |
|---|---|
| `src/utils/fs.ios.ts` | `fs.ts` 的 iOS 实现（RNFS），导出符号与类型完全一致 |
| `src/utils/localMediaMetadata.ios.ts` | `localMediaMetadata.ts` 的 iOS 实现，转调 `LocalMediaMetadata` 原生模块 |
| `src/utils/nativeModules/lyricDesktop.ios.ts` | 桌面歌词的 iOS 空实现（所有导出 no-op），保证调用点无需改 |
| `src/plugins/player/cache.ts` | 播放缓存的平台分派层 + iOS 文件缓存实现 |
| `src/types/pako.d.ts` | pako 的类型声明（pako 2.x 无内置类型，上游也没装 `@types/pako`，而 iOS 的 gzip 实现需要它） |
| `react-native.config.js` | 关闭 `react-native-file-system` / `react-native-local-media-metadata` 的 iOS autolinking |

### 3.4 修改 · JS 层

| 文件 | 改动 | 原因 |
|---|---|---|
| `src/plugins/player/utils.ts` | ① `isCached/getCacheSize/clearCache` 改为从 `./cache` re-export；② `updateNowPlayingTitles` 加 iOS 分支；③ `updateOptions` 在 iOS 过滤 `Capability.Stop` | ① iOS 无原生缓存 API；② iOS 桥没导出 `updateNowPlayingTitles`，改用 `updateNowPlayingMetadata`（该方法是**按键合并**写入 `MPNowPlayingInfoCenter`，只传 title/artist 不会清掉封面和时长）；③ 锁屏「停止」按钮映射到 `RemoteStop`，而该处理是「退出应用」，iOS 上太容易误触 |
| `src/plugins/player/playList.ts` | `handlePlayMusic` 里先把 URL 过一遍 `resolvePlayableUrl` | 让已缓存的歌用 `file://` 播放。Android 上该函数是直通，行为不变 |
| `src/plugins/player/index.ts` | 初始化时调用 `initCacheDir()`；给 `setupPlayer` 参数加注释 | iOS 需要提前建好缓存目录；已核对 iOS 的 `setupPlayer` 只读 `waitForBuffer`/`autoUpdateMetadata`，多余键被忽略，无需按平台拆分 |
| `src/plugins/player/service.ts` | 新增 `RemoteDuck` 处理（仅 iOS 生效） | **音频中断处理的关键**：RNTP 的 iOS 端在来电/闹钟打断时只派发 `remote-duck` 事件，**不会自动恢复播放**。不补这段，接完电话音乐就停住不动 |
| `src/utils/tools.ts` | 新增 `isIOS` 常量 | 供设置页等处使用 |
| `src/screens/Home/Views/Setting/Main.tsx` | `SETTING_SCREENS` 在 iOS 上过滤掉 `lyric_desktop` | 桌面歌词在 iOS 不存在，留着入口只会让用户以为坏了 |

### 3.5 `Info.plist` 逐项说明

| 键 | 值 | 不加会怎样 |
|---|---|---|
| `UIBackgroundModes` | `audio` | 一进后台 JS 线程被挂起，播放中断、锁屏控件消失 |
| `NSAppTransportSecurity.NSAllowsArbitraryLoads` | `true` | 音源返回的播放地址/封面大量是明文 http，会被 ATS 拦掉。**这条上架必被拒，本项目不上架** |
| `UIAppFonts` | `icomoon.ttf` | 全部图标变成方块（字体 PostScript 名已确认是 `icomoon`，与 `selection.json` 一致） |
| `UIFileSharingEnabled` + `LSSupportsOpeningDocumentsInPlace` | `true` | 「文件」App 里看不到洛雪音乐目录，无法拖入音源脚本/本地音乐 |
| `CFBundleDocumentTypes` + `UTImportedTypeDeclarations` | `.js`/`.json`/`.lxmc` | 从「文件」App 用洛雪音乐打开脚本/歌单备份时，App 不出现在候选列表 |
| `NSLocalNetworkUsageDescription` | 说明文案 | iOS 14+ 访问局域网地址会静默失败，同步连不上桌面端 |
| `CFBundleURLTypes` | `lxmusic` | 深链失效（Android 侧 `android:scheme="lxmusic"` 的对应项） |
| `ITSAppUsesNonExemptEncryption` | `false` | 每次安装弹出口合规提示（侧载场景只是噪音） |
| `UIRequiredDeviceCapabilities` | `arm64`（删掉 `armv7`） | 部分安装器判定不支持当前设备 |

### 3.6 新增 · 构建

| 文件 | 作用 |
|---|---|
| `scripts/build-ios-unsigned.sh` | Mac 本地一键编译未签名 IPA，含产物校验（`main.jsbundle`、`user-api-preload.js`、`UIBackgroundModes`、字体） |
| `.github/workflows/ios-unsigned-build.yml` | GitHub Actions 自动编译未签名 IPA 并上传 artifact |
| `.gitattributes` | 锁定 `.sh` / `.podspec` / `.pbxproj` / `.plist` 为 LF 行尾。不加的话，Windows 上 checkout 出来的 `.sh` 带 CRLF，在 macOS 上会报 `bad interpreter: ^M` |

---

## 4. 功能对照表

| 功能 | iOS 状态 | 说明 |
|---|---|---|
| 音源解析（内置源） | ✅ 完整 | 纯 JS，与平台无关 |
| **自定义音源脚本** | ✅ 完整 | JavaScriptCore 沙箱，preload 原样复用 |
| 在线播放 | ✅ 完整 | RNTP（fork 自带 iOS 实现，SwiftAudio） |
| 歌曲缓存 | ⚠️ 等价替代 | 无原生缓存，改为「流播 + 后台整首下载」，二次播放走本地 |
| 歌单 / 收藏 | ✅ 完整 | 纯 JS + AsyncStorage |
| 同步（与桌面端） | ✅ 完整 | RSA/AES 已按 Java 语义重写，需实测握手 |
| **后台播放** | ✅ 完整 | `UIBackgroundModes=audio` + AVAudioSession |
| **锁屏播放控件** | ✅ 完整 | RNTP 的 `MPRemoteCommandCenter` + `MPNowPlayingInfoCenter` |
| **音频中断处理** | ✅ 已补 | 新增 `RemoteDuck` 恢复逻辑（见 §3.4） |
| 锁屏显示歌词 | ✅ 降级保留 | 用 `updateNowPlayingMetadata` 更新标题行；完整歌词受 iOS 系统限制 |
| 本地音乐扫描 | ⚠️ 部分 | 能扫能播，元数据靠 AVFoundation（写入标签不支持） |
| 导入音源脚本/歌单 | ✅ 完整 | `UIDocumentPickerViewController` + 文件共享 |
| 深链 `lxmusic://` | ✅ 完整 | `CFBundleURLTypes` + `RCTLinkingManager` |
| **桌面歌词** | ❌ 移除 | iOS 沙盒不允许跨应用悬浮窗 |
| 检查更新 / 装 APK | ❌ 无效 | iOS 无 APK 安装能力 |

---

## 5. iOS 上必然缺失的功能

1. **桌面歌词（悬浮窗）**
   根本原因：iOS 没有 `SYSTEM_ALERT_WINDOW` 这类跨应用绘制权限，任何 App 都不能在其他 App 之上画窗口。
   处理：`LyricModule` 整套 no-op，设置入口在 iOS 隐藏。**这条无解，不是实现问题。**

2. **安装 APK / 应用内更新**
   `UtilsModule.installApk` 在 iOS 返回 `NO`。iOS 不允许 App 自行安装其他 App。

3. **电池优化白名单**
   iOS 没有这个概念，`isIgnoringBatteryOptimization` 恒返回 `YES`，避免设置页反复弹引导。

4. **SAF 目录持久授权**
   Android 可以「选择一个文件夹并长期读写」；iOS 没有等价物（安全作用域书签只能作用于用户每次确认的目录，体验差且易失效）。
   处理：`selectManagedFolder` 退化为固定的 `Documents/Music`，用户通过「文件」App 往里放音乐。

5. **改写音频标签**
   iOS 没有公开 API 能原地修改音频文件的 ID3/FLAC 标签（`AVAssetExportSession` 只能导出新文件）。
   `writeMetadata` / `writePic` / `writeLyric` 降级为 no-op —— 「编辑歌曲信息」保存后不会真正写入文件。

6. **读取内嵌歌词（ID3 USLT 等）**
   iOS 没有稳定的通用读取路径，`readLyric` 只读同名 `.lrc`，读不到就回退在线歌词。

---

## 6. 兼容风险点

按「踩到的概率 × 影响」排序：

### 6.1 高风险

| 风险 | 影响 | 应对 |
|---|---|---|
| **Xcode 编译未验证** | 本次改动在 Windows 上完成，`.m` 文件未经 `clang` 与 CocoaPods 校验；JS 层已用 Metro 双向打包验证过 | 首次 `pod install` + `xcodebuild` 大概率需要修 1~3 处编译问题（多为头文件、类型转换、API 可用性）。CI 的 `build-log` artifact 会保留完整日志，报错定位很快 |
| **RNTP fork 的 iOS 实现较老** | 该 fork 基于 SwiftAudio，iOS 端长期无人维护；偶发锁屏信息不同步、切歌卡顿 | 若出现，优先在 JS 层加重试/去抖；不建议改 Swift 源码 |
| **同步握手失败** | RSA/AES 语义若有一处不匹配，同步会卡在鉴权 | 已逐行对齐 Java 语义（含 `AES` 默认 = ECB/PKCS5、`NoPadding` = Raw RSA）；**必须实测一次与桌面端的完整同步** |
| **`RSA/ECB/NoPadding` 的输入长度** | iOS 的 `kSecKeyAlgorithmRSAEncryptionRaw` 要求输入正好等于模长（2048 位 = 256 字节），Java 同样如此；但若某音源脚本依赖 Java 的宽松行为，会失败 | 属于「与 Android 一致」的行为，不是 iOS 独有缺陷 |

### 6.2 中风险

| 风险 | 影响 | 应对 |
|---|---|---|
| **iOS 缓存策略差异** | 首播不产生缓存；若用户在下载完成前退出，该歌下次仍要重新下载 | 已按 §2.3 设计；如需更接近 Android，可在设置里加「仅 Wi-Fi 预取」开关 |
| **后台被系统回收** | iOS 长时间后台 + 内存压力下仍可能杀进程（Android 有前台服务常驻） | 音频后台模式已覆盖绝大多数场景；被杀的极端情况无法完全避免 |
| **`exitApp` 表现为闪退** | 调用 `exit(0)`，系统日志会记一次异常终止 | 已移除锁屏 Stop 能力，降低误触；TrollStore 场景可接受 |
| **设备名在 iOS 16+ 返回 `iPhone`** | 同步列表里多台设备可能同名 | 读取 `UIDevice.name` 需要 entitlement；已回退到 `model`，属已知限制 |
| **Xcode 版本** | RN 0.73 在 Xcode 16 上编译 `RCT-Folly`/Hermes 易出问题 | 构建脚本与 CI 均优先选 Xcode 15.4，找不到才回退 |
| **ATS 全开的安全影响** | 允许任意明文 http | 侧载场景的既定取舍；若将来要上架必须改为按域名白名单 |

### 6.3 低风险

- **JSC 与 QuickJS 的语法差异**：JSC 支持更完整的 ES 标准，极少数依赖 QuickJS 特有行为的脚本可能异常（实际音源脚本都是标准语法，风险很低）
- **`b642buf` 的有符号字节**：已按 Java 的 `(int) byte` 语义返回 `-128..127`，若写成无符号会导致所有二进制解密结果错位（已处理，此处仅作提醒）
- **图标字体**：`icomoon.ttf` 的 PostScript 名已确认为 `icomoon`，与 `selection.json` 一致；若替换字体文件需重新核对
- **首次启动权限弹窗**：本地网络、通知权限会在首次用到时弹出，属正常行为

---

## 7. 构建与安装

> **在 Windows 上开发？** Windows 无法本地编译 iOS，完整操作步骤见
> [BUILD-ON-WINDOWS.md](./BUILD-ON-WINDOWS.md)（推 GitHub → Actions 出包 → 下载 IPA）。

### 7.1 Mac 本地编译

```bash
# 前置：macOS + Xcode 15.4+、Node >= 18、CocoaPods >= 1.13
npm install
./scripts/build-ios-unsigned.sh
# 产物：build/artifacts/LxMusicMobile-unsigned.ipa
```

脚本会自动：`pod install` → `xcodebuild archive`（`CODE_SIGNING_ALLOWED=NO`）→ 校验关键产物 → 打包 `Payload/` 成 zip 并改名 `.ipa`。

### 7.2 GitHub Actions

`.github/workflows/ios-unsigned-build.yml`，触发方式：

- 手动 `workflow_dispatch`（可指定 ref）
- push tag `v*`
- 修改 `ios/**` 或 `src/**` 的 PR

产物在 Actions 页面的 `LxMusicMobile-unsigned-ipa` artifact 里，保留 30 天。

### 7.3 安装

| 方式 | 说明 |
|---|---|
| **TrollStore 巨魔** | 直接把 IPA 传到设备，用 TrollStore 打开安装。要求设备在 TrollStore 支持的 iOS 版本范围内 |
| **自签** | Sideloadly / AltStore / i4Tools 等工具，用自己的 Apple ID 重签。免费证书 7 天有效，付费开发者证书 1 年 |

两种方式都**不需要**本仓库做任何签名配置。

---

## 8. 装好之后建议这样验证

按依赖顺序测，出问题能快速定位到哪一层：

1. **启动 + 图标**：界面图标不是方块 → 字体注册成功
2. **内置音源播放**：随便搜一首能播 → 网络层 + RNTP 正常
3. **锁屏控件**：锁屏后能看到封面/歌名，能暂停/切歌 → `UIBackgroundModes` + RNTP 远程命令正常
4. **后台播放**：锁屏 5 分钟后仍在播 → 音频会话正常
5. **音频中断**：播歌时打一通电话，挂断后应自动续播 → `RemoteDuck` 逻辑生效
6. **自定义音源脚本**：导入一个 `.js` 音源并切换 → JavaScriptCore 沙箱正常
7. **缓存**：播一首完整的歌，退出重进再播同一首，观察是否秒起播（第二次应走本地）
8. **同步**：与桌面端配对 → RSA/AES 语义正确
9. **歌单/收藏/备份**：增删改查 + 导出 `.lxmc`

任一步失败，先看 Xcode 控制台日志：iOS 原生模块的问题会直接打印 `[LXMusic]` 前缀或 `Call script error:` 前缀。

---

## 9. 附：Android 侧为什么不受影响

本次所有平台差异都通过以下三种方式隔离，没有在共享代码里堆 `Platform.OS` 判断：

1. **平台后缀文件**：`fs.ios.ts` / `localMediaMetadata.ios.ts` / `lyricDesktop.ios.ts`
   → Metro 只在 iOS 打包时选中，Android 仍用原文件
2. **运行时平台分派集中在 3 个函数**：`cache.ts` 的三个导出、`updateNowPlayingTitles`、`updateOptions`
   → 非 iOS 分支走的是原始代码路径
3. **iOS 专属代码全部在新文件里**：`ios/LXMobileNative/`、`src/plugins/player/cache.ts`

`android/` 目录**一个字节都没改**。
