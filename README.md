# 清屏 · iOS 广告断粮器

**一句话**：本地 DNS 过滤隧道——把广告域名"断粮"（DNS 层面回 NXDOMAIN），开屏广告拉不到内容就不显示；带按域名的拦截统计面板。

**这是什么形态**：完整 Xcode 工程（SwiftUI 主 App + NetworkExtension 隧道扩展），在 Mac 上编译即得 .ipa，可侧载可 TestFlight。

---

## 建筑结构

```
App（主应用，SwiftUI）
 ├─ 仪表盘：隧道开关 / 总闸 / 今日拦截 / 七日柱状图
 ├─ 拦截榜：按域名统计明细（可搜索）
 ├─ 规则：内置清单查看 + 自定义后缀 + 批量导入
 └─ 设置：上游 DNS / 公共 DNS 劫持 / 账本说明

Extension（隧道扩展，NEPacketTunnelProvider）
 ├─ 只把虚拟 DNS(198.18.0.2) + 公共 DNS 劫持路由进隧道
 ├─ 所有 DNS 查询流经这里：命中清单→回 NXDOMAIN；未命中→转发上游
 └─ 统计落盘到 App Group（2 秒节流）+ Darwin 通知唤醒 UI

Shared（两 target 共用）
 ├─ SharedConfig：常量与键名
 ├─ StarterBlocklist：内置 ~300 条 CN 广告/追踪域名
 └─ SharedStats：统计写入器 + Darwin 通知中心
```

**轻量模式原理**：正常流量（淘宝下单、视频、游戏）**不进隧道**——只有 DNS 查询进来。零额外延迟、几乎零电耗。代价：App 内硬编码 DoH（HTTPS DNS）的流量绕过过滤器（已知限制，AdGuard 同款）。

---

## 怎么编译成 ipa（最后一公里）

### 路线 A：本机 Mac
1. 装 XcodeGen：`brew install xcodegen`
2. 进项目目录：`xcodegen generate`（生成 .xcodeproj）
3. `open 清屏.xcodeproj`，选自己的 Apple ID（Settings → Signing，两 target 都选 Personal Team）
4. 真机连 USB，Run——首次会弹"添加 VPN 配置"，按指纹确认
5. 导出 ipa：Product → Archive → Distribute App → Custom → Development Signing，得到 .ipa

### 路线 B：没有 Mac（GitHub Actions 云端编译）
把仓库推到 GitHub，把 `.github/workflows/build.yml` 里的 secrets 配好（证书 p12 + 描述文件，或用免费号的 CI 签名方案），push 一次自动产出 ipa 附件下载。

### 路线 C：免费签名自用（7 天一续）
编译出的 ipa 用 **Sideloadly**（Windows/Mac 都有）+ 自己的 Apple ID 重签直装；你的新 iOS 直装未知来源 ipa 的开关打开的话，重签后的包直接设备上安装。

---

## 风险报表（全透明账本）

| 风险项 | 状态 |
|---|---|
| 恶意代码 | 信任链闭合：源码你读、你签名、你设备——无未知作者 |
| 规则写崩断网 | **总闸**一键直通（设置页/仪表盘），或直接关隧道 |
| 上游 DNS 故障 | 隧道自动重连；换上游在设置页四选一 |
| DNS 记录泄露 | 统计只写本机 App Group 沙盒，无任何上传代码 |
| 并发过载 | 64 并发上限，超出丢包让系统自己重试 |
| 表膨胀 | 日统计留 30 天 / 域名榜留 500 条，自动裁剪 |

## 已知限制（诚实清单）
- App 硬编码 DoH 绕过（抖音等大厂部分流量）——iOS 无解，AdGuard 同款
- TCP/53 罕见路径未处理（v1）
- 统计按域名而非按 App 归因——iOS 隐私墙所限，系统不告诉扩展"是谁在问"
- 内置 ~300 条是入门弹药；全量火力去规则页导入 EasyListChina 域名表

## 行号级审计指南（验我的方法）
1. 拦截判决逻辑：`Extension/BlocklistStore.swift` 的 `isBlocked(domain:)`
2. DNS 报文真伪：`Extension/DNSMessage.swift`（RFC 1035，40 行小解析器）
3. 有没有偷偷联网：全局搜 `URLSession` / `NWConnection`——只有上游 DNS 一条（`PacketTunnelProvider.swift`）
4. 有没有上传数据：全局搜 `upload` / `POST`——零命中
