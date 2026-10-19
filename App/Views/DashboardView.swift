import SwiftUI
import NetworkExtension

/// 仪表盘：总闸开关 + 今日拦截 + 七日柱状图 + 状态
struct DashboardView: View {
    @EnvironmentObject var stats: StatsStore
    @EnvironmentObject var vpn: VPNManager

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 隧道开关
                    tunnelCard

                    // 总闸（直通模式）
                    masterSwitchCard

                    // 今日拦截大数字
                    VStack(spacing: 4) {
                        Text("\(stats.todayBlocked)")
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                            .foregroundColor(.accentColor)
                        Text("今日拦截")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))

                    // 七日图（手绘柱状，无第三方依赖）
                    weekChart

                    // 汇总
                    HStack {
                        statCell("累计拦截", "\(stats.totalBlocked)")
                        statCell("累计查询", "\(stats.totalQuery)")
                        statCell("拦截率", stats.blockRate.map { String(format: "%.1f%%", $0) } ?? "—")
                    }
                }
                .padding()
            }
            .navigationTitle("清屏")
        }
    }

    private var tunnelCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("拦截隧道")
                    .font(.headline)
                Text(statusText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { vpn.status == .connected || vpn.status == .connecting },
                set: { on in
                    if on { vpn.start() } else { vpn.stop() }
                }))
                .labelsHidden()
                .tint(.accentColor)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
    }

    private var statusText: String {
        switch vpn.status {
        case .connected: return "运行中 · 广告正在断粮"
        case .connecting: return "连接中…"
        case .disconnecting: return "断开中…"
        case .disconnected, .invalid: return "未启用"
        default: return "未知状态"
        }
    }

    private var masterSwitchCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("总闸 · 直通模式")
                    .font(.headline)
                Text("全部放行不拦截——规则出问题时一键救网")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Toggle("", isOn: $stats.masterOn)
                .labelsHidden()
                .tint(.orange)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
    }

    private var weekChart: some View {
        let maxV = max(1, stats.daily.map(\.count).max() ?? 1)
        return VStack(alignment: .leading, spacing: 8) {
            Text("近七日")
                .font(.headline)
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(stats.daily, id: \.day) { item in
                    VStack(spacing: 4) {
                        Text("\(item.count)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.accentColor.opacity(0.85))
                            .frame(height: max(6, CGFloat(item.count) / CGFloat(maxV) * 100))
                        Text(String(item.day.suffix(5)))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
                if stats.daily.isEmpty {
                    Text("隧道跑起来之后这里会长出柱子")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 40)
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
    }

    private func statCell(_ title: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.title3.bold())
            Text(title).font(.caption2).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
    }
}
