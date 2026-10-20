import Foundation

/// 统计写入器（App 与扩展共用）——2 秒节流落盘
/// 刷新机制说明：主 App 的 StatsStore 用 1 秒轮询读盘（原 Darwin 通知方案已移除：
/// CFNotificationCenter 的 Darwin 中心 API 在 iOS SDK 的 Swift 接口层不可见，需 bridging header
/// 才能用——轮询已足够顺滑，砍掉复杂度换编译确定性）
final class StatsWriter {
    private let d = Shared.defaults
    private var pendingBlocked = 0
    private var pendingQuery = 0
    private var pendingDomains: [String: Int] = [:]
    private var lastFlush = Date.distantPast

    func record(blocked: Bool, domain: String) {
        pendingQuery += 1
        if blocked {
            pendingBlocked += 1
            pendingDomains[domain, default: 0] += 1
        }
        flushIfNeeded()
    }

    private func flushIfNeeded() {
        // 2 秒节流：DNS 查询高峰每秒几十条，不能条条写盘
        guard Date().timeIntervalSince(lastFlush) > 2 else { return }
        flush()
    }

    func flush() {
        lastFlush = Date()
        guard pendingQuery > 0 else { return }
        let totalB = d.integer(forKey: Shared.keyTotalBlocked) + pendingBlocked
        let totalQ = d.integer(forKey: Shared.keyTotalQuery) + pendingQuery
        d.set(totalB, forKey: Shared.keyTotalBlocked)
        d.set(totalQ, forKey: Shared.keyTotalQuery)
        d.set(Date().timeIntervalSince1970, forKey: Shared.keyLastActive)

        var daily = (d.dictionary(forKey: Shared.keyDailyBlocked) as? [String: Int]) ?? [:]
        let today = StatsWriter.dayFormatter.string(from: Date())
        daily[today, default: 0] += pendingBlocked
        // 只留 30 天，防字典无限膨胀
        if daily.count > 30 {
            for k in daily.keys.sorted().prefix(daily.count - 30) { daily.removeValue(forKey: k) }
        }
        d.set(daily, forKey: Shared.keyDailyBlocked)

        var domains = (d.dictionary(forKey: Shared.keyDomainStats) as? [String: Int]) ?? [:]
        for (k, v) in pendingDomains { domains[k, default: 0] += v }
        // 域名榜只留前 500 名，防长尾无限膨胀
        if domains.count > 500 {
            let drop = domains.sorted { $0.value < $1.value }.prefix(domains.count - 500)
            for (k, _) in drop { domains.removeValue(forKey: k) }
        }
        d.set(domains, forKey: Shared.keyDomainStats)

        pendingBlocked = 0
        pendingQuery = 0
        pendingDomains = [:]
    }

    static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}
