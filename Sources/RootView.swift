import AppKit
import SwiftUI

struct RootView: View {
    @Bindable var store: AppStore
    var onClose: () -> Void

    @State private var query = ""
    @State private var expandedPID: pid_t?
    @State private var quitPID: pid_t?
    @State private var openSections: [AppKind: Bool] = [
        .menuBar: true,
        .agent: true,
        .windowed: true,
        .helper: false,
        .process: false,
    ]
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            if !store.generatingModels.isEmpty {
                ollamaStatus
            }
            if let banner = store.banner {
                Text(banner)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 8)
            }
            searchField
                .padding(.horizontal, 14)
                .padding(.bottom, 10)
            Divider()
            ScrollView {
                if sections.isEmpty {
                    Text(queryTrimmed.isEmpty ? "当前没有后台应用" : "没有匹配「\(queryTrimmed)」的应用")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                } else {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(sections) { section in
                            sectionView(section)
                        }
                    }
                    .padding(10)
                }
            }
            Divider()
            footer
        }
        .frame(width: 420, height: 580)
        .onAppear { searchFocused = true }
        .onChange(of: store.focusTick) { _, _ in
            searchFocused = true
        }
        .background {
            Button("刷新列表") { store.reload() }
                .keyboardShortcut("r", modifiers: .command)
                .hidden()
            Button("搜索") { searchFocused = true }
                .keyboardShortcut("f", modifiers: .command)
                .hidden()
            Button("关闭") { onClose() }
                .keyboardShortcut(.cancelAction)
                .hidden()
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "square.stack.3d.up")
                .font(.title3)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text("后台应用")
                    .font(.headline)
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 8)
            Button {
                store.reload()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .help("重新读取正在运行的应用")
            Menu {
                Button(store.launchAtLogin ? "登录时启动：开" : "登录时启动：关") {
                    store.setLaunchAtLogin(!store.launchAtLogin)
                }
                Divider()
                Button("退出后台应用") { NSApp.terminate(nil) }
            } label: {
                Image(systemName: "gearshape")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("登录项和退出")
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private var ollamaStatus: some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkles")
            Text("生成中")
                .fontWeight(.semibold)
            Text(store.generatingModels.joined(separator: "、"))
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 0)
        }
        .font(.caption)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .padding(.horizontal, 14)
        .padding(.bottom, 8)
        .help("Ollama 本地模型正在生成")
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Ollama 正在生成 \(store.generatingModels.joined(separator: "、"))")
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("搜索名称、功能或路径", text: $query)
                .textFieldStyle(.plain)
                .focused($searchFocused)
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var footer: some View {
        HStack(spacing: 6) {
            Text("前台")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(store.frontName)
                .font(.caption)
                .lineLimit(1)
            Spacer()
            if !queryTrimmed.isEmpty {
                Text("匹配 \(filtered.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .help("最前面的普通窗口不在上面的列表里")
    }

    private var summary: String {
        let extra = store.apps.count - store.standaloneCount
        if extra > 0 {
            return "\(store.standaloneCount) 个独立应用在后台，另有 \(extra) 个辅助进程"
        }
        return "\(store.standaloneCount) 个独立应用在后台"
    }

    private var queryTrimmed: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var filtered: [RunningApp] {
        let needle = queryTrimmed
        guard !needle.isEmpty else { return store.apps }
        return store.apps.filter { app in
            app.name.localizedCaseInsensitiveContains(needle)
                || app.bundleID.localizedCaseInsensitiveContains(needle)
                || app.purpose.localizedCaseInsensitiveContains(needle)
                || app.location.localizedCaseInsensitiveContains(needle)
                || app.executable.localizedCaseInsensitiveContains(needle)
                || String(app.pid).contains(needle)
                || (app.host?.localizedCaseInsensitiveContains(needle) ?? false)
        }
    }

    private var duplicateNames: Set<String> {
        var counts: [String: Int] = [:]
        for app in filtered {
            counts[app.name, default: 0] += 1
        }
        return Set(counts.filter { $0.value > 1 }.map(\.key))
    }

    private var sections: [AppSection] {
        let rows = filtered
        return AppKind.allCases.compactMap { kind in
            let apps = rows.filter { $0.kind == kind }
            return apps.isEmpty ? nil : AppSection(kind: kind, apps: apps)
        }
    }

    private func sectionView(_ section: AppSection) -> some View {
        DisclosureGroup(isExpanded: expandedBinding(section.kind)) {
            VStack(spacing: 2) {
                ForEach(section.apps) { app in
                    row(app)
                }
            }
            .padding(.top, 4)
        } label: {
            VStack(alignment: .leading, spacing: 1) {
                HStack {
                    Text(section.kind.title)
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text("\(section.apps.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Text(section.kind.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func expandedBinding(_ kind: AppKind) -> Binding<Bool> {
        Binding(
            get: {
                if !queryTrimmed.isEmpty { return true }
                return openSections[kind] ?? false
            },
            set: { openSections[kind] = $0 }
        )
    }

    private func row(_ app: RunningApp) -> some View {
        let expanded = expandedPID == app.pid
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Image(nsImage: app.icon)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 28, height: 28)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(app.name)
                            .font(.body.weight(.medium))
                            .lineLimit(1)
                        if app.isHidden {
                            Text("已隐藏")
                                .font(.caption2.weight(.medium))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1)
                                .background(Color.primary.opacity(0.08), in: Capsule())
                        }
                        if duplicateNames.contains(app.name) {
                            Text("PID \(app.pid)")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .monospacedDigit()
                        }
                    }
                    Text(app.purpose)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(expanded ? 8 : 2)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(app.location.isEmpty ? "没有可用路径" : app.location)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                expandedPID = expanded ? nil : app.pid
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityHint(expanded ? "再次点击收起详情" : "点击查看位置和操作")

            if expanded {
                detail(app)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(expanded ? Color.primary.opacity(0.06) : Color.clear)
        )
        .confirmationDialog(
            "退出「\(app.name)」？",
            isPresented: quitBinding(app.pid),
            titleVisibility: .visible
        ) {
            Button("退出", role: .destructive) { store.quit(pid: app.pid) }
            Button("取消", role: .cancel) {}
        } message: {
            Text(app.isSystem
                ? "这是系统组件。退出后相关功能会暂时不可用。"
                : "应用会收到退出请求。未保存的内容可能丢失。")
        }
    }

    private func detail(_ app: RunningApp) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            detailLine("功能", app.purpose)
            if let host = app.host, host != app.name {
                detailLine("属于", host)
            }
            if !app.bundleID.isEmpty {
                detailLine("标识", app.bundleID)
            }
            if !app.version.isEmpty {
                detailLine("版本", app.version)
            }
            detailLine("进程", String(app.pid))
            if let date = app.launchDate {
                detailLine("启动", "\(Self.absolute.string(from: date)) · \(Self.relative.localizedString(for: date, relativeTo: Date()))")
            }
            detailLine("位置", app.location.isEmpty ? "未知" : app.location)
            if !app.executable.isEmpty, app.executable != app.location {
                detailLine("程序", app.executable)
            }
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Button("在 Finder 中显示") { store.reveal(app) }
                        .help("打开访达并选中这个文件")
                    Button("拷贝位置") { store.copyLocation(app) }
                        .help("把路径复制到剪贴板")
                }
                HStack(spacing: 6) {
                    if app.canActivate {
                        Button("切换到前台") { store.activate(pid: app.pid) }
                            .help("把它的窗口带到最前面")
                    }
                    if app.canQuit {
                        Button("退出", role: .destructive) { quitPID = app.pid }
                            .help("请求这个应用自行退出")
                    }
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.leading, 38)
    }

    private func detailLine(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 32, alignment: .leading)
            Text(value)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.caption)
    }

    private func quitBinding(_ pid: pid_t) -> Binding<Bool> {
        Binding(
            get: { quitPID == pid },
            set: { if !$0 { quitPID = nil } }
        )
    }

    private static let relative: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.unitsStyle = .full
        return formatter
    }()

    private static let absolute: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }()
}

private struct AppSection: Identifiable {
    let kind: AppKind
    let apps: [RunningApp]
    var id: AppKind { kind }
}
