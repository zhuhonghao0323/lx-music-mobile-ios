#
# 洛雪音乐 iOS 原生模块集合（本地 pod）
#
# 为什么用本地 pod 而不是往 Xcode 工程里手动添加源文件：
# 手动改 project.pbxproj 需要同步维护 PBXBuildFile / PBXFileReference /
# PBXGroup / PBXSourcesBuildPhase 四处 UUID，极易写坏工程文件且无法 code review。
# 用 pod 承载后，Xcode 工程的 pbxproj 只需要改 build settings（bundle id / 签名），
# 新增/删除源文件都不再需要碰 pbxproj。
#
Pod::Spec.new do |s|
  s.name         = 'LXMobileNative'
  s.version      = '1.0.0'
  s.summary      = 'iOS native modules for lx-music-mobile'
  s.description  = <<-DESC
    Android 侧自研原生模块（userApi / utils / cache / crypto）的 iOS 等价实现。
  DESC
  s.homepage     = 'https://github.com/lyswhut/lx-music-mobile'
  # 用内联文本而不是 :file => '../../LICENSE'，避免 pod 校验时去解析越界的文件路径
  s.license      = { :type => 'Apache-2.0', :text => 'Apache License, Version 2.0' }
  s.author       = { 'lx-music-mobile' => 'lyswhut@qq.com' }
  # 与 Podfile 的 platform 保持一致，避免 deployment target 不匹配的告警
  s.platform     = :ios, '14.0'
  s.source       = { :path => '.' }

  s.source_files = 'Classes/**/*.{h,m,mm}'
  s.requires_arc = true

  # 音源脚本沙箱依赖系统内置 JavaScriptCore（替代 Android 的 QuickJS）
  s.frameworks = 'JavaScriptCore', 'Security', 'AVFoundation', 'MediaPlayer', 'UIKit'

  s.dependency 'React-Core'

  # 资源必须放在 pod 目录内部。
  #
  # 踩过的两个坑：
  #   1. 用 File.expand_path 生成绝对路径 → pod 校验直接失败：
  #      "File Patterns: File patterns must be relative and cannot start with a slash"
  #   2. 改成 '../../android/...' 这种相对路径 → 校验能过，但 CocoaPods 在
  #      **复制资源阶段**会静默跳过越界路径，最终 app bundle 里根本没有这些文件，
  #      表现为 CI 打包时校验失败："缺少 user-api-preload.js"
  #
  # 所以只能放在 Resources/ 下。这两个文件是 Android/iOS 共用的：
  #   - user-api-preload.js：音源脚本沙箱的宿主 API 注入脚本
  #   - icomoon.ttf：图标字体（配合 Info.plist 的 UIAppFonts 注册）
  # 源头分别是 android/app/src/main/assets/script/ 与 src/resources/fonts/，
  # 构建脚本（scripts/build-ios-unsigned.sh）和 CI 都会在 pod install 前
  # 自动从源头同步过来，避免两边不一致。
  s.resources = ['Resources/*']

  # 纯 Objective-C 静态库，不设 DEFINES_MODULE（那会要求额外的 modulemap），
  # 只保留 CLANG_ENABLE_MODULES 以便用 @import 方式引用 React
  s.pod_target_xcconfig = {
    'CLANG_ENABLE_MODULES' => 'YES',
  }
end
