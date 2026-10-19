import Foundation

/// 内置精简拦截清单——后缀匹配规则
/// 说明：这是"拿到就能用"的入门弹药（约 300 条主流 CN 广告/追踪域名）
/// 完整火力在 App 内"规则"页粘贴导入 EasyListChina 域名表（每行一条）
enum StarterBlocklist {

    struct Category {
        let name: String
        let domains: [String]
    }

    static let categories: [Category] = [
        Category(name: "广告联盟（开屏/横幅主力）", domains: [
            // 腾讯广点通系
            "gdt.qq.com", "mi.gdt.qq.com", "win.gdt.qq.com", "adsmind.ugdtimg.com", "ugdtimg.com",
            // 字节/穿山甲系
            "ad.toutiao.com", "ads.toutiao.com", "dsp.toutiao.com", "pangolin-sdk-toutiao.com",
            "ad.bytedance.com", "ad.oceanengine.com", "sf1-tkcdn-toutiao.com", "csjplatform.com",
            // 快手/百度联盟
            "ad.kuaishou.com", "ssp.kuaishou.com", "union.baidu.com", "cpro.baidu.com",
            "pos.baidu.com", "afd.baidu.com", "gsp.baidu.com", "wangmeng.baidu.com",
            // 国际联盟
            "doubleclick.net", "googlesyndication.com", "googleadservices.com", "admob.com",
            "applovin.com", "adcolony.com", "inmobi.com", "mopub.com", "chartboost.com",
            "unityads.unity3d.com", "vungle.com", "tapjoy.com", "ironsrc.com", "appsflyer.com",
            "adform.net", "adroll.com", "criteo.com", "pubmatic.com", "rubiconproject.com",
            "openx.net", "smartadserver.com", "casalemedia.com", "adtech.de", "yieldmo.com",
            "mediav.com", "ipinyou.com", "madhouse.cn", "domob.cn", "vamaker.com",
            "adview.cn", "adsame.com", "admaster.com.cn", "adkmob.com", "duomeng.cn",
            "anqu.com", "youdao.com", "duapps.com", "wiad.cn", "qchannel01.cn",
            "whytouch.com", "url.alibabaplus.cn", "mads.tanx.com", "tanzx.com",
        ]),
        Category(name: "统计与追踪 SDK", domains: [
            "umeng.com", "umeng.co", "umengcloud.com", "umtrack.com", "umengta.com",
            "cnzz.com", "51.la", "51yes.com", "growing.io", "growingio.com",
            "sensorsdata.cn", "sensorsdata.com", "appsee.com", "hotjar.com",
            "mixpanel.com", "amplitude.com", "segment.io", "branch.io", "kochava.com",
            "talkingdata.com", "udrig.com", "shuzilm.cn",
            "mtj.baidu.com", "hm.baidu.com", "log.baidu.com", "analytics.163.com",
            "a.stat.baidu.com", "nsclick.baidu.com", "track.ucweb.com", "huichuan.sm.cn",
            "beacon.tingyun.com", "tingyun.com", "monitor.tingyun.com",
            "sdk.e.qq.com", "report.qq.com", "log.toutiao.com", "tracker.toutiao.com",
            "applog.toutiao.com", "applog.snssdk.com", "log.snssdk.com",
            "gtag.cn", "analytics.google.com", "google-analytics.com", "googletagmanager.com",
        ]),
        Category(name: "推广/升级/推送域名", domains: [
            "aop.openrct.cn", "sm.domob.cn", "promotion.feng.com", "apk.stemcell.com.cn",
            "update.9555.com", "dip.nie.ele.me", "upgrade.365taoquan.com",
            "push.igexin.com", "sdk.open.igexin.com", "getui.com", "jpush.cn",
            "api.jpush.cn", "push.jpush.cn", "xg.qq.com", "openinstall.io",
        ]),
        Category(name: "开屏常见 CDN 与静态广告位", domains: [
            "cdn.lfzclzprg.cn", "s1.jump2just.com", "adash-c.ut.taobao.com",
            "adashx.m.taobao.com", "acs4baichuan.m.taobao.com", "amdc.m.taobao.com",
            "gm.mmstat.com", "mmstat.com", "ynuf.alipay.com",
            "gma.alicdn.com", "promotion.alicdn.com", "imp.m.sm.cn", "jump.m.sm.cn",
            "a.market.178.com", "ad.17173.com", "imp.g.163.com", "g.163.com",
            "n.dcs.pconline.com.cn", "jsadcode1.pconline.com.cn", "ad.pptv.com",
            "sugar.zhihu.com", "appcloud2.zhihu.com", "zhihu-web-analytics.zhihu.com",
        ]),
        Category(name: "风险与低信誉域名", domains: [
            "gps.cell-com.cn", "push.chenxi.net", "s.idcpcloud.cn",
            "sunkwan.com", "tkgc.qq.com", "otherdata.ksjws.cn",
        ]),
    ]

    /// 展平的完整后缀清单
    static var allSuffixes: [String] {
        var set = Set<String>()
        for c in categories {
            for d in c.domains where !d.isEmpty {
                set.insert(d.lowercased())
            }
        }
        return Array(set)
    }
}
