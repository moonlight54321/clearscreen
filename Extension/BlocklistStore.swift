import Foundation

/// 拦截规则库：内置清单 + 用户自定义，统一后缀匹配
/// 数据源全部在 App Group 沙盒内，规则可随时增删——全透明账本
final class BlocklistStore {
    private(set) var suffixes: Set<String> = []
    private let d = Shared.defaults

    func reload() {
        suffixes = Set(StarterBlocklist.allSuffixes)
        if let custom = d.stringArray(forKey: Shared.keyCustomRules) {
            for rule in custom where !rule.isEmpty {
                suffixes.insert(rule.lowercased().trimmingCharacters(in: .whitespaces))
            }
        }
    }

    /// 域名是否命中拦截：query 或其任意父域在清单里即命中
    /// 例：规则 "gdt.qq.com" 命中 "mi.gdt.qq.com"
    func isBlocked(domain: String) -> Bool {
        var parts = domain.split(separator: ".").map(String.init)
        while !parts.isEmpty {
            if suffixes.contains(parts.joined(separator: ".")) { return true }
            parts.removeFirst()
        }
        return false
    }
}
