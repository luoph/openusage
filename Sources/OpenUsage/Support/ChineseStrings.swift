import Foundation

/// Simplified Chinese strings, keyed by the English original (see `L10n`).
///
/// Scope is the everyday surface: dashboard cards, metric titles, the menu bar, Customize, and
/// Settings. Long-tail provider error copy is deliberately not translated yet — it falls through to
/// English, which is correct behavior, not a bug.
///
/// Conventions:
/// - Product and vendor names stay as-is (OpenUsage, Claude, Codex, Cursor, Pi, Sparkle, iCloud).
/// - Metric names match the wording already used by the local `openusage` skill's report script
///   (会话 / 周额度 / 额外用量 / 总用量 …), so the app and that tool read the same.
/// - Units and symbols ($, %, tokens) are formatted in code and never appear here.
enum ChineseStrings {
    static let table: [String: String] = metrics
        .merging(dashboard) { current, _ in current }
        .merging(settings) { current, _ in current }
        .merging(options) { current, _ in current }

    // MARK: - Metric titles (provider-produced, translated at display time)

    private static let metrics: [String: String] = [
        "Session": "会话",
        "Weekly": "周额度",
        "Daily": "日额度",
        "Monthly": "月额度",
        "Today": "今天",
        "Yesterday": "昨天",
        "Last 30 Days": "最近 30 天",
        "Last 4 Weeks": "最近 4 周",
        "This Week": "本周",
        "This Month": "本月",
        "Usage Trend": "用量趋势",
        "Total Usage": "总用量",
        "Extra Usage": "额外用量",
        "Extra Balance": "额外余额",
        "Balance": "余额",
        "Requests": "请求",
        "Key Limit": "Key 限额",
        "Rate Limit Resets": "速率重置",
        "Web Searches": "网页搜索",
        "Org Credits": "组织额度",
        "Org Spend": "组织花费",
        "Spark Weekly": "Spark 周额度",
        "Cursor Models": "Cursor 模型",
        "Other Models": "其他模型"
    ]

    // MARK: - Dashboard, menu bar, Customize

    private static let dashboard: [String: String] = [
        "No data": "无数据",
        "no data": "无数据",
        "Refreshing": "刷新中",
        "Refresh now (⌘R)": "立即刷新（⌘R）",
        "Customize": "自定义",
        "Customize…": "自定义…",
        "Settings": "设置",
        "Quit OpenUsage": "退出 OpenUsage",
        "About OpenUsage": "关于 OpenUsage",
        "Share Screenshot": "分享截图",
        "Update Available": "有可用更新",
        "Welcome to OpenUsage": "欢迎使用 OpenUsage",
        "Monitor Your AI Subscriptions with OpenUsage": "用 OpenUsage 监控你的 AI 订阅用量",
        "Choose what's visible and where": "选择显示哪些内容、显示在哪里",
        "Notifications, appearance and more": "通知、外观等设置",
        "No Enabled Providers": "没有启用的服务商",
        "No metrics to show": "没有可显示的指标",
        "Drag metrics here": "把指标拖到这里",
        "Turn on Customize to choose what to show.": "打开自定义来选择显示内容。",
        "Always Visible": "始终显示",
        "On Demand": "按需显示",
        "Reset All": "全部重置",
        "Reset All Customization": "重置所有自定义",
        "Total Spend": "总花费",
        "Total Spend Metric": "总花费指标",
        "No spend data": "无花费数据",
        "No cost data for this period": "该时间段没有成本数据",
        "No cost-per-token data for this period": "该时间段没有单位成本数据",
        "No token data for this period": "该时间段没有 token 数据",
        "This period used a model with unknown pricing": "这个时间段用到了价格未知的模型",
        "You have no rate limit resets": "你没有可用的速率重置",
        "Expiry times unavailable": "过期时间不可用",
        "Use this reset?": "使用这次重置？",
        "Immediately reset your usage limits. This can't be undone.": "立即重置用量额度。此操作无法撤销。",
        "Resetting your usage…": "正在重置用量…",
        "Back": "返回",
        "Hide": "隐藏",
        "Dismiss": "忽略",
        "Options": "选项",
        "Cancel": "取消",
        "Save": "保存",
        "Use": "使用",
        "Reset": "重置",
        "None": "无",
        "Unavailable": "不可用"
    ]

    // MARK: - Settings

    private static let settings: [String: String] = [
        "General": "通用",
        "Appearance": "外观",
        "Usage Display": "用量显示",
        "Notifications": "通知",
        "Privacy": "隐私",
        "Command Line": "命令行",
        "Advanced": "高级",
        "Updates": "更新",
        "iCloud Sync": "iCloud 同步",

        "Language": "语言",
        "Launch at Login": "登录时启动",
        "Global Shortcut": "全局快捷键",
        "Open OpenUsage from anywhere": "在任何地方唤出 OpenUsage",
        "Record Shortcut": "录制快捷键",
        "Clear Shortcut": "清除快捷键",
        "Type Shortcut…": "按下快捷键…",
        "Show Total Spend": "显示总花费",

        "Icon Style": "图标样式",
        "Theme": "主题",
        "Density": "密度",
        "Reduce Animations": "减少动效",
        "Time Format": "时间格式",
        "Increase Transparency": "增加透明度",
        "Party Mode": "派对模式",
        "Drunk Mode": "微醺模式",
        "Party mode is on, so this stays paused.": "派对模式开启中，此项暂停。",
        "macOS Reduce Transparency or Increase Contrast is on, so this stays paused.":
            "macOS 的“降低透明度”或“增强对比度”已开启，此项暂停。",
        "macOS Reduce Transparency or Increase Contrast is on, so the party stays paused.":
            "macOS 的“降低透明度”或“增强对比度”已开启，派对模式暂停。",

        "Show Usage As": "用量显示方式",
        "Always Show Pacing": "始终显示进度",
        "Show how you're pacing on every metric, not just ones near their limit":
            "在所有指标上显示用量进度，而不只是接近上限的那些",
        "Reset Times": "重置时间",

        "Hide From Screen Share": "屏幕共享时隐藏",
        "Help make OpenUsage better by sharing anonymous usage analytics":
            "分享匿名使用数据，帮助改进 OpenUsage",

        "Terminal Helper": "终端工具",
        "Install…": "安装…",
        "Uninstall": "卸载",
        "Adds a global `openusage` command agents can use to monitor limits.":
            "添加全局 openusage 命令，供 agent 查询额度。",

        "Log Level": "日志级别",
        "Copy Log Path": "复制日志路径",
        "Reveal in Finder": "在访达中显示",
        "Reset All Settings…": "重置所有设置…",
        "Cost Estimates": "成本估算",
        "Fallback Model": "回落模型",
        "Estimate costs for models that don't have known pricing.": "为没有已知价格的模型估算成本。",
        "Unavailable Model": "不可用的模型",
        "This model's pricing is unavailable. Choose another model or None.":
            "该模型的价格不可用。请选择其他模型或“无”。",

        "Check for Updates…": "检查更新…",
        "Update Automatically": "自动更新",
        "Beta Updates": "Beta 版更新",
        "Receive pre-release builds before they ship to everyone": "抢先获取正式发布前的预览版本",

        "Sync Across Macs": "跨 Mac 同步",
        "This Mac": "这台 Mac",
        "Syncing usage history": "正在同步用量历史",
        "Waiting for this Mac’s first iCloud update…": "等待这台 Mac 的首次 iCloud 更新…"
    ]

    // MARK: - Setting option labels

    private static let options: [String: String] = [
        "Automatic": "自动",
        "System": "跟随系统",
        "Light": "浅色",
        "Dark": "深色",
        "Default": "默认",
        "Compact": "紧凑",
        "Auto": "自动",
        "Bars": "条形",
        "Text": "文字",
        "Left": "靠左",
        "Exact Time": "具体时间",
        "Countdown": "倒计时",
        "Used": "已用",
        "Remaining": "剩余",
        "Limit reached": "已达上限",
        "Not started": "未开始",
        "Refresh failed": "刷新失败"
    ]
}
