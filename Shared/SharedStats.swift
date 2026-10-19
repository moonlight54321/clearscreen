import Foundation

/// 统计写入器（App 与扩展共用）——节流落盘 + Darwin 通知提醒主 App 刷新 UI
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

        DarwinNotificationCenter.post(Shared.darwinRefresh)
    }

    static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}

/// Darwin 通知——扩展和主 App 进程间的实时信道（不占额外权限）
enum DarwinNotificationCenter {
    /// 观察盒注册表：保住 CF 观察指针的生命周期
    private static var boxes: [ObjectIdentifier: ObserverBox] = [:]
    private static let bridgeName = Notification.Name("com.adam.clearscreen.darwin.bridge")

    static func post(_ name: String) {
        let center = CFNotificationCenterGetDarwinNotificationCenter()
        CFNotificationCenterPostNotification(center, CFNotificationName(name as CFString), nil, nil, true)
    }

    static func observe(_ name: String, callback: @escaping () -> Void) -> () -> Void {
        let box = ObserverBox(callback: callback)
        boxes[ObjectIdentifier(box)] = box
        let center = CFNotificationCenterGetDarwinNotificationCenter()
        let nameRef = CFNotificationName(name as CFString)
        // CF 回调是 C 函数指针（不能捕获），借 NotificationCenter 桥一次到主线程
        CFNotificationCenterAddObserver(center, Unmanaged.passUnretained(box).toOpaque(), { _, _, _, _, _ in
            NotificationCenter.default.post(name: bridgeName, object: nil)
        }, nameRef, nil, .deliverImmediately)
        let token = NotificationCenter.default.addObserver(forName: bridgeName, object: nil, queue: .main) { _ in
            callback()
        }
        return {
            NotificationCenter.default.removeObserver(token)
            CFNotificationCenterRemoveObserver(center, Unmanaged.passUnretained(box).toOpaque(), nameRef, nil)
            boxes.removeValue(forKey: ObjectIdentifier(box))
        }
    }
}

private final class ObserverBox {
    let callback: () -> Void
    init(callback: @escaping () -> Void) { self.callback = callback }
}
