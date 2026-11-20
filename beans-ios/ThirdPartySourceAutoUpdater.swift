import Foundation

/// 第三方音源脚本自动更新。
///
/// 对齐 LX Music 的「URL 音源自动更新」语义：
/// 1. 只有记录了 `updateURL`（链接导入，或手动填写）的音源才会检查更新；
/// 2. 拉取时显式声明 `Accept: text/javascript`，避免分发服务器返回 JSON 错误体；
/// 3. 版本号归一化后按语义比较（远端 > 本地 才更新），没有版本号时退回内容比对；
/// 4. 新内容必须仍能解析成音源才写入，失败一律保留旧脚本；
/// 5. 默认 12 小时最多自动检查一次，也可手动触发。
final class ThirdPartySourceAutoUpdater: ObservableObject {
    static let shared = ThirdPartySourceAutoUpdater()

    enum Phase: Equatable {
        case idle
        case checking
        case finished(updated: Int, failed: Int)
    }

    /// 单个音源的检查结果
    enum SingleOutcome {
        case updated(from: String?, to: String?)
        case latest
        case noUpdateURL
        case failed(String)

        func message(sourceName: String) -> String {
            switch self {
            case .updated(let from, let to):
                let fromText = from ?? "旧版本"
                let toText = to ?? "新版本"
                return beansLocalized(
                    "已更新「\(sourceName)」：\(fromText) → \(toText)",
                    "Updated \(sourceName): \(fromText) → \(toText)"
                )
            case .latest:
                return beansLocalized("「\(sourceName)」已是最新版本", "\(sourceName) is already up to date")
            case .noUpdateURL:
                return beansLocalized(
                    "「\(sourceName)」没有更新地址，请在编辑里填写脚本链接",
                    "\(sourceName) has no update URL. Add one in Edit."
                )
            case .failed(let reason):
                return beansLocalized("「\(sourceName)」检查失败：\(reason)", "\(sourceName) update failed: \(reason)")
            }
        }
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
    @MainActor
    func autoCheckIfNeeded(store: UnblockSourceStore = .shared) async -> Int {
        guard autoUpdateEnabled else { return 0 }
        let last = defaults.object(forKey: Self.lastRunKey) as? Date ?? .distantPast
        guard Date().timeIntervalSince(last) > Self.autoInterval else { return 0 }
        guard updatableCount(in: store.sources) > 0 else { return 0 }
        return await checkAll(store: store, silent: true)
    }

    /// 全量检查（手动触发时 silent = false，会写 lastMessage）
    @discardableResult
    @MainActor
    func checkAll(store: UnblockSourceStore = .shared, silent: Bool = false) async -> Int {
        guard phase != .checking else { return 0 }
        let candidates = store.sources.filter { $0.enabled && !($0.updateURL ?? "").isEmpty }
        guard !candidates.isEmpty else {
            if !silent {
                lastMessage = beansLocalized(
                    "没有可自动更新的音源：只有填了更新地址的音源才会检查更新",
                    "No updatable sources: only sources with an update URL are checked"
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
            case .noUpdateURL:
                break
            }
        }
        defaults.set(Date(), forKey: Self.lastRunKey)
        phase = .finished(updated: updatedCount, failed: failedCount)
        if !silent {
            lastMessage = summary(updated: updatedCount, failed: failedCount)
        }
        return updatedCount
    }

    /// 单个音源手动更新（音源行上的「更新」按钮）
    @discardableResult
    @MainActor
    func updateOne(_ source: ThirdPartySource, store: UnblockSourceStore = .shared) async -> SingleOutcome {
        switch await check(source) {
        case .updated(let updated):
            store.upsert(updated)
            lastMessage = SingleOutcome.updated(from: source.version, to: updated.version).message(sourceName: source.name)
            return .updated(from: source.version, to: updated.version)
        case .upToDate:
            var touched = source
            touched.lastCheckedAt = Date()
            store.upsert(touched)
            let outcome = SingleOutcome.latest
            lastMessage = outcome.message(sourceName: source.name)
            return outcome
        case .noUpdateURL:
            let outcome = SingleOutcome.noUpdateURL
            lastMessage = outcome.message(sourceName: source.name)
            return outcome
        case .failed(let reason):
            let outcome = SingleOutcome.failed(reason)
            lastMessage = outcome.message(sourceName: source.name)
            return outcome
        }
    }

    @MainActor
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
        case noUpdateURL
        case failed(String)
    }

    @MainActor
    private func check(_ source: ThirdPartySource) async -> Outcome {
        guard let rawURL = source.updateURL?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawURL.isEmpty,
              let url = URL(string: rawURL),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            return .noUpdateURL
        }
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 20
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.setValue("BeansMusic/1.0", forHTTPHeaderField: "User-Agent")
            // 分发服务器会按 Accept 决定返回脚本还是 JSON 错误体
            request.setValue("text/javascript,application/javascript,*/*", forHTTPHeaderField: "Accept")
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                BeansLogger.shared.log("音源自动更新：\(source.name) HTTP \(http.statusCode)", level: .debug)
                return .failed("HTTP \(http.statusCode)")
            }
            guard data.count <= 9_000_000 else { return .failed("脚本过大") }
            guard let text = String(data: data, encoding: .utf8),
                  !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return .failed("响应为空")
            }
            guard let parsed = try? ThirdPartySourceImportParser.parse(text: text, fallbackName: source.name),
                  let candidate = parsed.first else {
                BeansLogger.shared.log("音源自动更新：\(source.name) 远程内容无法解析，跳过", level: .debug)
                return .failed("远程内容无法解析")
            }

            let incomingScript = candidate.script ?? text
            let incomingVersion = candidate.version
            let oldVersion = source.version
            let shouldUpdate: Bool
            if let remote = Self.normalizedVersion(incomingVersion),
               let local = Self.normalizedVersion(oldVersion) {
                shouldUpdate = Self.compareVersion(remote, local) > 0
            } else if let current = source.script, !current.isEmpty {
                // 任意一端没有合法版本号时，退回内容比对
                shouldUpdate = Self.fingerprint(current) != Self.fingerprint(incomingScript)
            } else {
                let templateChanged = !candidate.template.isEmpty && candidate.template != source.template
                let headersChanged = candidate.headers.contains { source.headers[$0.key] != $0.value }
                shouldUpdate = templateChanged || headersChanged
            }
            guard shouldUpdate else { return .upToDate }

            var updated = source
            updated.script = incomingScript
            updated.version = incomingVersion ?? source.version
            if !candidate.name.isEmpty { updated.name = candidate.name }
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
            return .failed(error.localizedDescription)
        }
    }

    /// 剥掉 v 前缀并校验纯数字点分格式；不合法返回 nil
    static func normalizedVersion(_ version: String?) -> String? {
        guard let version else { return nil }
        var text = version.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("v") || text.hasPrefix("V") { text.removeFirst() }
        let parts = text.split(separator: ".")
        guard (1...4).contains(parts.count),
              parts.allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isNumber) }) else {
            return nil
        }
        return text
    }

    /// 语义化版本比较：a > b 返回 1，相等 0，小于 -1
    static func compareVersion(_ a: String, _ b: String) -> Int {
        let left = a.split(separator: ".").map { Int($0) ?? 0 }
        let right = b.split(separator: ".").map { Int($0) ?? 0 }
        let count = max(left.count, right.count)
        for index in 0..<count {
            let l = index < left.count ? left[index] : 0
            let r = index < right.count ? right[index] : 0
            if l != r { return l > r ? 1 : -1 }
        }
        return 0
    }

    /// 忽略行尾与首尾空白的指纹，避免仅换行差异触发误更新
    private static func fingerprint(_ script: String) -> String {
        script
            .replacingOccurrences(of: "\r\n", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
