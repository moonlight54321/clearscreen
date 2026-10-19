import Foundation
import NetworkExtension

/// VPN 配置管理：创建/保存/开关隧道
final class VPNManager: ObservableObject {
    @Published var status: NEVPNStatus = .invalid
    private var manager = NETunnelProviderManager()

    init() { refresh() }

    func refresh() {
        NETunnelProviderManager.loadAllFromPreferences { [weak self] managers, _ in
            if let existing = managers?.first {
                self?.manager = existing
            } else {
                self?.buildConfig()
            }
            DispatchQueue.main.async {
                self?.status = self?.manager.connection.status ?? .invalid
                self?.watchStatus()
            }
        }
    }

    private func buildConfig() {
        let proto = NETunnelProviderProtocol()
        proto.providerBundleIdentifier = "com.adam.clearscreen.tunnel"
        proto.serverAddress = "清屏"
        manager.protocolConfiguration = proto
        manager.localizedDescription = "清屏 · 广告断粮器"
        manager.isEnabled = true
    }

    private func watchStatus() {
        NotificationCenter.default.removeObserver(self, name: .NEVPNStatusDidChange, object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(statusChanged),
            name: .NEVPNStatusDidChange, object: nil)
    }

    @objc private func statusChanged() {
        DispatchQueue.main.async { [weak self] in
            self?.status = self?.manager.connection.status ?? .invalid
        }
    }

    /// 开隧道（iOS 会弹"添加 VPN 配置"确认框——那就是你的海关申报环节）
    func start() {
        manager.saveToPreferences { [weak self] _ in
            self?.manager.loadFromPreferences { m, _ in
                guard let m = m else { return }
                self?.manager = m
                self?.manager.isEnabled = true
                self?.manager.saveToPreferences { _, _ in
                    try? self?.manager.connection.startVPNTunnel()
                }
            }
        }
    }

    func stop() {
        manager.connection.stopVPNTunnel()
    }
}
