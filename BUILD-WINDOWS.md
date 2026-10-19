# Windows 端最快路线（全程约 30 分钟）

## 为什么必须走云端编译
Xcode 只活在 macOS 里——Windows 和 iPhone 都跑不了它；所以编译这步交给 GitHub Actions 的免费 macos 云机器，你的 Windows 只负责**推代码 + 签名装机**最后两步

## 第 1 步：建仓库推代码（约 5 分钟，一次性）
1. GitHub 上 New repository，名字随意（比如 `clearscreen`），选 **Public**（macos 云机器对公开仓库免费，私有仓库要扣额度）
2. 二选一：
   - **GitHub Desktop**（图形界面，最省事）：Add → Add Local Repository → 把 zip 解压后的 **qingping 文件夹里的内容**作为仓库根目录（App/、Extension/、project.yml 等直接在根上）→ Commit → Push
   - **命令行**：解压 zip，进 qingping 目录，依次跑：
     ```
     git init
     git add .
     git commit -m "清屏 v1.0"
     git branch -M main
     git remote add origin https://github.com/你的用户名/clearscreen.git
     git push -u origin main
     ```
   ⚠️ 注意：`.github/workflows/build.yml` 必须在**仓库根目录**下才生效——也就是把 qingping **里面的内容**当根推，不是把 qingping 文件夹整个推进去

## 第 2 步：云编译（约 10-15 分钟，全自动）
推上去 Actions 自动开跑（也可手动：仓库页 Actions 标签 → build-ipa → Run workflow）；跑完后在该次运行页面底部 **Artifacts** 区下载 `清屏-unsigned-ipa`——里面是未签名的 ipa

## 第 3 步：重签 + 装机（约 5 分钟，JMC 同款流程）
1. Windows 装 [Sideloadly](http://sideloadly.io) + iTunes（要它的苹果驱动）
2. iPhone USB 连电脑
3. Sideloadly 里拖入 ipa → 填自己的 Apple ID → Start → 手机上输一次密码 → 等进度条走完
4. 首次打开 App → 开隧道 → iOS 弹"添加 VPN 配置"→ 指纹确认——完事

## 免费号注意事项
- 免费签名 **7 天过期**：过期后 App 打不开，回 Sideloadly 再签一次即可（数据都在 App Group 里，不会丢）
- Apple ID 填的是"专用密码"生成入口的普通密码都行，Sideloadly 会引导；被苹果风控拦截就换时间段再试

## 想先做个 10 分钟的便宜实验？
直接把 CI 产出的 **unsigned ipa** 用你 iOS 的未知来源直装开关装一次——理论上会被签名墙拒绝（无签名 = 无人担保），但万一你这版系统连无签名包都吃，整个流程就砍到 15 分钟；失败了再回第 3 步走 Sideloadly，不亏
