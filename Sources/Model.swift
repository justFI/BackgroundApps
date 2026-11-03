import AppKit
import Darwin

enum AppKind: String, CaseIterable, Identifiable {
    case menuBar
    case agent
    case windowed
    case helper
    case process

    var id: String { rawValue }

    var title: String {
        switch self {
        case .menuBar: "菜单栏与辅助应用"
        case .agent: "后台代理"
        case .windowed: "窗口在后台"
        case .helper: "内嵌辅助与扩展"
        case .process: "其他进程"
        }
    }

    var subtitle: String {
        switch self {
        case .menuBar: "不在程序坞里，通常一直开着"
        case .agent: "不能切到前台的独立程序"
        case .windowed: "普通应用，当前不是最前面的窗口"
        case .helper: "属于其他应用的网页进程、插件、小组件"
        case .process: "没有标准应用包的后台程序"
        }
    }

    var isStandalone: Bool {
        switch self {
        case .menuBar, .agent, .windowed: true
        case .helper, .process: false
        }
    }
}

struct RunningApp: Identifiable {
    let pid: pid_t
    var id: pid_t { pid }
    let name: String
    let bundleID: String
    let kind: AppKind
    let purpose: String
    let version: String
    let location: String
    let executable: String
    let host: String?
    let launchDate: Date?
    let isHidden: Bool
    let canActivate: Bool
    let canQuit: Bool
    let isSystem: Bool
    let icon: NSImage
}

enum Inventory {
    static let selfBundleID = "local.backgroundapps"

    static func snapshot() -> (apps: [RunningApp], frontName: String) {
        let workspace = NSWorkspace.shared
        let front = workspace.frontmostApplication
        let frontIsSelf = front?.bundleIdentifier == selfBundleID
        let frontName: String
        let hiddenPID: pid_t?
        if let front, !frontIsSelf {
            frontName = front.localizedName?.nonEmpty ?? "未命名应用"
            hiddenPID = front.activationPolicy == .regular ? front.processIdentifier : nil
        } else if frontIsSelf {
            frontName = "后台应用"
            hiddenPID = nil
        } else {
            frontName = "无"
            hiddenPID = nil
        }

        var metas = MetaCache()
        var hosts = HostCache()
        var apps: [RunningApp] = []
        apps.reserveCapacity(workspace.runningApplications.count)

        for running in workspace.runningApplications {
            if running.isTerminated { continue }
            let bundleID = running.bundleIdentifier ?? ""
            if bundleID == selfBundleID { continue }
            if running.processIdentifier == hiddenPID { continue }
            if running.activationPolicy == .regular && running.isActive && running.processIdentifier == front?.processIdentifier {
                continue
            }

            let bundlePath = absoluteExistingPath(running.bundleURL)
            let executable = processPath(running.processIdentifier)
                ?? absoluteExistingPath(running.executableURL)
                ?? ""
            let location = bundlePath ?? containerPath(executable)
            let name = (running.localizedName?.nonEmpty)
                ?? URL(fileURLWithPath: executable).lastPathComponent.nonEmpty
                ?? "未命名进程"
            let kind = classify(bundleID: bundleID, path: location, policy: running.activationPolicy, hasBundle: bundlePath != nil)
            let host = hosts.name(for: location)
            let meta = metas.meta(for: bundlePath.map { URL(fileURLWithPath: $0) })
            let purpose = Purpose.text(
                name: name,
                bundleID: bundleID,
                executable: executable,
                path: location,
                host: host,
                kind: kind,
                isHidden: running.isHidden,
                about: meta.about,
                category: meta.category
            )
            let iconSource = running.icon ?? workspace.icon(forFile: location.isEmpty ? executable : location)
            let isSystem = bundleID.hasPrefix("com.apple.")
                || location.hasPrefix("/System/")
                || location.hasPrefix("/usr/")

            apps.append(RunningApp(
                pid: running.processIdentifier,
                name: name,
                bundleID: bundleID,
                kind: kind,
                purpose: purpose,
                version: meta.version,
                location: location,
                executable: executable,
                host: host,
                launchDate: running.launchDate,
                isHidden: running.isHidden,
                canActivate: running.activationPolicy != .prohibited,
                canQuit: !blockedQuit.contains(bundleID),
                isSystem: isSystem,
                icon: sizedIcon(iconSource)
            ))
        }

        apps.sort { lhs, rhs in
            let order = lhs.name.localizedStandardCompare(rhs.name)
            if order == .orderedSame { return lhs.pid < rhs.pid }
            return order == .orderedAscending
        }
        return (apps, frontName)
    }

    /// WebKit 内容进程给出的是相对 file URL。`URL.path` 会把它接到我们自己的工作目录上。
    private static func absoluteExistingPath(_ url: URL?) -> String? {
        guard let url, url.isFileURL, url.baseURL == nil else { return nil }
        let path = url.path
        guard path.hasPrefix("/"), FileManager.default.fileExists(atPath: path) else { return nil }
        return path
    }

    private static func processPath(_ pid: pid_t) -> String? {
        var buffer = [CChar](repeating: 0, count: Int(PATH_MAX))
        let length = proc_pidpath(pid, &buffer, UInt32(buffer.count))
        guard length > 0 else { return nil }
        let path = String(cString: buffer)
        guard path.hasPrefix("/") else { return nil }
        return path
    }

    /// 取可执行文件所在的最内层 .app / .appex / .xpc，没有包就用可执行文件本身。
    private static func containerPath(_ executable: String) -> String {
        guard !executable.isEmpty else { return "" }
        let markers = [".app/", ".appex/", ".xpc/"]
        var best: String?
        for marker in markers {
            var range = executable.startIndex..<executable.endIndex
            while let found = executable.range(of: marker, range: range) {
                let path = String(executable[..<found.upperBound].dropLast())
                if best == nil || path.count > best!.count {
                    best = path
                }
                range = found.upperBound..<executable.endIndex
            }
        }
        return best ?? executable
    }

    /// WebKit 内容进程的 bundleURL 经常落在 /private/tmp，路径上看不出它是辅助进程。
    private static func classify(
        bundleID: String,
        path: String,
        policy: NSApplication.ActivationPolicy,
        hasBundle: Bool
    ) -> AppKind {
        if isHelper(bundleID: bundleID, path: path) { return .helper }
        if !hasBundle || isRawExecutable(path) { return .process }
        switch policy {
        case .regular:
            return .windowed
        case .accessory:
            return path.hasSuffix(".app") ? .menuBar : .agent
        case .prohibited:
            return .agent
        @unknown default:
            return .process
        }
    }

    private static func isHelper(bundleID: String, path: String) -> Bool {
        if path.range(of: ".app/") != nil { return true }
        if path.contains(".appex") || path.contains(".xpc") || path.contains(".framework/") { return true }
        if bundleID.hasPrefix("com.apple.WebKit.") { return true }
        if bundleID == "com.apple.SafariPlatformSupport.Helper" { return true }
        if bundleID.hasSuffix(".helper") || bundleID.hasSuffix(".Helper") { return true }
        return false
    }

    private static func isRawExecutable(_ path: String) -> Bool {
        path.contains("/bin/") || path.contains("/sbin/") || path.contains("/libexec/")
    }

    private static let blockedQuit: Set<String> = [
        "com.apple.loginwindow",
        "com.apple.dock",
        "com.apple.WindowManager",
        "com.apple.systemuiserver",
        "com.apple.controlcenter",
        "com.apple.MenuBarAgent",
    ]
}

private struct BundleMeta {
    var version = ""
    var about: String?
    var category: String?
}

private struct MetaCache {
    private var cache: [String: BundleMeta] = [:]

    mutating func meta(for url: URL?) -> BundleMeta {
        guard let url else { return BundleMeta() }
        if let cached = cache[url.path] { return cached }
        let loaded = Self.load(url)
        cache[url.path] = loaded
        return loaded
    }

    private static func load(_ url: URL) -> BundleMeta {
        guard let bundle = Bundle(url: url) else { return BundleMeta() }
        let short = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        let version: String
        if let short, let build, !short.isEmpty, !build.isEmpty, build != short {
            version = "\(short) (\(build))"
        } else {
            version = short?.nonEmpty ?? build?.nonEmpty ?? ""
        }
        let about = (bundle.object(forInfoDictionaryKey: "CFBundleGetInfoString") as? String).flatMap(meaningfulAbout)
        let category = bundle.object(forInfoDictionaryKey: "LSApplicationCategoryType") as? String
        return BundleMeta(version: version, about: about, category: category?.nonEmpty)
    }
}

private struct HostCache {
    private var cache: [String: String] = [:]

    mutating func name(for path: String) -> String? {
        guard let range = path.range(of: ".app/") else { return nil }
        let appPath = String(path[..<range.lowerBound]) + ".app"
        if path == appPath { return nil }
        if let cached = cache[appPath] { return cached }
        let url = URL(fileURLWithPath: appPath)
        let folder = url.deletingPathExtension().lastPathComponent
        let display: String?
        if let bundle = Bundle(url: url) {
            display = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)?.nonEmpty
                ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)?.nonEmpty
        } else {
            display = nil
        }
        let resolved = display ?? folder
        cache[appPath] = resolved
        return resolved
    }
}

private func meaningfulAbout(_ raw: String) -> String? {
    let text = raw.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)
    if text.count < 4 { return nil }
    if text.contains("<") || text.contains("©") || text.contains("保留所有权利") { return nil }
    if text.range(of: "copyright", options: .caseInsensitive) != nil { return nil }
    if text.range(of: #"^\d+(\.\d+){1,3}(\s*\(.+\))?$"#, options: .regularExpression) != nil { return nil }
    return text
}

private func sizedIcon(_ image: NSImage) -> NSImage {
    let copy = (image.copy() as? NSImage) ?? image
    copy.size = NSSize(width: 32, height: 32)
    return copy
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}
