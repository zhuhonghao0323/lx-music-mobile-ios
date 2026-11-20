import UIKit
import CryptoKit

/// 封面缩略图磁盘缓存：列表里的封面只下载一次，之后本地秒开。
/// - 内存：NSCache（按 maxPixel 分桶，避免小图被大图顶掉）
/// - 磁盘：Caches/Covers/*.jpg（按 URL + 尺寸哈希命名）
/// - 下载：URLSession 共享缓存 + 失败不落盘，下次可重试
final class CoverThumbCache: @unchecked Sendable {
    static let shared = CoverThumbCache()

    private let memory = NSCache<NSString, UIImage>()
    private let ioQueue = DispatchQueue(label: "ZMusic.CoverThumbCache.io", qos: .utility)
    private let directory: URL
    private let session: URLSession
    /// 同一 URL 并发请求合并，避免列表滚动时重复下载
    private let lock = NSLock()
    private var inflight: [String: Task<UIImage?, Never>] = [:]

    private init() {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        directory = base.appendingPathComponent("Covers", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.urlCache = URLCache(memoryCapacity: 12 * 1024 * 1024, diskCapacity: 120 * 1024 * 1024)
        config.timeoutIntervalForRequest = 20
        session = URLSession(configuration: config)
        memory.countLimit = 420
    }

    /// 尺寸按 64 像素分桶，减少缓存碎片
    private func bucket(_ maxPixel: CGFloat) -> Int {
        max(96, Int((maxPixel / 64).rounded(.up)) * 64)
    }

    private func key(for url: URL, maxPixel: CGFloat) -> String {
        let raw = "\(url.absoluteString)|\(bucket(maxPixel))"
        let digest = SHA256.hash(data: Data(raw.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func fileURL(for key: String) -> URL {
        directory.appendingPathComponent(key + ".jpg")
    }

    /// 内存命中（同步，供首帧直接使用）
    func memoryImage(for url: URL?, maxPixel: CGFloat) -> UIImage? {
        guard let url else { return nil }
        return memory.object(forKey: key(for: url, maxPixel: maxPixel) as NSString)
    }

    /// 磁盘命中（同步，谨慎在大列表里用；列表走 async 版本）
    func diskImage(for url: URL?, maxPixel: CGFloat) -> UIImage? {
        guard let url else { return nil }
        let k = key(for: url, maxPixel: maxPixel)
        if let cached = memory.object(forKey: k as NSString) { return cached }
        guard let image = UIImage(contentsOfFile: fileURL(for: k).path) else { return nil }
        memory.setObject(image, forKey: k as NSString)
        return image
    }

    /// 异步取图：内存 → 磁盘 → 网络
    func image(for url: URL?, maxPixel: CGFloat) async -> UIImage? {
        guard let url else { return nil }
        let k = key(for: url, maxPixel: maxPixel)
        if let cached = memory.object(forKey: k as NSString) { return cached }

        lock.lock()
        if let task = inflight[k] {
            lock.unlock()
            return await task.value
        }
        let task = Task<UIImage?, Never> { [weak self] in
            guard let self else { return nil }
            if let disk = await self.readDisk(key: k) { return disk }
            return await self.download(url: url, key: k, maxPixel: maxPixel)
        }
        inflight[k] = task
        lock.unlock()

        let result = await task.value
        lock.lock()
        inflight[k] = nil
        lock.unlock()
        return result
    }

    /// 预下载（云同步用）：已存在则直接跳过
    @discardableResult
    func prewarm(url: URL?, maxPixel: CGFloat) async -> Bool {
        guard let url else { return false }
        let k = key(for: url, maxPixel: maxPixel)
        if memory.object(forKey: k as NSString) != nil { return true }
        if FileManager.default.fileExists(atPath: fileURL(for: k).path) { return true }
        return await image(for: url, maxPixel: maxPixel) != nil
    }

    func clearAll() {
        memory.removeAllObjects()
        ioQueue.async { [directory] in
            try? FileManager.default.removeItem(at: directory)
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }

    /// 当前磁盘占用（字节）
    func diskUsage() -> Int64 {
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.fileSizeKey])) ?? []
        return files.reduce(into: Int64(0)) { total, file in
            let size = (try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            total += Int64(size)
        }
    }

    private func readDisk(key: String) async -> UIImage? {
        let path = fileURL(for: key).path
        return await withCheckedContinuation { (continuation: CheckedContinuation<UIImage?, Never>) in
            ioQueue.async { [weak self] in
                guard let image = UIImage(contentsOfFile: path) else {
                    continuation.resume(returning: nil)
                    return
                }
                self?.memory.setObject(image, forKey: key as NSString)
                continuation.resume(returning: image)
            }
        }
    }

    private func download(url: URL, key: String, maxPixel: CGFloat) async -> UIImage? {
        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode), !data.isEmpty else {
                return nil
            }
            let target = bucket(maxPixel)
            guard let image = Self.downsample(data: data, maxPixel: CGFloat(target)) else { return nil }
            memory.setObject(image, forKey: key as NSString)
            if let jpeg = image.jpegData(compressionQuality: 0.86) {
                let path = fileURL(for: key)
                ioQueue.async { try? jpeg.write(to: path, options: .atomic) }
            }
            return image
        } catch {
            return nil
        }
    }

    private static func downsample(data: Data, maxPixel: CGFloat) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: cg)
    }
}
