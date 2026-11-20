import Foundation

/// 第三方音源脚本自动更新。
///
/// 规则：
/// 1. 只有「从链接导入」的音源记录了 `updateURL`，才有自动更新的可能；
/// 2. 每次检查重新拉取远程脚本，先确认新内容仍能被解析成音源（避免把可用配置覆盖成垃圾），
///    再比对脚本内容指纹与 `@version`，有变化才写回本地；
/// 3. 默认 12 小时最多检查一次，也可以在音源管理面板手动点「检查更新」。
@MainActor
final class ThirdPartySourceAutoUpdater: ObservableObject {
    static let shared = ThirdPartySourceAutoUpdater()

    enum Phase: Equatable {
        case idle
        case checking
        case finished(updated: Int, failed: Int)
    }

    static let autoUpdateKey = "beans.thirdPartySourceAutoUpdate"
    static let lastRunKey = "beans.thirdPartySourceAutoUpdate.lastRun"
    /// 自动检查的最小间隔
    static let autoInterval: TimeInterval = 12 * 60 * 60

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var lastMessage: String?

    private let defaults = UserDefaults.standard

    var autoUpdateEnabled: Bool {
        defaults.object(forKey: Self.autoUpdateKey) as? Bool ?? true
    }

    func setAutoUpdateEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: Self.autoUpdateKey)
    }

    /// 可自动更新的音源（启用 + 有远程地址）
    func updatableCount(in sources: [ThirdPartySource]) -> Int {
        sources.filter { $0.enabled && !($0.updateURL ?? "").isEmpty }.count
    }

    /// 进入音源管理面板 / 启动时调用：只有超过间隔才真正发请求
    @discardableResult
    func autoCheckIfNeeded(store: UnblockSourceStore = .shared) async -> Int {
        guard autoUpdateEnabled else { return 0 }
        let last = defaults.object(forKey: Self.lastRunKey) as? Date ?? .distantPast
        guard Date().timeIntervalSince(last) > Self.autoInterval else { return 0 }
        return await checkAll(store: store, silent: true)
    }

    /// 全量检查（手动触发时 silent = false，会写 lastMessage）
    @discardableResult
    func checkAll(store: UnblockSourceStore = .shared, silent: Bool = false) async -> Int {
        guard phase != .checking else { return 0 }
        let candidates = store.sources.filter { $0.enabled && !($0.updateURL ?? "").isEmpty }
        guard !candidates.isEmpty else {
            if !silent {
                lastMessage = beansLocalized(
                    "没有可自动更新的音源：只有「从链接导入」的音源会记录更新地址",
                    "No updatable sources: only sources imported from a URL keep an update address"
                )
            }
            return 0
        }
        phase = .checking
        var updatedCount = 0
        var failedCount = 0
        for source in candidates {
            switch await check(source) {
            case .updated(let updated):
                store.upsert(updated)
                updatedCount += 1
            case .upToDate:
                var touched = source
                touched.lastCheckedAt = Date()
                store.upsert(touched)
            case .failed:
                failedCount += 1
            }
        }
        defaults.set(Date(), forKey: Self.lastRunKey)
        phase = .finished(updated: updatedCount, failed: failedCount)
        if !silent {
            lastMessage = summary(updated: updatedCount, failed: failedCount)
        }
        return updatedCount
    }

    private func summary(updated: Int, failed: Int) -> String {
        var parts: [String] = []
        if updated > 0 {
            parts.append(beansLocalized("已更新 \(updated) 个音源", "Updated \(updated) source(s)"))
        } else {
            parts.append(beansLocalized("已是最新版本", "Already up to date"))
        }
        if failed > 0 {
            parts.append(beansLocalized("\(failed) 个检查失败", "\(failed) failed"))
        }
        return parts.joined(separator: "，")
    }

    private enum Outcome {
        case updated(ThirdPartySource)
        case upToDate
        case failed
    }

    private func check(_ source: ThirdPartySource) async -> Outcome {
        guard let rawURL = source.updateURL,
              let url = URL(string: rawURL),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            return .failed
        }
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 20
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.setValue("BeansMusic/1.0", forHTTPHeaderField: "User-Agent")
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                BeansLogger.shared.log("音源自动更新：\(source.name) HTTP \(http.statusCode)", level: .debug)
                return .failed
            }
            guard let text = String(data: data, encoding: .utf8), !text.isEmpty else { return .failed }
            // 新内容必须仍能解析成音源，否则保留旧配置
            guard let parsed = try? ThirdPartySourceImportParser.parse(text: text, fallbackName: source.name),
                  let candidate = parsed.first else {
                BeansLogger.shared.log("音源自动更新：\(source.name) 远程内容无法解析，跳过", level: .debug)
                return .failed
            }
            let incomingScript = candidate.script ?? text
            let incomingVersion = candidate.version
            let changed: Bool
            if let current = source.script, !current.isEmpty {
                changed = Self.fingerprint(current) != Self.fingerprint(incomingScript)
            } else {
                changed = true
            }
            let versionChanged = {
                guard let incomingVersion else { return false }
                guard let currentVersion = source.version, !currentVersion.isEmpty else { return false }
                return currentVersion != incomingVersion
            }()
            guard changed || versionChanged else { return .upToDate }

            var updated = source
            updated.script = incomingScript
            updated.version = incomingVersion ?? source.version
            if !candidate.template.isEmpty { updated.template = candidate.template }
            if !candidate.headers.isEmpty {
                var merged = source.headers
                for (key, value) in candidate.headers { merged[key] = value }
                updated.headers = merged
            }
            updated.lastCheckedAt = Date()
            updated.lastUpdatedAt = Date()
            BeansLogger.shared.log(
                "音源自动更新：\(source.name) \(source.version ?? "-") → \(updated.version ?? "-")",
                level: .info
            )
            return .updated(updated)
        } catch {
            BeansLogger.shared.log("音源自动更新失败：\(source.name) \(error.localizedDescription)", level: .debug)
            return .failed
        }
    }

    /// 忽略行尾与首尾空白的指纹，避免仅换行差异触发误更新
    private static func fingerprint(_ script: String) -> String {
        script
            .replacingOccurrences(of: "\r\n", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
