#!/usr/bin/env bash
#
# 洛雪音乐 iOS —— 本地编译未签名 IPA
#
# 用法（在 Mac 上执行）：
#   ./scripts/build-ios-unsigned.sh
#
# 产物：build/artifacts/LxMusicMobile-unsigned.ipa
#   该 IPA 未做任何签名，可直接用于：
#     - TrollStore 巨魔安装
#     - Sideloadly / AltStore / i4Tools 等工具自签后安装
#
# 前置条件：
#   - macOS + Xcode（建议 15.4 及以上）
#   - Node >= 18、CocoaPods >= 1.13
#   - 已执行过 npm install
#
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

SCHEME="LxMusicMobile"
WORKSPACE="ios/${SCHEME}.xcworkspace"
ARCHIVE_PATH="build/${SCHEME}.xcarchive"
ARTIFACT_DIR="build/artifacts"
APP_NAME="${SCHEME}.app"
OUTPUT_IPA="${ARTIFACT_DIR}/${SCHEME}-unsigned.ipa"

log() { printf '\033[1;36m[ios-build]\033[0m %s\n' "$*"; }
fail() { printf '\033[1;31m[ios-build] %s\033[0m\n' "$*" >&2; exit 1; }

# ---------- 环境检查 ----------
command -v node >/dev/null 2>&1 || fail "未找到 node，请先安装 Node.js >= 18"
command -v pod  >/dev/null 2>&1 || fail "未找到 CocoaPods，请执行: sudo gem install cocoapods"

if [ ! -d "node_modules" ]; then
  fail "未找到 node_modules，请先在项目根目录执行 npm install"
fi

xcodebuild -version >/dev/null 2>&1 || fail "未找到 Xcode 命令行工具，请执行: xcode-select --install"

log "Node $(node -v) / $(pod --version | sed 's/^/CocoaPods /')"
log "Xcode $(xcodebuild -version | head -1)"

# ---------- 同步共享资源 ----------
# user-api-preload.js 与 icomoon.ttf 是 Android/iOS 共用的资源，
# 但 CocoaPods 只认 pod 目录内的资源路径（../.. 越界路径会被静默跳过，
# 表现为 app bundle 里缺文件），所以构建前从源头同步一份。
log "同步共享资源到 pod 目录..."
mkdir -p ios/LXMobileNative/Resources
cp android/app/src/main/assets/script/user-api-preload.js ios/LXMobileNative/Resources/
cp src/resources/fonts/icomoon.ttf ios/LXMobileNative/Resources/
ls -l ios/LXMobileNative/Resources/

# ---------- 安装 Pods ----------
log "安装 CocoaPods 依赖（首次会比较慢，需要编译 Hermes 等）..."
pushd ios >/dev/null
pod install --repo-update
popd >/dev/null

[ -d "$WORKSPACE" ] || fail "pod install 未生成 ${WORKSPACE}"

# ---------- 清理旧产物 ----------
rm -rf "$ARCHIVE_PATH"
mkdir -p "$ARTIFACT_DIR"

# ---------- 归档（不签名） ----------
# 关键参数说明：
#   CODE_SIGNING_ALLOWED=NO     : 整个归档过程不签名，无证书也能跑通
#   CODE_SIGNING_REQUIRED=NO    : 同上，双保险
#   CODE_SIGN_IDENTITY=""       : 清空签名身份，避免 Xcode 去找默认证书
#   -destination generic/platform=iOS : 只编译真机 arm64，不编译模拟器架构
log "开始编译（Release / arm64 / 未签名）..."
xcodebuild \
  -workspace "$WORKSPACE" \
  -scheme "$SCHEME" \
  -configuration Release \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE_PATH" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGN_ENTITLEMENTS="" \
  ENABLE_BITCODE=NO \
  clean archive

APP_PATH="${ARCHIVE_PATH}/Products/Applications/${APP_NAME}"
[ -d "$APP_PATH" ] || fail "归档产物中找不到 ${APP_NAME}，路径：${APP_PATH}"

# ---------- 校验产物 ----------
log "校验产物结构..."
[ -f "${APP_PATH}/Info.plist" ] || fail "App 缺少 Info.plist"
[ -f "${APP_PATH}/main.jsbundle" ] || fail "App 缺少 main.jsbundle（JS 未打进包，检查 Bundle React Native code and images 构建阶段）"

# 确认后台音频声明真的写进包了：这是锁屏播放能工作的前提
if ! /usr/libexec/PlistBuddy -c "Print :UIBackgroundModes" "${APP_PATH}/Info.plist" 2>/dev/null | grep -q "audio"; then
  fail "Info.plist 缺少 UIBackgroundModes=audio，后台播放会失效"
fi

# 确认图标字体被打进包了，否则所有图标会变成方块
if [ ! -f "${APP_PATH}/icomoon.ttf" ]; then
  log "警告：包内未找到 icomoon.ttf，界面图标可能无法显示"
fi

# 确认音源脚本沙箱的 preload 脚本在包里
if [ ! -f "${APP_PATH}/user-api-preload.js" ]; then
  fail "包内缺少 user-api-preload.js，自定义音源脚本将无法运行"
fi

# ---------- 打包成 IPA ----------
log "打包 IPA..."
STAGE_DIR="build/ipa-stage"
rm -rf "$STAGE_DIR"
mkdir -p "${STAGE_DIR}/Payload"
cp -R "$APP_PATH" "${STAGE_DIR}/Payload/"

rm -f "$OUTPUT_IPA"
pushd "$STAGE_DIR" >/dev/null
# 用 zip 而不是 ditto：TrollStore / 自签工具对标准 zip 结构兼容性更好
zip -qry "$OUTPUT_IPA" Payload
popd >/dev/null

rm -rf "$STAGE_DIR"

SIZE=$(du -h "$OUTPUT_IPA" | cut -f1)
log "完成：${OUTPUT_IPA} (${SIZE})"
log "该 IPA 未签名，可直接用 TrollStore 安装，或用自签工具重签后安装。"
