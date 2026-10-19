import SwiftUI

/// 规则管理：自定义拦截后缀 + 批量导入（EasyListChina 域名粘贴导入）
struct RulesView: View {
    @State private var customRules: [String] = []
    @State private var newRule = ""
    @State private var importText = ""
    @State private var showImporter = false
    @State private var toast: String?

    private var starterCount: Int { StarterBlocklist.allSuffixes.count }

    var body: some View {
        NavigationView {
            List {
                Section {
                    HStack {
                        Image(systemName: "shippingbox")
                        Text("内置清单：\(starterCount) 条主流广告/追踪域名")
                    }
                    .font(.subheadline)
                } header: {
                    Text("内置规则（只读）")
                }

                Section {
                    ForEach(customRules, id: \.self) { rule in
                        Text(rule)
                            .font(.system(.subheadline, design: .monospaced))
                    }
                    .onDelete { idx in
                        customRules.remove(atOffsets: idx)
                        save()
                    }
                    HStack {
                        TextField("例：ads.example.com", text: $newRule)
                            .font(.system(.subheadline, design: .monospaced))
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                        Button("添加") {
                            let r = newRule.lowercased().trimmingCharacters(in: .whitespaces)
                            guard !r.isEmpty, !customRules.contains(r) else { return }
                            customRules.append(r)
                            newRule = ""
                            save()
                        }
                        .disabled(newRule.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                } header: {
                    Text("自定义拦截（后缀匹配，立即生效）")
                } footer: {
                    Text("命中规则：域名本身或任意子域。例：填 gdt.qq.com 则 mi.gdt.qq.com 一并拦截")
                }

                Section {
                    Button {
                        showImporter = true
                    } label: {
                        Label("批量导入域名清单", systemImage: "square.and.arrow.down")
                    }
                    Text("把 EasyListChina 的域名列表（每行一条）粘贴进来即可上全量火力")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } header: {
                    Text("导入")
                }
            }
            .navigationTitle("规则")
            .onAppear {
                customRules = Shared.defaults.stringArray(forKey: Shared.keyCustomRules) ?? []
            }
            .sheet(isPresented: $showImporter) {
                NavigationView {
                    VStack(spacing: 12) {
                        TextEditor(text: $importText)
                            .font(.system(.body, design: .monospaced))
                            .frame(minHeight: 300)
                            .padding(8)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(12)
                            .padding()
                        Button {
                            let lines = importText
                                .split(separator: "\n")
                                .map { $0.lowercased().trimmingCharacters(in: .whitespaces) }
                                .filter { !$0.isEmpty && !$0.contains(" ") }
                            let added = lines.filter { !customRules.contains($0) }
                            customRules.append(contentsOf: added)
                            save()
                            toast = "导入 \(added.count) 条"
                            showImporter = false
                            importText = ""
                        } label: {
                            Text("导入")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.horizontal)
                        .padding(.bottom)
                    }
                    .navigationTitle("批量导入")
                    .navigationBarTitleDisplayMode(.inline)
                }
            }
            .overlay(alignment: .bottom) {
                if let t = toast {
                    Text(t)
                        .font(.footnote)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(.thinMaterial))
                        .padding(.bottom, 20)
                        .task {
                            try? await Task.sleep(nanoseconds: 1_800_000_000)
                            withAnimation { toast = nil }
                        }
                }
            }
        }
    }

    private func save() {
        Shared.defaults.set(customRules, forKey: Shared.keyCustomRules)
    }
}
