import SwiftUI

/// 设置：上游 DNS 选择 / 公共 DNS 劫持 / 关于与账本说明
struct SettingsView: View {
    @State private var upstream: String = Shared.defaultUpstream
    @State private var hijack: Bool = true
    @State private var lastActive: String = "—"

    var body: some View {
        NavigationView {
            List {
                Section {
                    Picker("上游 DNS", selection: $upstream) {
                        ForEach(Array(Shared.upstreamPool.keys), id: \.self) { ip in
                            Text("\(Shared.upstreamPool[ip] ?? ip) · \(ip)").tag(ip)
                        }
                    }
                    Toggle("劫持硬编码公共 DNS", isOn: $hijack)
                } header: {
                    Text("解析链路")
                } footer: {
                    Text("劫持开关：把 8.8.8.8 等常见硬编码 DNS 一并引入隧道，防止 App 绕过清屏；当前选中的上游永远不劫持，避免回环")
                }

                Section {
                    LabeledRow("版本", "1.0 · 断粮式拦截")
                    LabeledRow("引擎", "本地 DNS 过滤隧道（NEPacketTunnel）")
                    LabeledRow("统计数据", "仅存本机沙盒，不上传任何服务器")
                    LabeledRow("最近拦截活动", lastActive)
                } header: {
                    Text("账本")
                } footer: {
                    Text("全透明账本：源码每一行可审计，DNS 记录只进本机 App Group 容器，出事能定位到行号")
                }
            }
            .navigationTitle("设置")
            .onAppear {
                upstream = Shared.defaults.string(forKey: Shared.keyUpstreamDNS) ?? Shared.defaultUpstream
                hijack = Shared.defaults.object(forKey: Shared.keyHijackPublic) as? Bool ?? true
                refreshLastActive()
            }
            .onChange(of: upstream) { v in
                Shared.defaults.set(v, forKey: Shared.keyUpstreamDNS)
            }
            .onChange(of: hijack) { v in
                Shared.defaults.set(v, forKey: Shared.keyHijackPublic)
            }
        }
    }

    private func refreshLastActive() {
        if let t = Shared.defaults.object(forKey: Shared.keyLastActive) as? TimeInterval {
            let f = DateFormatter()
            f.dateFormat = "MM-dd HH:mm:ss"
            lastActive = f.string(from: Date(timeIntervalSince1970: t))
        }
    }
}

struct LabeledRow: View {
    let title: String
    let value: String
    init(_ t: String, _ v: String) { title = t; value = v }
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
                .font(.system(.subheadline, design: .monospaced))
        }
    }
}
