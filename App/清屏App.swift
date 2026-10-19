import SwiftUI

@main
struct ClearScreenApp: App {
    @StateObject private var stats = StatsStore()
    @StateObject private var vpn = VPNManager()

    var body: some Scene {
        WindowGroup {
            TabView {
                DashboardView()
                    .tabItem { Label("仪表盘", systemImage: "shield") }
                DomainListView()
                    .tabItem { Label("拦截榜", systemImage: "list.bullet.rectangle") }
                RulesView()
                    .tabItem { Label("规则", systemImage: "doc.text.magnifyingglass") }
                SettingsView()
                    .tabItem { Label("设置", systemImage: "gearshape") }
            }
            .environmentObject(stats)
            .environmentObject(vpn)
            .preferredColorScheme(.dark)
        }
    }
}
