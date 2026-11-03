import AppKit
import Observation
import ServiceManagement

@MainActor
@Observable
final class AppStore {
    var apps: [RunningApp] = []
    var frontName = "无"
    var banner: String?
    var launchAtLogin = false
    var focusTick = 0
    var generatingModels: [String] = []

    var onUpdated: ((Int) -> Void)?
    var onClose: (() -> Void)?
    var onOllama: (([String]) -> Void)?

    private var pending: Task<Void, Never>?
    private var ollamaWatch: Task<Void, Never>?
    private var bannerToken = 0

    var standaloneCount: Int {
        apps.reduce(into: 0) { count, app in
            if app.kind.isStandalone { count += 1 }
        }
    }

    init() {
        refreshLoginState()
    }

    func startOllamaWatch() {
        guard ollamaWatch == nil else { return }
        ollamaWatch = Task { @MainActor [weak self] in
            while let self, !Task.isCancelled {
                let sample = await Task.detached(priority: .utility) {
                    OllamaSampler.sample()
                }.value
                if let sample, sample != self.generatingModels {
                    self.generatingModels = sample
                    self.onOllama?(sample)
                }
                let active = !self.generatingModels.isEmpty
                try? await Task.sleep(for: active ? .milliseconds(400) : .milliseconds(500))
            }
        }
    }

    func schedule() {
        pending?.cancel()
        pending = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }
            reload()
        }
    }

    func reload() {
        let shot = Inventory.snapshot()
        apps = shot.apps
        frontName = shot.frontName
        onUpdated?(standaloneCount)
    }

    func reveal(_ app: RunningApp) {
        let path = FileManager.default.fileExists(atPath: app.location) ? app.location : app.executable
        guard !path.isEmpty, FileManager.default.fileExists(atPath: path) else {
            flash("找不到这个位置")
            return
        }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }

    func copyLocation(_ app: RunningApp) {
        let path = app.location.isEmpty ? app.executable : app.location
        guard !path.isEmpty else {
            flash("没有可复制的位置")
            return
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(path, forType: .string)
        flash("已复制位置")
    }

    func activate(pid: pid_t) {
        guard let running = NSRunningApplication(processIdentifier: pid) else {
            flash("这个进程已经不在了")
            reload()
            return
        }
        if running.activate(options: [.activateAllWindows]) {
            onClose?()
        } else {
            flash("无法把它切到前台")
        }
    }

    func quit(pid: pid_t) {
        guard let app = apps.first(where: { $0.pid == pid }) else { return }
        guard app.canQuit else {
            flash("「\(app.name)」是关键系统组件，不能从这里退出")
            return
        }
        guard let running = NSRunningApplication(processIdentifier: pid) else {
            flash("这个进程已经不在了")
            reload()
            return
        }
        if running.terminate() {
            flash("已请求「\(app.name)」退出")
        } else {
            flash("系统拒绝让「\(app.name)」退出")
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            refreshLoginState()
            if SMAppService.mainApp.status != .requiresApproval {
                flash("无法修改登录项：\(error.localizedDescription)")
            }
            return
        }
        refreshLoginState()
        if SMAppService.mainApp.status == .requiresApproval { return }
        flash(enabled ? "已设为登录时启动" : "已取消登录时启动")
    }

    func refreshLoginState() {
        switch SMAppService.mainApp.status {
        case .enabled:
            launchAtLogin = true
        case .requiresApproval:
            launchAtLogin = false
            showPersistent("要登录时启动，请到「系统设置 → 通用 → 登录项与扩展」里允许后台应用。")
        case .notRegistered, .notFound:
            launchAtLogin = false
        @unknown default:
            launchAtLogin = false
        }
    }

    private func flash(_ text: String) {
        bannerToken += 1
        let token = bannerToken
        banner = text
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.5))
            if bannerToken == token { banner = nil }
        }
    }

    private func showPersistent(_ text: String) {
        bannerToken += 1
        banner = text
    }
}
