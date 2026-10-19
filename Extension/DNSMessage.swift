import Foundation

/// 极简 DNS 报文解析器——只读问题段（QNAME/QTYPE），够拦截用
/// 字节级协议代码，改这里之前先看 RFC 1035 第 4.1 节
struct DNSMessage {
    let bytes: [UInt8]
    var transactionID: UInt16 { UInt16(bytes[0]) << 8 | UInt16(bytes[1]) }
    var flags: UInt16 { UInt16(bytes[2]) << 8 | UInt16(bytes[3]) }
    var isResponse: Bool { flags & 0x8000 != 0 }
    var questionCount: UInt16 { UInt16(bytes[4]) << 8 | UInt16(bytes[5]) }
    /// 问题段里的域名（点分小写），解析失败返回 nil
    let qname: String?
    /// 问题段偏移（字节）
    let questionStart: Int
    var qtype: UInt16 { qname == nil ? 0 : readU16(questionStart + qnameLen) }
    private let qnameLen: Int

    init?(packet: [UInt8]) {
        // DNS 头 12 字节 + 至少一个问题段
        guard packet.count >= 17 else { return nil }
        bytes = packet
        let headerLen = 12
        var labels: [String] = []
        var i = headerLen
        // 遍历标签：长度前缀，0 结尾，最大 255 字节域名防越界
        while i < packet.count {
            let len = Int(packet[i])
            if len == 0 {
                i += 1
                break
            }
            // 长度高位两 bit 是压缩指针（0xC0）——查询段一般不出现，防炸直接当解析失败
            if len & 0xC0 != 0 { return nil }
            let start = i + 1
            guard start + len <= packet.count else { return nil }
            labels.append(String(decoding: packet[start..<(start + len)], as: UTF8.self))
            i = start + len
        }
        qnameLen = i - headerLen
        questionStart = headerLen
        qname = labels.isEmpty ? nil : labels.joined(separator: ".").lowercased()
    }

    private func readU16(_ off: Int) -> UInt16 {
        guard off + 1 < bytes.count else { return 0 }
        return UInt16(bytes[off]) << 8 | UInt16(bytes[off + 1])
    }

    // MARK: - 响应构造

    /// 拦截应答：把原查询改写成 NXDOMAIN（域名不存在）
    /// 结构：头(12) + 复制原问题段 + 无应答记录
    func nxDomainResponse() -> [UInt8] {
        var out = bytes
        // QR=1 响应 / AA=1 / RD保留 / RA=1 / RCODE=3 (NXDOMAIN)
        out[2] = 0x81
        out[3] = 0x83
        // ANCOUNT=0, NSCOUNT=0, ARCOUNT=0
        out[6] = 0; out[7] = 0
        out[8] = 0; out[9] = 0
        out[10] = 0; out[11] = 0
        // 截掉问题段之后的所有内容
        let questionEnd = 12 + qnameLen + 4
        if questionEnd < out.count {
            out.removeSubrange(questionEnd..<out.count)
        }
        return out
    }

    /// 转发应答：把上游回来的响应 ID 改回客户端的 ID
    static func rewriteID(_ response: [UInt8], to id: UInt16) -> [UInt8] {
        guard response.count >= 12 else { return response }
        var out = response
        out[0] = UInt8(id >> 8)
        out[1] = UInt8(id & 0xFF)
        return out
    }
}
