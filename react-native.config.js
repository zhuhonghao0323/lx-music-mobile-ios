/**
 * React Native 工程配置
 *
 * 这里最关键的一条：把两个「只有 Android 原生实现」的依赖在 iOS 上关掉。
 *
 * 为什么必须关：
 *   react-native-file-system / react-native-local-media-metadata 这两个包
 *   由上游自己维护（lyswhut fork），仓库里只有 android/ 目录，没有 ios/。
 *   但它们的 package.json 里声明了 podspec，CocoaPods 的 autolinking 会照单全收，
 *   执行 pod install 时会因为 podspec 里的 source_files 匹配不到任何文件而报错，
 *   或者装上一个空壳 pod 导致编译期链接失败。
 *
 * 关掉之后的替代方案（见 JS 层改动）：
 *   - 文件系统：src/utils/fs.ios.ts 用 react-native-fs 重写（RNFS 两端都支持）
 *   - 本地媒体元数据：src/utils/localMediaMetadata.ios.ts 做降级实现
 */
module.exports = {
  dependencies: {
    'react-native-file-system': {
      platforms: {
        ios: null,
      },
    },
    'react-native-local-media-metadata': {
      platforms: {
        ios: null,
      },
    },
  },
  // 图标字体 icomoon.ttf 通过 LXMobileNative 的 pod resources 打进 App bundle，
  // 并在 Info.plist 的 UIAppFonts 中注册，因此不需要在这里再配 assets。
}
