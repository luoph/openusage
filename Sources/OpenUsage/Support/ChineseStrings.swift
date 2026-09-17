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
        // Total Spend's title menu and its period switcher. "30 Days" is the switcher's compact form
        // of "Last 30 Days" — three segments have to fit across the 320pt popover.
        "Cost": "花费",
        "Cost/MTok": "MTok 单价",
        "Tokens": "Token 数",
        "30 Days": "30 天",
        "No spend data": "无花费数据",
        "No cost data for this period": "该时间段没有成本数据",
        "No cost-per-token data for this period": "该时间段没有单位成本数据",
        "No token data for this period": "该时间段没有 token 数据",
        "This period used a model with unknown pricing": "这个时间段用到了价格未知的模型",

        // Hover-popover source notes: where a spend figure came from, and whether it is imputed.
        // Codex's multi-source note is assembled at runtime ("From your <a> and <b> (estimated)"),
        // so it has no fixed string to key on and stays English.
        "From your pi logs (estimated)": "来自你的 pi 日志（估算）",
        "From your Claude usage history (estimated)": "来自你的 Claude 用量历史（估算）",
        "From your Claude usage history and pi (estimated)": "来自你的 Claude 用量历史和 pi（估算）",
        "From your Codex logs (estimated)": "来自你的 Codex 日志（估算）",
        "From your Grok logs (estimated)": "来自你的 Grok 日志（估算）",
        "From your Antigravity conversations (estimated)": "来自你的 Antigravity 会话（估算）",
        "From your OpenCode logs": "来自你的 OpenCode 日志",
        "From your Cursor usage export": "来自你的 Cursor 用量导出",
        "From your Cursor usage history.": "来自你的 Cursor 用量历史。",
        "Estimated locally, so it may be off": "本地估算，可能有偏差",
        "You have no rate limit resets": "你没有可用的速率重置",
        "Expiry times unavailable": "过期时间不可用",
        "Use this reset?": "使用这次重置？",
        "Immediately reset your usage limits. This can't be undone.": "立即重置用量额度。此操作无法撤销。",
        "Resetting your usage…": "正在重置用量…",
        "Back": "返回",
        "Hide": "隐藏",
        // Right-click menus on a provider header and on a metric row. `%@` / `%d` are filled by
        // `L10n.format`, so the placeholder has to survive translation.
        "Hide %@": "隐藏 %@",
        "Refresh %@": "刷新 %@",
        "Star for menu bar": "固定到菜单栏",
        "Unstar": "取消固定",
        "%d metrics": "%d 个指标",
        "%d available": "%d 个可用",
        "Updated %@": "更新于 %@",
        "Dismiss": "忽略",
        "Options": "选项",
        "Cancel": "取消",
        "Save": "保存",
        "Use": "使用",
        "Reset": "重置",
        "None": "无",
        "Unavailable": "不可用",

        // Footer status and the update banner.
        "Updating…": "更新中…",
        "Next update in %dm": "%d 分钟后更新",
        "Next update in %ds": "%d 秒后更新",
        "Copied to clipboard": "已复制到剪贴板",
        "Install Update": "安装更新",
        "OpenUsage %@ is ready to download.": "OpenUsage %@ 已可下载。",

        // Customize: the transient pill shown after starring / unstarring a metric.
        "Starred for menu bar": "已固定到菜单栏",
        "Removed from menu bar": "已从菜单栏移除",
        "Up to 2 stars per provider": "每个服务商最多固定 2 项",
        "Show more": "展开",
        "Show less": "收起",
        "Reset All Customization?": "重置所有自定义？",

        // Codex reset credits (the resets popover).
        "Expiring soon": "即将过期",
        "Nothing to reset right now": "当前没有可重置的项",
        "Your usage doesn't need a reset yet": "你的用量还不需要重置",
        "Reset claimed. Enjoy!": "重置已领取，尽情使用！",
        "That reset is no longer available": "该重置已不可用",
        "Couldn't reset usage. Please try again.": "重置用量失败，请重试。"
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
        "Loading Models…": "正在加载模型…",
        "Recalculating Estimates…": "正在重新计算估算…",
        "Allow Notifications": "允许通知",
        "Open System Settings": "打开系统设置",
        "Reset All Settings?": "重置所有设置？",
        "Couldn't copy the log path to the clipboard.": "无法复制日志路径到剪贴板。",

        // Settings → API Keys (OpenRouter / Z.ai).
        "Override With a Custom Key": "使用自定义 Key 覆盖",
        "From Your Environment": "来自环境变量",
        "Saved in App": "已保存在应用内",
        "Custom Key": "自定义 Key",
        "Add": "添加",
        "Edit": "编辑",
        "Clear": "清除",
        "Show": "显示",
        "Done": "完成",
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
        // Relative age of the last sync, fed into "Updated %@".
        "just now": "刚刚",
        "%dm ago": "%d 分钟前",
        "%dh ago": "%d 小时前",
        "%dd ago": "%d 天前",
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
        // Hover copy on a meter: the pace projection, and the aged-snapshot hint beside a provider name.
        "Outdated": "已过期",
        "Reset %@": "重置 %@",
        "Unknown model found": "发现价格未知的模型",
        "Unknown models found": "发现多个价格未知的模型",
        "Alert when a limit drops below 10% remaining.": "额度剩余低于 10% 时提醒。",
        "Alert when a limit is projected to finish before it resets.": "预计额度在重置前用尽时提醒。",
        "Alert when a limit is projected to finish with little left.": "预计额度重置时所剩无几时提醒。",
        "Not started": "未开始",
        "Refresh failed": "刷新失败"
    ]
}
