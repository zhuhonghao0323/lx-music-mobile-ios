# 在 Windows 11 上打 iOS 包（未签名 IPA）

## 先明确一件事

**Windows 本地打不了 iOS 包。** 这不是配置问题，是硬限制：

- Xcode 只有 macOS 版本，苹果没有发布过 Windows 版
- iOS 的编译链路（clang + iOS SDK + 代码签名 + IPA 打包）全部依赖 macOS 工具链
- 没有官方或可靠的第三方交叉编译方案

所以在 Windows 上只有一条纯软件路径：**把代码推到 GitHub，用 GitHub 提供的 macOS 机器编译**（Actions）。

---

## 方案一：GitHub Actions（推荐，免费）

整个流程你在 Windows 上就能完成，不需要碰 Mac。

### 步骤 1：在 GitHub 建一个空仓库

1. 打开 https://github.com/new
2. Repository name 填 `lx-music-mobile-ios`（名字随意）
3. **Private / Public 的选择很关键**，见下方「额度说明」
4. **不要**勾选 "Add a README file"、"Add .gitignore"、"Choose a license"——必须是完全空的仓库
5. 点 Create repository

### 步骤 2：把本地代码推上去

打开 PowerShell 或 Git Bash，逐条执行：

```bash
cd "C:\Users\zhuho\WorkBuddy AI\lxmusic\upstream"

# 原来的 origin 指向上游作者仓库，改个名字留作参考（不改也行）
git remote rename origin upstream

# 指向你自己的仓库，把 <你的用户名> 和 <仓库名> 换掉
git remote add origin https://github.com/<你的用户名>/lx-music-mobile-ios.git

# 分支改名成 main（GitHub 默认分支名）
git branch -M main

# 推送
git push -u origin main
```

推送时会弹出一个浏览器窗口让你登录 GitHub（Git Credential Manager），登录授权即可。
如果没弹窗，说明之前配过凭据，直接推就行；报 `Authentication failed` 的话，去
GitHub → Settings → Developer settings → Personal access tokens 生成一个带 `repo` 权限的 token，
用户名填 GitHub 用户名，密码位置粘贴 token。

### 步骤 3：触发编译

有两种方式，任选其一。

**方式 A：打 tag（会自动触发，最省事）**

```bash
git tag v1.9.1-ios
git push origin v1.9.1-ios
```

**方式 B：手动触发**

1. 打开 `https://github.com/<你的用户名>/lx-music-mobile-ios/actions`
2. 左侧点 **Build iOS Unsigned IPA**
3. 右侧点 **Run workflow** → 分支选 `main` → 再点绿色的 **Run workflow**

### 步骤 4：等它跑完

点进正在运行的任务，能看到步骤依次变绿：

```
✓ Checkout
✓ Setup Node
✓ Select Xcode
✓ Show toolchain versions
✓ Configure git for npm git dependencies
✓ Install npm dependencies          ← 约 5~10 分钟
✓ Install CocoaPods dependencies    ← 约 3~8 分钟
✓ Archive (unsigned)                ← 约 15~30 分钟，最慢的一步
✓ Package unsigned IPA
✓ Upload IPA artifact
```

全程大约 **30~50 分钟**（第一次最慢，之后有缓存会快一些）。

### 步骤 5：下载 IPA

任务跑完后，在任务详情页**最下方**找到 **Artifacts** 区域：

- `LxMusicMobile-unsigned-ipa` ← 点这个下载，得到一个 zip
- 解压后里面是 `LxMusicMobile-v1.9.1-unsigned.ipa`

这就是你要的未签名 IPA。

### 步骤 6：装到 iPhone

把 IPA 传到手机上，两种方式按你的 iOS 版本选：

| 方式 | 适用条件 | 说明 |
|---|---|---|
| **TrollStore 巨魔** | 你的 iOS 版本必须在 TrollStore 支持范围内 | 不需要签名、不过期、不需要电脑。去 https://github.com/opa334/TrollStore 查你的系统版本是否支持。装好后用 TrollStore 直接打开 IPA 即可 |
| **自签** | 任意 iOS 版本 | Windows 上可用 **Sideloadly**（sideloadly.io）或**爱思助手**。数据线连 iPhone → 拖入 IPA → 填 Apple ID → 开始。免费 Apple ID 签的包 **7 天过期**，过期需重签；付费开发者账号（$99/年）签的包 1 年有效 |

传输 IPA 到手机的方式：iCloud 云盘、微信文件传输助手（传到手机后用文件 App 打开）、数据线拷贝都行。

---

## 额度说明（很重要）

GitHub Actions 对**私有仓库**按分钟计费，而 **macOS runner 的计费倍率是 10 倍**：

| 仓库类型 | 每月免费额度 | 折算成 macOS 构建时间 | 大约能构建几次 |
|---|---|---|---|
| **Public（公开）** | 不限 | 不限 | 无限次 |
| **Private（私有）** | 2000 分钟 | 200 分钟 | 约 4~6 次 |

所以：

- 只想自己用、不在乎代码公开 → **选 Public**，随便构建
- 不想公开 → 选 Private，注意省着用（改完代码攒一攒再构建，别每次小改都跑）

这个项目本身是 Apache-2.0 开源的，公开你的修改没有授权问题。

---

## 如果第一次构建失败了

**大概率会失败一两次**，这是预期内的——iOS 原生代码（`ios/LXMobileNative/Classes/*.m`）是在 Windows 上写的，没有经过 Xcode 编译器验证，首次编译通常会有 1~3 处需要修的地方。

排查方法：

1. 打开失败的那次运行，展开红色的 **Archive (unsigned)** 步骤
2. 在日志里搜 `error:`，能看到具体是哪个文件哪一行
3. 也可以在 Artifacts 里下载 `build-log`，里面有完整日志

常见的几类错误和对应改法：

| 报错关键词 | 原因 | 改法 |
|---|---|---|
| `use of undeclared identifier` / `No visible @interface` | 少 import 了头文件 | 在对应 `.m` 顶部补 `#import` |
| `'xxx' is only available in iOS X.X or newer` | 用了高于 14.0 的 API | 加 `@available` 判断，或换低版本 API |
| `Implicit conversion loses integer precision` 升级为 error | 类型转换告警被当成错误 | 显式加 `(int)` / `(NSUInteger)` 强转 |
| `linker command failed` / `Undefined symbols` | pod 没正确链接 | 检查 `LXMobileNative.podspec` 的 `frameworks` / `dependency` |
| `pod install` 阶段失败 | CDN 索引或 podspec 路径问题 | 看日志里具体哪个 pod，通常是 `s.resources` 路径 |

把报错日志贴给我，我可以直接改代码。

---

## 方案二：租一台云 Mac（不推荐，但可行）

如果你不想公开代码、又急着要包，可以按小时租云 Mac：

- MacStadium、MacInCloud 之类，约 $1/小时
- 连上去之后按 `docs/iOS-ADAPTATION.md` §7.1 执行 `./scripts/build-ios-unsigned.sh`
- 优点：能直接在 Xcode 里调试编译错误，比看 CI 日志快
- 缺点：要花钱，且每次都要重新配环境

---

## 关于「在 Windows 上装个 macOS 虚拟机」

技术上可行（VMware/VirtualBox + macOS 镜像），但：

- 违反苹果的软件许可协议（macOS 只允许运行在苹果硬件上）
- 虚拟机里的 Xcode 编译速度极慢，且经常遇到图形栈、磁盘性能问题
- 折腾成本远高于直接用 GitHub Actions

不推荐，但这是你自己的机器，自己判断。

---

## 快速检查清单

推送前确认这几件事（都已配置好，列出来供你核对）：

- [x] `react-native.config.js` 已关闭两个 Android-only 依赖的 iOS autolinking
- [x] `.gitattributes` 已锁定 `.sh` 为 LF（否则 macOS 上会报 `bad interpreter: ^M`）
- [x] workflow 里已把 `git+ssh://` 重写成 https（否则 `npm ci` 会 Permission denied）
- [x] `node_modules/` 在 `.gitignore` 里（322MB，不会被推上去）
- [x] `ios/Podfile` 已关闭签名（`CODE_SIGNING_ALLOWED=NO`）
- [x] IPA 打包步骤会校验 `main.jsbundle` / `user-api-preload.js` / `UIBackgroundModes`

---

## 一句话总结

```bash
# 三步走
git remote add origin https://github.com/<你>/lx-music-mobile-ios.git
git push -u origin main
git tag v1.9.1-ios && git push origin v1.9.1-ios
# 然后去 Actions 页面等 30~50 分钟，下载 artifact 里的 IPA
```
