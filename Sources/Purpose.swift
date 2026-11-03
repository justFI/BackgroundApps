import Foundation

enum Purpose {
    static func text(
        name: String,
        bundleID: String,
        executable: String,
        path: String,
        host: String?,
        kind: AppKind,
        isHidden: Bool,
        about: String?,
        category: String?
    ) -> String {
        if let curated = bundleText[bundleID] ?? executableText[URL(fileURLWithPath: executable).lastPathComponent] {
            return curated
        }
        if let structural = structural(
            name: name,
            bundleID: bundleID,
            executable: executable,
            path: path,
            host: host
        ) {
            return structural
        }
        if let about, about.compare(name, options: .caseInsensitive) != .orderedSame {
            return about
        }
        if let category, let label = categoryText[category] {
            return "开发者没有写功能简介。系统分类是「\(label)」。"
        }
        return fallback(kind: kind, isHidden: isHidden)
    }

    private static func structural(
        name: String,
        bundleID: String,
        executable: String,
        path: String,
        host: String?
    ) -> String? {
        if bundleID == "com.apple.WebKit.WebContent" {
            return "网页内容进程，负责渲染页面和运行页面脚本。名称里带有所属应用。"
        }
        if bundleID == "com.apple.WebKit.Networking" {
            return "网页网络进程，替所属应用收发页面请求。名称里带有所属应用。"
        }
        if bundleID == "com.apple.WebKit.GPU" {
            return "网页图形进程，替所属应用做页面里的图形加速。"
        }
        if bundleID == "com.apple.SafariPlatformSupport.Helper" {
            return host.map { "为「\($0)」提供密码、自动填充和网站兼容辅助。" }
                ?? "Safari 平台辅助进程，负责密码和自动填充。"
        }
        if path.contains("/Input Methods/")
            || bundleID.localizedCaseInsensitiveContains("inputmethod")
            || bundleID.localizedCaseInsensitiveContains("InputMethod") {
            return "输入法。在后台接收按键，把文字送到当前正在使用的应用。"
        }
        if URL(fileURLWithPath: executable).lastPathComponent == "node" {
            return "Node.js 进程。上面的名称是它正在执行的工具或脚本。"
        }
        if path.contains(".appex") {
            if bundleID.localizedCaseInsensitiveContains("widget") || name.localizedCaseInsensitiveContains("widget") {
                return owned(host, "的小组件，在桌面或通知中心显示内容。", bare: "小组件扩展，在桌面或通知中心显示内容。")
            }
            if bundleID.localizedCaseInsensitiveContains("QuickLook") || name.localizedCaseInsensitiveContains("Quick Look") {
                return owned(host, "的快速查看插件，在访达里按空格预览文件。", bare: "快速查看插件，在访达里按空格预览文件。")
            }
            if path.contains("ExtensionKit/Extensions") || bundleID.contains("Settings") {
                return owned(host, "的系统设置面板，只在打开对应设置页时工作。", bare: "系统设置扩展，只在打开对应设置页时工作。")
            }
            return owned(host, "的应用扩展，给系统或其他应用提供一项附加功能。", bare: "应用扩展，给系统或其他应用提供一项附加功能。")
        }
        if path.contains(".xpc") {
            return owned(host, "的 XPC 服务，在后台完成一项独立任务，没有自己的窗口。", bare: "XPC 服务，在后台完成一项独立任务，没有自己的窗口。")
        }
        if host != nil || bundleID.hasSuffix(".helper") || bundleID.hasSuffix(".Helper") {
            return owned(host, "内部的辅助进程，负责渲染、插件或后台任务，不会单独出现在程序坞。", bare: "其他应用内部的辅助进程，不会单独出现在程序坞。")
        }
        return nil
    }

    private static func owned(_ host: String?, _ suffix: String, bare: String) -> String {
        guard let host, !host.isEmpty else { return bare }
        return "「\(host)」\(suffix)"
    }

    private static func fallback(kind: AppKind, isHidden: Bool) -> String {
        switch kind {
        case .menuBar:
            "驻留后台的应用，通常在菜单栏提供功能，不出现在程序坞。"
        case .agent:
            "独立的后台程序，没有自己的程序坞图标。"
        case .windowed:
            isHidden ? "普通窗口应用，窗口目前被隐藏。" : "普通窗口应用。它还开着，只是当前不在最前面。"
        case .helper:
            "附属于其他应用的后台组件。"
        case .process:
            "没有标准应用包的后台进程。"
        }
    }
}

private let bundleText: [String: String] = [
    "com.apple.loginwindow": "登录窗口。负责显示登录界面，并维持当前用户会话。不要退出它。",
    "com.apple.WindowManager": "窗口管理。负责窗口动画、分屏和台前调度。不要退出它。",
    "com.apple.controlcenter": "控制中心。菜单栏上的网络、专注、声音、亮度等开关都由它提供。",
    "com.apple.dock": "程序坞。用来启动和切换应用，也负责启动台和调度中心。",
    "com.apple.finder": "访达。管理文件、磁盘、外接设备和网络位置。",
    "com.apple.wallpaper.agent": "桌面墙纸。负责当前桌面和锁定屏幕的壁纸。",
    "com.apple.dock.extra": "程序坞附加组件。给应用提供程序坞菜单、进度或快捷操作。",
    "com.apple.dock.external.extra.arm64": "第三方应用的程序坞扩展。名称里的括号就是它服务的那个应用。",
    "com.apple.MenuBarAgent": "菜单栏宿主。承载菜单栏右侧那些不属于单个应用的系统图标。",
    "com.apple.notificationcenterui": "通知中心。接收、展示和收纳各应用的通知。",
    "com.apple.systemuiserver": "系统界面服务。负责一部分菜单栏图标和系统菜单。",
    "com.apple.wifi.WiFiAgent": "Wi-Fi 菜单。查看无线网络、连接和断开热点。",
    "com.apple.AirPlayUIAgent": "隔空播放。把画面或音频送到另一台设备，也负责屏幕镜像。",
    "com.apple.TextInputMenuAgent": "输入法菜单。菜单栏上的输入法图标，用来切换输入源。",
    "com.apple.TextInputSwitcher": "输入法切换服务。在不同输入法之间实际完成切换。",
    "com.apple.AccessibilityUIServer": "辅助功能界面。放大镜、旁白、悬停文本等辅助功能的界面。",
    "com.apple.accessibility.universalAccessAuthWarn": "辅助功能权限提示。某个应用请求控制电脑时弹出的系统确认。",
    "com.apple.universalcontrol": "通用控制。一套键盘和鼠标同时操作附近的 Mac 和 iPad。",
    "com.apple.sharingd": "共享服务。隔空投送、接力、通用剪贴板和本地共享都走它。",
    "com.apple.talagent": "窗口恢复。重新登录或重新打开应用时，帮系统还原上次的窗口。",
    "com.apple.CoreLocationAgent": "定位服务。替应用向系统查询这台 Mac 的位置。",
    "com.apple.UserNotificationCenter": "通知投递中心。把通知从应用送到通知中心。",
    "com.apple.chronod": "小组件时间服务。按时间线刷新桌面和通知中心里的小组件。",
    "com.apple.campo": "Siri AI 的界面进程，负责系统里的 Siri 对话窗口。",
    "com.apple.Siri": "Siri。响应菜单栏或快捷键唤起的语音和文字请求。",
    "com.apple.SiriNCService": "Siri 的通知服务，把 Siri 的结果送到通知中心。",
    "com.apple.UIKitSystemApp": "UIKit 系统宿主。给 Mac 上的 iOS 风格界面提供运行环境。",
    "com.apple.coreservices.uiagent": "系统对话框。打开方式、授权和一部分系统提示由它显示。",
    "com.apple.SoftwareUpdateNotificationManager": "软件更新通知。有系统更新时在菜单栏或通知里提醒。",
    "com.apple.security.Keychain-Circle-Notification": "iCloud 钥匙串提示。验证设备或同步密码时出现。",
    "com.apple.AuthenticationServicesCore.AuthenticationServicesAgent": "自动填充与通行密钥。在网页和应用里填入已保存的密码。",
    "com.apple.AppSSOAgent": "单点登录代理。给支持企业单点登录的应用提供登录状态。",
    "com.apple.backgroundtaskmanagement.agent": "登录项管理界面背后的服务，负责允许或阻止应用在后台运行。",
    "com.apple.MobileDeviceUpdater": "苹果设备连接。iPhone、iPad 插上这台 Mac 时由它处理连接和更新。",
    "com.apple.dt.mcp-server": "Xcode 的后台服务进程，给 Xcode 的智能功能和外部工具提供接口。",
    "com.apple.dt.Xcode": "Xcode。开发、编译、签名和调试苹果平台应用。",
    "com.apple.dt.Devices": "Xcode 设备中心。查看模拟器以及用线或网络连上的苹果设备。",
    "com.apple.CoreSimulator.SimulatorTrampoline": "模拟器跳板进程。负责把 iOS 模拟器拉起来。",
    "com.apple.CoreSimulator.CoreSimulatorService": "模拟器核心服务。管理模拟器设备的运行状态。",
    "com.apple.systempreferences": "系统设置。修改这台 Mac 的偏好、账户、网络和权限。",
    "com.apple.Safari": "Safari。苹果的网页浏览器。",
    "com.apple.mail": "邮件。收发电子邮件，并管理邮箱账户。",
    "com.apple.MobileSMS": "信息。收发短信和 iMessage。",
    "com.apple.Notes": "备忘录。记录笔记、清单和附件。",
    "com.apple.reminders": "提醒事项。按时间和列表管理待办。",
    "com.apple.iCal": "日历。查看日程、会议和提醒。",
    "com.apple.Preview": "预览。查看和标注 PDF、图片。",
    "com.apple.TextEdit": "文本编辑。打开和修改纯文本、富文本。",
    "com.apple.Terminal": "终端。在这台 Mac 上运行命令行。",
    "com.apple.ActivityMonitor": "活动监视器。查看 CPU、内存、能耗和每个进程。",
    "com.apple.Console": "控制台。查看系统和应用写出的日志。",
    "com.apple.DiskUtility": "磁盘工具。分区、修复和抹掉磁盘。",
    "com.apple.systemprofiler": "系统信息。查看硬件、软件和序列号。",
    "com.apple.SystemProfiler": "系统信息。查看硬件、软件和序列号。",
    "com.apple.Music": "音乐。播放资料库和 Apple Music。",
    "com.apple.TV": "电视。播放影片和 Apple TV 内容。",
    "com.apple.podcasts": "播客。订阅和播放播客节目。",
    "com.apple.Photos": "照片。管理照片图库和相册。",
    "com.apple.AppStore": "App Store。安装和更新 Mac 应用。",
    "com.apple.AddressBook": "通讯录。保存联系人和电话、邮箱。",
    "com.apple.FaceTime": "FaceTime。和苹果设备进行音频或视频通话。",
    "com.apple.Maps": "地图。查路线、地点和交通。",
    "com.apple.weather": "天气。查看当前天气和预报。",
    "com.apple.stocks": "股市。查看自选股票和行情。",
    "com.apple.Home": "家庭。控制家里的 HomeKit 设备。",
    "com.apple.freeform": "无边记。一块可以涂写、贴图的协作画板。",
    "com.apple.iBooksX": "图书。阅读已购买或导入的书。",
    "com.apple.Dictionary": "词典。查词语解释和翻译。",
    "com.apple.calculator": "计算器。",
    "com.apple.quicktimeplayer": "QuickTime Player。播放和简单剪辑音视频。",
    "com.apple.ScriptEditor2": "脚本编辑器。编写和运行 AppleScript。",
    "com.apple.automator": "自动操作。把重复步骤收成一个工作流。",
    "com.apple.shortcuts": "快捷指令。把多步操作收成一条指令。",
    "com.apple.finder.FinderSync.IsExtensionEnabled": "访达扩展检测。系统用它询问某个访达扩展是否启用。",
    "com.google.Chrome": "Google Chrome 浏览器。",
    "com.google.Chrome.helper": "Chrome 的辅助进程，负责渲染页面、扩展或后台任务。",
    "com.google.chrome.for.testing": "供自动化测试使用的 Chrome，不是日常使用的那个浏览器。",
    "com.microsoft.edgemac": "Microsoft Edge 浏览器。",
    "org.mozilla.firefox": "Firefox 浏览器。",
    "com.brave.Browser": "Brave 浏览器。",
    "company.thebrowser.Browser": "Arc 浏览器。",
    "com.apple.SafariTechnologyPreview": "Safari 技术预览版，用来提前试用新的网页功能。",
    "com.todesktop.230313mzl4w4u92": "Cursor。写代码用的编辑器，可以在里面和 AI 对话。",
    "com.todesktop.230313mzl4w4u92.helper": "Cursor 的辅助进程，负责窗口渲染或后台任务。",
    "com.github.Electron.helper": "Electron 应用的插件辅助进程。",
    "com.microsoft.VSCode": "Visual Studio Code。写代码用的编辑器。",
    "com.electron.ollama": "Ollama。在这台 Mac 上运行和下载大语言模型。",
    "com.openai.chat": "ChatGPT 桌面版。和 ChatGPT 对话。",
    "com.anthropic.claudefordesktop": "Claude 桌面版。和 Claude 对话。",
    "com.figma.Desktop": "Figma。做界面设计，也可以和别人一起改同一份稿。",
    "com.figma.agent": "Figma 本地代理。负责本机字体，以及和 Figma 桌面端的连接。",
    "com.electron.lark": "飞书。聊天、开会、处理工作消息和文档。",
    "com.electron.lark.helper": "飞书的辅助进程，负责渲染或后台任务。",
    "com.electron.lark-notifier": "飞书通知进程。飞书在后台时由它弹出消息提醒。",
    "com.bytedance.macos.feishu": "飞书。聊天、开会、处理工作消息和文档。",
    "com.bot.pc.doubao": "豆包。字节跳动的 AI 对话应用。",
    "com.bot.pc.doubao.browser": "豆包内置浏览器，用来打开豆包里的网页。",
    "com.bytedance.inputmethod.doubaoime": "豆包输入法。在后台接收按键，把文字送到当前应用。",
    "com.netease.uuremote": "UU 远程。网易的远程桌面，用来控制另一台电脑或被控制。",
    "com.metacubex.ClashX.meta": "ClashX Meta。本机代理客户端，按规则转发网络流量。",
    "fyi.lunar.Lunar": "Lunar。调节外接显示器的亮度、对比度和信号源。",
    "com.bjango.istatmenus.status": "iStat Menus 的菜单栏图标。在菜单栏查看 CPU、内存、网络和传感器。",
    "com.bjango.istatmenus.agent": "iStat Menus 的采集进程。在后台读取传感器和系统占用，再交给菜单栏显示。",
    "com.raycast.macos": "Raycast。键盘启动器，用来打开应用、跑命令、查剪贴板。",
    "com.runningwithcrayons.Alfred": "Alfred。键盘启动器，用来打开应用和运行工作流。",
    "com.tencent.xinWeChat": "微信。收发消息、语音和文件。",
    "com.tencent.qq": "QQ。收发消息和文件。",
    "com.alibaba.DingTalkMac": "钉钉。企业聊天、会议和审批。",
    "com.microsoft.Word": "Microsoft Word。编写和排版文档。",
    "com.microsoft.Excel": "Microsoft Excel。编辑表格和公式。",
    "com.microsoft.Powerpoint": "Microsoft PowerPoint。编辑演示文稿。",
    "com.microsoft.Outlook": "Microsoft Outlook。邮件、日历和联系人。",
    "com.microsoft.teams2": "Microsoft Teams。企业聊天和会议。",
    "us.zoom.xos": "Zoom。视频会议。",
    "com.tinyspeck.slackmacgap": "Slack。团队聊天和工作区消息。",
    "com.hnc.Discord": "Discord。语音、文字频道和社区聊天。",
    "notion.id": "Notion。笔记、数据库和协作文档。",
    "md.obsidian": "Obsidian。用本地 Markdown 文件做笔记。",
    "abnerworks.Typora": "Typora。所见即所得的 Markdown 编辑器。",
    "com.netease.163music": "网易云音乐。播放在线和本地音乐。",
    "com.spotify.client": "Spotify。播放在线音乐。",
    "com.colliderli.iina": "IINA。播放本地和网络视频。",
    "org.videolan.vlc": "VLC。播放常见格式的音视频。",
    "com.docker.docker": "Docker Desktop。运行容器和本地开发环境。",
    "io.tailscale.ipn.macsys": "Tailscale。把这台 Mac 接入你的虚拟专用网络。",
    "com.1password.1password": "1Password。保存并自动填充密码。",
    "com.bitwarden.desktop": "Bitwarden。保存并自动填充密码。",
    "org.pqrs.Karabiner-Elements": "Karabiner-Elements。改键盘按键和组合键。",
    "org.pqrs.Karabiner-Menu": "Karabiner 的菜单栏图标。",
    "com.hegenberg.BetterTouchTool": "BetterTouchTool。自定义触控板、鼠标和键盘手势。",
    "com.knollsoft.Rectangle": "Rectangle。用快捷键排列窗口。",
    "com.lwouis.alt-tab-macos": "AltTab。按住快捷键在所有窗口之间切换。",
    "eu.exelban.Stats": "Stats。在菜单栏查看 CPU、内存、磁盘和网络。",
    "com.surteesstudios.Bartender": "Bartender。整理和隐藏菜单栏图标。",
    "com.getdropbox.dropbox": "Dropbox。把文件同步到云端和其他设备。",
    "com.google.drivefs": "Google 云端硬盘。同步云端文件到这台 Mac。",
    "com.microsoft.OneDrive": "OneDrive。同步微软云端文件。",
    "com.parallels.desktop.console": "Parallels Desktop。在 Mac 上运行虚拟机。",
    "com.vmware.fusion": "VMware Fusion。在 Mac 上运行虚拟机。",
    "com.kingsoft.wpsoffice.mac": "WPS Office。编辑文字、表格和演示文稿。",
    "com.kingsoft.wpsoffice.mac.WPSQuickLook": "WPS 的快速查看插件。在访达里按空格预览 WPS 文档。",
    "com.googlecode.iterm2": "iTerm2。终端，用来运行命令行。",
    "dev.warp.Warp-Stable": "Warp。带补全和分块输出的终端。",
    "com.jetbrains.intellij": "IntelliJ IDEA。写代码用的集成开发环境。",
    "com.sublimetext.4": "Sublime Text。文本和代码编辑器。",
    "org.p0deje.Maccy": "Maccy。菜单栏剪贴板历史。",
    "com.pilotmoon.scroll-reverser": "Scroll Reverser。分别反转鼠标和触控板的滚动方向。",
]

private let executableText: [String: String] = [
    "universalaccessd": "辅助功能守护进程。把放大、旁白等辅助功能设置应用到系统。",
    "sharingd": "共享服务。隔空投送、接力、通用剪贴板和本地共享都走它。",
    "studentd": "课堂服务。学校或教室配置下的学生端后台进程。",
    "UURemoteServer": "UU 远程的后台服务进程，负责保持远程连接。",
    "simulator-server": "模拟器控制服务。本地工具用它连接和控制 iOS 模拟器。",
    "AppSSODaemon": "单点登录的后台守护进程。",
    "osascript": "正在执行的 AppleScript。",
    "omp": "omp 命令行工具对应的后台进程。",
    "omp-capture-helper": "omp 的截图辅助进程，用来抓取屏幕内容。",
    "node": "Node.js 进程。进程名是它正在执行的工具或脚本。",
]

private let categoryText: [String: String] = [
    "public.app-category.business": "商务",
    "public.app-category.developer-tools": "开发工具",
    "public.app-category.education": "教育",
    "public.app-category.entertainment": "娱乐",
    "public.app-category.finance": "财务",
    "public.app-category.games": "游戏",
    "public.app-category.graphics-design": "图形设计",
    "public.app-category.healthcare-fitness": "健康",
    "public.app-category.lifestyle": "生活",
    "public.app-category.medical": "医疗",
    "public.app-category.music": "音乐",
    "public.app-category.news": "新闻",
    "public.app-category.photography": "摄影",
    "public.app-category.productivity": "效率",
    "public.app-category.reference": "参考",
    "public.app-category.social-networking": "社交",
    "public.app-category.sports": "体育",
    "public.app-category.travel": "旅行",
    "public.app-category.utilities": "工具",
    "public.app-category.video": "视频",
    "public.app-category.weather": "天气",
    "public.app-category.shopping": "购物",
    "public.app-category.food-and-drink": "美食",
]
