import SwiftUI
import UIKit

/// 兼容 iOS 13 的远程封面加载视图。
///
/// 系统 `AsyncImage` 需要 iOS 15+，而本项目最低支持 iOS 13.4，
/// 所以这里用 URLSession + 内存缓存做一份轻量实现。
final class SwiftUICoverImageCache {
  static let shared = SwiftUICoverImageCache()
  private let cache = NSCache<NSString, UIImage>()
  private let session: URLSession

  private init() {
    let config = URLSessionConfiguration.default
    config.requestCachePolicy = .returnCacheDataElseLoad
    config.urlCache = URLCache(memoryCapacity: 8 * 1024 * 1024,
                               diskCapacity: 64 * 1024 * 1024,
                               diskPath: "lx_cover_cache")
    session = URLSession(configuration: config)
    cache.countLimit = 30
  }

  func cachedImage(for url: URL) -> UIImage? {
    cache.object(forKey: url.absoluteString as NSString)
  }

  func load(_ url: URL, completion: @escaping (UIImage?) -> Void) {
    if let image = cachedImage(for: url) {
      completion(image)
      return
    }
    let task = session.dataTask(with: url) { [weak self] data, _, _ in
      guard let data = data, let image = UIImage(data: data) else {
        DispatchQueue.main.async { completion(nil) }
        return
      }
      self?.cache.setObject(image, forKey: url.absoluteString as NSString)
      DispatchQueue.main.async { completion(image) }
    }
    task.resume()
  }
}

struct SwiftUICoverImage: View {
  let url: URL
  @State private var image: UIImage?

  var body: some View {
    Group {
      if let image = image {
        Image(uiImage: image).resizable().aspectRatio(contentMode: .fill)
      } else {
        ZStack {
          Color.white.opacity(0.06)
          Image(systemName: "music.note")
            .font(.system(size: 44))
            .foregroundColor(.white.opacity(0.35))
        }
      }
    }
    // onChange(of:) 需要 iOS 14+，这里用最简单的 onAppear + 视图 id 变化重建，
    // 保证切换歌曲换封面时能重新加载。
    .onAppear { load() }
  }

  private func load() {
    if let cached = SwiftUICoverImageCache.shared.cachedImage(for: url) {
      image = cached
      return
    }
    image = nil
    SwiftUICoverImageCache.shared.load(url) { loaded in
      if loaded != nil { image = loaded }
    }
  }
}
