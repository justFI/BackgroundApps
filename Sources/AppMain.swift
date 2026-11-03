import AppKit
import SwiftUI

@main
struct BackgroundAppsMain {
    @MainActor
    static func main() {
        if CommandLine.arguments.contains("--dump") {
            dump()
            return
        }
        if CommandLine.arguments.contains("--ollama") {
            dumpOllama()
            return
        }
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }

    private static func dump() {
        _ = NSApplication.shared
        let shot = Inventory.snapshot()
        var counts: [AppKind: Int] = [:]
        for app in shot.apps {
            counts[app.kind, default: 0] += 1
            let fields = [app.kind.rawValue, app.name, app.bundleID, app.location, app.purpose].map(flat)
            print(fields.joined(separator: "\t"))
        }
        let parts = AppKind.allCases.map { "\($0.rawValue)=\(counts[$0] ?? 0)" }.joined(separator: " ")
        print("# front: \(flat(shot.frontName))")
        print("# \(parts) total=\(shot.apps.count)")
    }

    private static func dumpOllama() {
        switch OllamaSampler.sample() {
        case nil:
            print("unknown")
        case let models? where models.isEmpty:
            print("idle")
        case let models?:
            print(models.joined(separator: "\t"))
        }
    }

    private static func flat(_ text: String) -> String {
        text.replacingOccurrences(of: "\t", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: StatusController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        installAppMenu()
        controller = StatusController()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }

    private func installAppMenu() {
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "退出后台应用", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let item = NSMenuItem()
        item.submenu = appMenu
        let main = NSMenu()
        main.addItem(item)
        NSApp.mainMenu = main
    }
}

@MainActor
final class StatusController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private var ollamaItem: NSStatusItem?
    private let popover = NSPopover()
    private let store = AppStore()
    private var globalMonitor: Any?

    override init() {
        super.init()
        configureItem()
        configurePopover()
        observeWorkspace()
        store.onUpdated = { [weak self] count in
            self?.statusItem.button?.toolTip = "后台应用：\(count) 个独立应用在后台"
            self?.statusItem.button?.setAccessibilityValue("\(count) 个独立应用在后台")
        }
        store.onClose = { [weak self] in
            self?.closePopover()
        }
        store.onOllama = { [weak self] models in
            self?.applyOllama(models)
        }
        store.reload()
        store.startOllamaWatch()
    }

    private func configureItem() {
        guard let button = statusItem.button else { return }
        let symbol = NSImage(systemSymbolName: "square.stack.3d.up", accessibilityDescription: "后台应用")
        let image = symbol?.withSymbolConfiguration(.init(pointSize: 14, weight: .medium)) ?? symbol
        image?.isTemplate = true
        button.image = image
        button.imagePosition = .imageOnly
        button.toolTip = "后台应用"
        button.setAccessibilityLabel("后台应用")
        button.target = self
        button.action = #selector(handleClick(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func configurePopover() {
        let host = NSHostingController(rootView: RootView(store: store, onClose: { [weak self] in
            self?.closePopover()
        }))
        host.sizingOptions = .preferredContentSize
        popover.contentViewController = host
        popover.contentSize = NSSize(width: 420, height: 580)
        popover.behavior = .applicationDefined
        popover.animates = true
    }

    private func observeWorkspace() {
        let names: [Notification.Name] = [
            NSWorkspace.didLaunchApplicationNotification,
            NSWorkspace.didTerminateApplicationNotification,
            NSWorkspace.didActivateApplicationNotification,
            NSWorkspace.didDeactivateApplicationNotification,
            NSWorkspace.didHideApplicationNotification,
            NSWorkspace.didUnhideApplicationNotification,
        ]
        let center = NSWorkspace.shared.notificationCenter
        for name in names {
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.store.schedule()
                }
            }
        }
    }

    @objc private func handleClick(_ sender: Any?) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            closePopover()
            if let event = NSApp.currentEvent, let button = statusItem.button {
                NSMenu.popUpContextMenu(contextMenu, with: event, for: button)
            }
            return
        }
        if popover.isShown {
            closePopover()
        } else {
            openPopover(from: statusItem.button)
        }
    }

    private func applyOllama(_ models: [String]) {
        guard !models.isEmpty else {
            if let ollamaItem {
                NSStatusBar.system.removeStatusItem(ollamaItem)
                self.ollamaItem = nil
            }
            return
        }
        let item = ollamaItem ?? makeOllamaItem()
        let title = ollamaTitle(models)
        item.button?.title = " " + title
        item.button?.toolTip = "Ollama 本地模型正在生成：" + models.joined(separator: "、")
        item.button?.setAccessibilityLabel("Ollama 正在生成 " + models.joined(separator: "、"))
    }

    private func makeOllamaItem() -> NSStatusItem {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        ollamaItem = item
        if let button = item.button {
            let symbol = NSImage(systemSymbolName: "sparkles", accessibilityDescription: "Ollama 生成中")
            let image = symbol?.withSymbolConfiguration(.init(pointSize: 13, weight: .medium)) ?? symbol
            image?.isTemplate = true
            button.image = image
            button.imagePosition = .imageLeading
            button.target = self
            button.action = #selector(openOllama(_:))
            button.sendAction(on: [.leftMouseUp])
        }
        return item
    }

    private func ollamaTitle(_ models: [String]) -> String {
        let joined = models.joined(separator: "、")
        if models.count > 2 || joined.count > 36 {
            return "\(models.count) 个模型生成中"
        }
        return joined + " 生成中"
    }

    @objc private func openOllama(_ sender: Any?) {
        if popover.isShown {
            closePopover()
        } else {
            openPopover(from: ollamaItem?.button)
        }
    }

    private func openPopover(from button: NSView? = nil) {
        guard let button = button ?? statusItem.button else { return }
        store.reload()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApp.activate()
        store.focusTick += 1
        if globalMonitor == nil {
            globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.closePopover()
                }
            }
        }
    }

    private func closePopover() {
        guard popover.isShown else { return }
        popover.performClose(nil)
    }

    private lazy var contextMenu: NSMenu = {
        let menu = NSMenu()
        let open = menu.addItem(withTitle: "打开后台应用", action: #selector(openFromMenu(_:)), keyEquivalent: "")
        open.target = self
        let quit = menu.addItem(withTitle: "退出后台应用", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.target = NSApp
        return menu
    }()

    @objc private func openFromMenu(_ sender: Any?) {
        openPopover(from: statusItem.button)
    }
}
