import SwiftUI

/// 拦截榜：按域名排序的统计明细（可搜索）
struct DomainListView: View {
    @EnvironmentObject var stats: StatsStore
    @State private var query = ""

    private var filtered: [(domain: String, count: Int)] {
        if query.isEmpty { return stats.topDomains }
        return stats.topDomains.filter { $0.domain.contains(query.lowercased()) }
    }

    var body: some View {
        NavigationView {
            List {
                if filtered.isEmpty {
                    Text("暂无数据——隧道开启后所有被拦截的域名会在这里排队")
                        .foregroundColor(.secondary)
                }
                ForEach(filtered, id: \.domain) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.domain)
                                .font(.system(.subheadline, design: .monospaced))
                            Text("\(item.count) 次")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "nosign")
                            .foregroundColor(.red.opacity(0.6))
                    }
                }
            }
            .searchable(text: $query, prompt: "搜域名")
            .navigationTitle("拦截榜")
        }
    }
}
