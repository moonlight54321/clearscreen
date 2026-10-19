import Foundation
import SwiftUI

/// 主 App 侧的统计读取器：轮询 + Darwin 通知双触发刷新
final class StatsStore: ObservableObject {
    @Published var totalBlocked = 0
    @Published var totalQuery = 0
    @Published var todayBlocked = 0
    @Published var daily: [(day: String, count: Int)] = []
    @Published var topDomains: [(domain: String, count: Int)] = []
    @Published var lastActive: Date?
    @Published var masterOn: Bool {
        didSet { Shared.defaults.set(masterOn, forKey: Shared.keyMasterOn) }
    }

    private var timer: Timer?
    private var removeObservation: (() -> Void)?

    init() {
        masterOn = Shared.defaults.object(forKey: Shared.keyMasterOn) as? Bool ?? false
        reload()
        // 前台 1 秒轮询（统计写盘有 2 秒节流，1 秒轮询够顺滑）
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.reload()
        }
        // 扩展落盘瞬间主动叫醒一次
        removeObservation = DarwinNotificationCenter.observe(Shared.darwinRefresh) { [weak self] in
            DispatchQueue.main.async { self?.reload() }
        }
    }

    deinit {
        timer?.invalidate()
        removeObservation?()
    }

    func reload() {
        let d = Shared.defaults
        totalBlocked = d.integer(forKey: Shared.keyTotalBlocked)
        totalQuery = d.integer(forKey: Shared.keyTotalQuery)
        let dailyDict = (d.dictionary(forKey: Shared.keyDailyBlocked) as? [String: Int]) ?? [:]
        let today = StatsWriter.dayFormatter.string(from: Date())
        todayBlocked = dailyDict[today] ?? 0
        daily = dailyDict.sorted { $0.key < $1.key }.suffix(7).map { (day: $0.key, count: $0.value) }
        let domains = (d.dictionary(forKey: Shared.keyDomainStats) as? [String: Int]) ?? [:]
        topDomains = domains.sorted { $0.value > $1.value }.prefix(20).map { (domain: $0.key, count: $0.value) }
        if let t = d.object(forKey: Shared.keyLastActive) as? TimeInterval {
            lastActive = Date(timeIntervalSince1970: t)
        }
    }

    /// 拦截率（百分比，无查询时为 nil）
    var blockRate: Double? {
        guard totalQuery > 0 else { return nil }
        return Double(totalBlocked) / Double(totalQuery) * 100
    }
}
