import Foundation

/// 全局共享常量——主 App 与隧道扩展共用
/// 风险报表原则：所有跨进程数据都走 App Group，全部锁在你自己的沙盒里
enum Shared {
    /// App Group 标识（两 target 的 entitlements 必须一致）
    static let groupID = "group.com.adam.clearscreen"
    static var defaults: UserDefaults {
        UserDefaults(suiteName: groupID) ?? .standard
    }

    // MARK: - 键名
    static let keyMasterOn = "masterOn"                    // 总闸：一键放行全部流量
    static let keyUpstreamDNS = "upstreamDNS"              // 真实上游 DNS
    static let keyHijackPublic = "hijackPublicDNS"         // 劫持公共硬编码 DNS
    static let keyCustomRules = "customRules"              // 用户自定义拦截后缀
    static let keyTotalBlocked = "stat.totalBlocked"       // 累计拦截数
    static let keyTotalQuery = "stat.totalQuery"           // 累计查询数
    static let keyDailyBlocked = "stat.dailyBlocked"       // [yyyy-MM-dd: Int]
    static let keyDomainStats = "stat.domainCounts"        // [域名: Int]
    static let keyLastActive = "stat.lastActive"

    /// 通知 App 刷新 UI 的 Darwin 通知名
    static let darwinRefresh = "com.adam.clearscreen.statsUpdated"

    /// 隧道虚拟网段（RFC 2544 基准地址段，不与任何真实网络冲突）
    static let tunnelIP = "198.18.0.1"
    static let virtualDNS = "198.18.0.2"

    /// 默认上游（阿里 DNS，低延迟）
    static let defaultUpstream = "223.5.5.5"
    /// 可选上游池
    static let upstreamPool = [
        "223.5.5.5": "阿里 DNS",
        "119.29.29.29": "DNSPod",
        "114.114.114.114": "114 DNS",
        "1.2.4.8": "CNNIC",
    ]
    /// 常见硬编码公共 DNS（勾选后一并引入隧道接管，防止 App 绕过）
    static let publicDNSHijack = ["8.8.8.8", "8.8.4.4", "1.1.1.1", "114.114.114.114", "180.76.76.76"]
}
