import Foundation
import NetworkExtension
import Network

/// 隧道主体：DNS 拦截型 Packet Tunnel
/// 工作模型（断粮式拦截）：
///   1. 只把虚拟 DNS (198.18.0.2) 和被劫持的公共 DNS 路由进隧道——你的全部正常流量不进隧道
///   2. 系统和应用的所有 DNS 查询会落到扩展手里
///   3. 命中拦截清单 → 当场回 NXDOMAIN（域名不存在）→ 开屏广告拉不到内容 = 断粮
///   4. 未命中 → 原样转发给真实上游（223.5.5.5 等），把答案送回查询方
/// 总闸（masterOn）开启时：全部查询直通上游，不做拦截——规则出问题时一键救网
class PacketTunnelProvider: NEPacketTunnelProvider {

    private let blocklist = BlocklistStore()
    private let stats = StatsWriter()
    private var upstream: NWEndpoint.Host = "223.5.5.5"
    private var connection: NWConnection?
    // 待应答查询表：key = 改写后的事务 ID
    private var pendingQueries: [UInt16: (clientIP: [UInt8], clientPort: UInt16, origID: UInt16, createdAt: Date)] = [:]
    private var pendingCount = 0
    private var idCursor: UInt16 = 0

    override func start(completionHandler: @escaping (Error?) -> Void) {
        blocklist.reload()
        let d = Shared.defaults
        let upstreamStr = d.string(forKey: Shared.keyUpstreamDNS) ?? Shared.defaultUpstream
        upstream = NWEndpoint.Host(upstreamStr)

        // 隧道网络设置：虚拟 IP + 只把 DNS 地址路由进隧道（轻量模式，正常流量不经过隧道）
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: Shared.tunnelIP)
        let ipv4 = NEIPv4Settings(addresses: [Shared.tunnelIP], subnetMasks: ["255.255.255.255"])

        var routed: [String] = [Shared.virtualDNS]
        let hijack = d.object(forKey: Shared.keyHijackPublic) as? Bool ?? true
        if hijack {
            // 劫持硬编码公共 DNS，防 App 绕过；当前上游永远排除在外防回环
            routed += Shared.publicDNSHijack.filter { $0 != upstreamStr }
        }
        ipv4.includedRoutes = routed.map {
            NEIPv4Route(destinationAddress: $0, subnetMask: "255.255.255.255")
        }
        settings.ipv4Settings = ipv4
        settings.dnsSettings = NEDNSSettings(servers: [Shared.virtualDNS])

        setTunnelNetworkSettings(settings) { [weak self] error in
            if let error = error {
                completionHandler(error)
                return
            }
            self?.openUpstream()
            self?.startReading()
            completionHandler(nil)
        }
    }

    override func stop(completionHandler: @escaping () -> Void) {
        stats.flush()
        connection?.cancel()
        completionHandler()
    }

    // MARK: - 上游链路

    private func openUpstream() {
        let conn = NWConnection(host: upstream, port: 53, using: .udp)
        connection = conn
        conn.stateUpdateHandler = { [weak self] state in
            if case .failed = state, let self = self {
                // 上游断了：重连一次
                self.openUpstream()
            }
        }
        conn.start(queue: .global(qos: .userInitiated))
        receiveLoop()
    }

    private func receiveLoop() {
        connection?.receiveMessage { [weak self] data, _, isComplete, error in
            guard let self = self else { return }
            defer { self.receiveLoop() }
            guard error == nil, isComplete, let data = data, data.count >= 12 else { return }
            let resp = [UInt8](data)
            let id = UInt16(resp[0]) << 8 | UInt16(resp[1])
            guard let p = self.pendingQueries.removeValue(forKey: id) else { return }
            self.pendingCount = max(0, self.pendingCount - 1)
            let answer = DNSMessage.rewriteID(resp, to: p.origID)
            self.writeToClient(clientIP: p.clientIP, clientPort: p.clientPort, dnsPayload: answer)
        }
    }

    // MARK: - 客户端包循环

    private func startReading() {
        packetFlow.readPackets { [weak self] packets, _ in
            guard let self = self else { return }
            for data in packets {
                self.handlePacket([UInt8](data))
            }
            self.startReading()
        }
    }

    private func handlePacket(_ pkt: [UInt8]) {
        // IPv4 头解析
        guard pkt.count >= 28, pkt[0] >> 4 == 4 else { return }
        let ihl = Int(pkt[0] & 0x0F) * 4
        guard ihl >= 20, pkt.count > ihl + 8 else { return }
        guard pkt[9] == 17 else { return }                          // 只处理 UDP（v1 不管 TCP DNS）
        let srcIP = Array(pkt[12...15])
        let srcPort = UInt16(pkt[ihl]) << 8 | UInt16(pkt[ihl + 1])
        let dstPort = UInt16(pkt[ihl + 2]) << 8 | UInt16(pkt[ihl + 3])
        guard dstPort == 53 else { return }                          // 只处理 DNS

        let dnsBytes = Array(pkt[(ihl + 8)...])
        guard let msg = DNSMessage(packet: dnsBytes), let domain = msg.qname, !msg.isResponse else { return }

        // 总闸：开着 = 一切直通
        let masterOn = Shared.defaults.object(forKey: Shared.keyMasterOn) as? Bool ?? false

        if !masterOn && blocklist.isBlocked(domain: domain) {
            stats.record(blocked: true, domain: domain)
            writeToClient(clientIP: srcIP, clientPort: srcPort, dnsPayload: msg.nxDomainResponse())
        } else {
            stats.record(blocked: false, domain: domain)
            forwardToUpstream(clientIP: srcIP, clientPort: srcPort, message: msg)
        }
    }

    private func forwardToUpstream(clientIP: [UInt8], clientPort: UInt16, message: DNSMessage) {
        // 并发上限 64：超出直接丢弃，客户端自己会超时重试
        guard pendingCount < 64 else { return }
        let key = freeID()
        pendingQueries[key] = (clientIP, clientPort, message.transactionID, Date())
        pendingCount += 1
        var out = message.bytes
        out[0] = UInt8(key >> 8)
        out[1] = UInt8(key & 0xFF)
        connection?.send(content: Data(out), completion: .contentProcessed { _ in })

        // 8 秒超时清理（响应先到则 removeValue 拿到 nil，不会重复扣减）
        DispatchQueue.global().asyncAfter(deadline: .now() + 8) { [weak self] in
            if self?.pendingQueries.removeValue(forKey: key) != nil {
                self?.pendingCount = max(0, (self?.pendingCount ?? 1) - 1)
            }
        }
    }

    private func freeID() -> UInt16 {
        for _ in 0..<65536 {
            idCursor = idCursor &+ 1
            if pendingQueries[idCursor] == nil { return idCursor }
        }
        return idCursor
    }

    // MARK: - 应答回写（手工造 IP+UDP 头）

    private func writeToClient(clientIP: [UInt8], clientPort: UInt16, dnsPayload: [UInt8]) {
        var ip = [UInt8](repeating: 0, count: 20)
        ip[0] = 0x45                              // IPv4, 头长 20
        let totalLen = 20 + 8 + dnsPayload.count
        ip[2] = UInt8(totalLen >> 8); ip[3] = UInt8(totalLen & 0xFF)
        ip[6] = 0x40                              // Don't Fragment
        ip[8] = 64                                // TTL
        ip[9] = 17                                // UDP
        ip.replaceSubrange(12...15, with: [198, 18, 0, 2])   // 源 = 虚拟 DNS
        ip.replaceSubrange(16...19, with: clientIP)          // 目的 = 查询方
        let checksum = ipChecksum(ip)
        ip[10] = UInt8(checksum >> 8); ip[11] = UInt8(checksum & 0xFF)

        var udp = [UInt8](repeating: 0, count: 8)
        udp[0] = 0; udp[1] = 53
        udp[2] = UInt8(clientPort >> 8); udp[3] = UInt8(clientPort & 0xFF)
        udp[4] = UInt8((8 + dnsPayload.count) >> 8); udp[5] = UInt8((8 + dnsPayload.count) & 0xFF)
        udp[6] = 0; udp[7] = 0                    // UDP 校验和置 0（IPv4 合法）

        packetFlow.writePackets([Data(ip + udp + dnsPayload)], withProtocols: [NSNumber(value: AF_INET)])
    }

    private func ipChecksum(_ data: [UInt8]) -> UInt16 {
        var sum: UInt32 = 0
        var i = 0
        while i + 1 < data.count {
            sum += UInt32(data[i]) << 8 | UInt32(data[i + 1])
            i += 2
        }
        if i < data.count { sum += UInt32(data[i]) << 8 }
        while sum >> 16 != 0 { sum = (sum & 0xFFFF) + (sum >> 16) }
        return UInt16(~sum & 0xFFFF)
    }
}
