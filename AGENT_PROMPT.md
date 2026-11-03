# 实现这个应用的 Agent 提示词

下面两段是同一份实现说明，分别用中文和英文写成。把其中一段交给编程代理，可以按本仓库已经实现的行为重做这个 macOS 菜单栏应用。它不是某个模型的隐藏系统提示，也不包含密钥、账号或本机路径。

The two sections below are the same implementation brief, in Chinese and in English. Give either section to a coding agent to rebuild this menu-bar app as it behaves in this repository. This is not a hidden model system prompt, and it contains no keys, accounts, or machine-specific paths.

## 中文提示词

你是 macOS 工程师。用 Swift 做一个只住在菜单栏里的应用，名字叫「后台应用」，包名 `local.backgroundapps`。不要做程序坞图标。界面文字用简体中文。目标系统是 Apple 芯片上的 macOS 14。用 `swiftc` 直接编译，不创建 Xcode 工程。不要写入任何私钥、令牌、个人家目录或某台电脑专有的包名。

应用要随时列出当前用户会话里正在运行、但不是最前面普通窗口的程序。用户要能看到每个程序的名称、作用和文件位置，并可以打开位置、拷贝路径、切到前台或请求退出。另外，当本机 Ollama 的本地模型正在生成文本时，菜单栏要出现一个独立状态；生成结束就去掉。模型仅仅加载在内存里不算生成中。

列表来自 `NSWorkspace.runningApplications`，并在应用启动、打开面板，以及工作区发出启动、退出、激活、失去激活、隐藏、取消隐藏通知时刷新。通知可以合并到大约 200 毫秒后的一次刷新。排除本应用自己。排除当前最前面且激活策略为 regular 的应用，把它的本地化名称显示在面板底部，标签是「前台」。没有前台应用时显示「无」。

每个进程记录进程号、名称、包名、类型、作用、版本、位置、可执行文件、所属应用、启动时间、是否隐藏、能否切到前台、能否退出、是否系统组件、图标。名称用本地化名称，否则用可执行文件名。位置优先用真实存在的 bundle URL。可执行文件用 `proc_pidpath`。WebKit 一类进程可能给出相对于调用者工作目录的 file URL，这种路径不存在时不要使用。位置取可执行文件所在的最内层 `.app`、`.appex` 或 `.xpc`，没有包就用可执行文件本身。系统组件指包名以 `com.apple.` 开头，或路径在 `/System/`、`/usr/` 下。

类型按这个顺序判断：

1. 路径里还有外层 `.app/`，或包含 `.appex`、`.xpc`、`.framework/`，或包名是 WebKit 内容、网络、图形进程，或 Safari 平台辅助进程，或包名以 `.helper` 结尾：内嵌辅助与扩展。
2. 没有 bundle，或路径含 `/bin/`、`/sbin/`、`/libexec/`：其他进程。
3. 激活策略 regular：窗口在后台。
4. 激活策略 accessory 且路径以 `.app` 结尾：菜单栏与辅助应用。其余 accessory，以及 prohibited：后台代理。

分组标题和副标题：

- 菜单栏与辅助应用：不在程序坞里，通常一直开着。
- 后台代理：不能切到前台的独立程序。
- 窗口在后台：普通应用，当前不是最前面的窗口。
- 内嵌辅助与扩展：属于其他应用的网页进程、插件、小组件。
- 其他进程：没有标准应用包的后台程序。

前三类算独立应用，后两类算辅助进程。面板摘要写成「N 个独立应用在后台，另有 M 个辅助进程」。同名进程在名称旁显示进程号。被隐藏的应用显示「已隐藏」。

作用说明按这个顺序，命中就停止：

1. 按包名或可执行文件名查一张内置中文说明表。表里只放公开、常见的应用，不要放作者自己的私有包名。
2. 按结构说明：WebKit 网页内容、网络、图形进程；Safari 自动填充辅助；输入法；Node.js（名称是它正在跑的脚本）；小组件；快速查看；系统设置扩展；其他 `.appex`；`.xpc`；某个应用内部的 helper。能找到外层应用名时写进句子。
3. 使用 bundle 的 `CFBundleGetInfoString`，但丢掉太短、含版权符号、HTML 或只是版本号的文字，也丢掉和名称相同的文字。
4. 把 `LSApplicationCategoryType` 翻成中文分类，并说明开发者没有写功能简介。
5. 按类型给一句笼统说明。窗口应用如果被隐藏，要说窗口目前被隐藏。

面板宽 420、高 580。顶部是标题「后台应用」、摘要、刷新按钮和齿轮菜单。齿轮菜单切换登录时启动，并提供退出本应用。登录项用 `SMAppService.mainApp`。如果系统要求批准，提示用户到「系统设置 → 通用 → 登录项与扩展」。搜索框占位是「搜索名称、功能或路径」，匹配名称、包名、作用、位置、可执行文件、进程号和所属应用。搜索时展开所有命中的分组。没有结果时说明是没有后台应用，还是没有匹配。

点一行展开详情：功能、所属应用、标识、版本、进程号、启动时间、位置、程序路径。操作按钮是「在 Finder 中显示」「拷贝位置」。激活策略不是 prohibited 时提供「切换到前台」，成功后关闭面板。允许退出时提供「退出」，先弹出确认框。系统组件的确认文案要说明退出后相关功能会暂时不可用。退出调用 `NSRunningApplication.terminate()`，不要 `kill -9`。这六个包名不提供退出：`com.apple.loginwindow`、`com.apple.dock`、`com.apple.WindowManager`、`com.apple.systemuiserver`、`com.apple.controlcenter`、`com.apple.MenuBarAgent`。找不到文件或进程已经消失时，用一条大约 2.5 秒的橙色提示，不要弹系统警告框。

快捷键：Command-R 刷新，Command-F 聚焦搜索，Esc 关闭面板。主菜单至少有「退出后台应用」。菜单栏图标用 SF Symbol `square.stack.3d.up`，模板渲染，固定方形宽度。左键开关面板，右键弹出「打开后台应用」和「退出后台应用」。面板用 application-defined 行为，打开时激活应用，并在面板外点击时关闭。打开面板时让搜索框获得焦点。

Ollama 状态单独实现。枚举本机进程，找到路径以 `/llama-server` 结尾的进程，用 `KERN_PROCARGS2` 读取参数。只接受 `--port` 在 1 到 65535、`--host` 为空或环回地址的进程。请求 `http://127.0.0.1:<port>/slots`，超时不超过 1 秒。任一 slot 的 `is_processing` 为真才算正在生成。模型名从 `~/.ollama/models/manifests` 和 `manifests-v2` 的清单解析。清单可能是指向 blob 的符号链接，按符号链接读取。用模型层 digest 对应到 `name:tag`。若 `/api/ps` 里也有这个名字，优先用它。解析不到就显示「本地模型」。一次采样失败时保留上一次状态，不要闪成空闲。空闲时移除状态图标。生成中时用可变宽度状态项，SF Symbol `sparkles`，标题是模型名加「生成中」。两个以上模型，或标题超过约 36 个字符时，改成「N 个模型生成中」。提示和辅助功能标签写完整模型名。点击它打开同一个列表面板。面板在标题下显示「生成中」和模型名。生成中大约每 400 毫秒采样，空闲大约每 500 毫秒采样，采样放在后台，结果回到主线程再改界面。

提供 `./build.sh`：用 zsh，生成 1024 像素图标并做成 icns，复制 Info.plist，以 arm64、macOS 14、优化级别 `-O` 编译全部 `Sources/*.swift`，临时签名标识 `local.backgroundapps`，安装到 `~/Applications/后台应用.app`。安装前如果同名进程存在就先结束它。`build/` 不提交。支持 `--dump` 打印制表符分隔的列表，以及 `--ollama` 打印正在生成的模型名、`idle` 或 `unknown`。Info.plist 设置 `LSUIElement`、最低系统 14.0、简体中文开发地区、高分辨率。状态栏控制器和界面状态放在主线程。编译必须能在 Swift 6 的严格并发检查下通过。

完成后用真实的 `NSWorkspace` 列表核对分组、路径和排除前台应用的规则。若本机有 Ollama，分别在生成中和空闲时运行 `--ollama`，确认只有 `is_processing` 为真时出现模型名。

## English prompt

You are a macOS engineer. Implement a menu-bar-only app in Swift named 后台应用, with bundle identifier `local.backgroundapps`. It must not show a Dock icon. All interface text is Simplified Chinese. Target Apple silicon and macOS 14. Compile with `swiftc` directly. Do not create an Xcode project. Do not write private keys, tokens, a personal home directory, or a bundle identifier that belongs to one person’s private app.

The app lists programs running in the current user session except the frontmost normal window. For each program the user can see its name, purpose, and file location, then reveal it in Finder, copy the path, bring it forward, or ask it to quit. Separately, while local Ollama is generating with a local model, show an extra menu-bar status. Remove it when generation stops. A model that is only loaded in memory is not generating.

Read the list from `NSWorkspace.runningApplications`. Refresh at launch, when the panel opens, and when the workspace posts launch, terminate, activate, deactivate, hide, or unhide notifications. Coalesce those notifications into one refresh about 200 milliseconds later. Exclude this app. Exclude the frontmost app when its activation policy is regular, and show its localized name at the bottom of the panel next to the label 「前台」. Show 「无」 when there is no front app.

For every process store pid, name, bundle identifier, kind, purpose, version, location, executable, host app, launch date, hidden flag, whether it can be activated, whether it can be quit, whether it is a system component, and an icon. Prefer the localized name, then the executable name. Prefer a bundle URL that exists on disk. Read the executable with `proc_pidpath`. Some WebKit processes expose a file URL relative to the caller’s working directory. Ignore a path that does not exist. The location is the innermost `.app`, `.appex`, or `.xpc` containing the executable, or the executable itself when there is no bundle. Treat a process as a system component when its bundle identifier starts with `com.apple.` or its path starts with `/System/` or `/usr/`.

Classify in this order:

1. Embedded helper or extension: the path still contains an outer `.app/`, or contains `.appex`, `.xpc`, or `.framework/`, or the bundle identifier is a WebKit content, networking, or GPU process, or the Safari platform helper, or the bundle identifier ends in `.helper`.
2. Other process: there is no bundle, or the path contains `/bin/`, `/sbin/`, or `/libexec/`.
3. Window in the background: activation policy regular.
4. Menu-bar and accessory app: activation policy accessory and the path ends in `.app`. Every other accessory process, and every prohibited process, is a background agent.

Group titles and subtitles:

- Menu-bar and accessory apps: not in the Dock, usually left running.
- Background agents: independent programs that cannot be brought forward.
- Windows in the background: normal apps that are not frontmost.
- Embedded helpers and extensions: web processes, plug-ins, and widgets owned by another app.
- Other processes: background programs without a normal app bundle.

The first three kinds are standalone apps. The last two are helper processes. Summarize the panel as “N standalone apps in the background, plus M helper processes,” in Chinese. Show the pid beside a duplicated name. Mark a hidden app 「已隐藏」.

Choose the purpose text in this order and stop at the first hit:

1. A built-in Chinese description keyed by bundle identifier or executable name. Include only public, common apps. Do not include the author’s private bundle identifiers.
2. A structural description for WebKit web content, networking, and GPU processes; the Safari autofill helper; input methods; Node.js, whose displayed name is the script it is running; widgets; Quick Look; System Settings extensions; other `.appex` files; `.xpc` services; and helpers inside another app. Include the outer app name when it can be resolved.
3. `CFBundleGetInfoString`, after dropping text that is very short, contains a copyright mark or HTML, is only a version number, or is the same as the name.
4. `LSApplicationCategoryType`, translated to a Chinese category, with a sentence saying the developer did not supply a description.
5. One generic sentence for the kind. If a windowed app is hidden, say its windows are hidden.

The panel is 420 by 580 points. The header contains the title 后台应用, the summary, a reload button, and a gear menu. The gear menu toggles launch at login and quits this app. Register login with `SMAppService.mainApp`. If the system requires approval, tell the user to open System Settings → General → Login Items & Extensions. The search field placeholder is 「搜索名称、功能或路径」. Match name, bundle identifier, purpose, location, executable, pid, and host app. While a query is active, expand every matching group. Distinguish an empty background from no search matches.

Clicking a row reveals purpose, host app, identifier, version, pid, launch time, location, and executable path. Actions are 「在 Finder 中显示」 and 「拷贝位置」. Offer 「切换到前台」 unless the activation policy is prohibited, and close the panel after a successful activation. Offer 「退出」 only when quitting is allowed, and confirm first. For a system component, the confirmation says the related feature will be unavailable temporarily. Quit with `NSRunningApplication.terminate()`, never `kill -9`. Do not offer Quit for `com.apple.loginwindow`, `com.apple.dock`, `com.apple.WindowManager`, `com.apple.systemuiserver`, `com.apple.controlcenter`, or `com.apple.MenuBarAgent`. If the file or process is already gone, show an orange banner for about 2.5 seconds. Do not raise a system alert.

Shortcuts: Command-R reloads, Command-F focuses search, and Esc closes the panel. The app menu contains at least 「退出后台应用」. The status icon is the template SF Symbol `square.stack.3d.up` at a square status-item length. Left click toggles the panel. Right click shows 「打开后台应用」 and 「退出后台应用」. Use an application-defined popover. Activating the app on open is required. Close the popover when the user clicks outside it. Focus the search field when the panel opens.

Implement the Ollama status separately. Enumerate local processes, find executables whose path ends in `/llama-server`, and read arguments with `KERN_PROCARGS2`. Accept only a `--port` from 1 through 65535 and a `--host` that is empty or loopback. Request `http://127.0.0.1:<port>/slots` with a timeout under one second. Generation is active only when some slot has `is_processing` set to true. Resolve the model name from manifests under `~/.ollama/models/manifests` and `manifests-v2`. Those manifests may be symlinks to blobs. Follow the symlink. Map the model-layer digest to `name:tag`. Prefer a name that is also present in `/api/ps`. If no name resolves, display 「本地模型」. If a sample fails, keep the previous state instead of flashing idle. Remove the status item when idle. While generating, use a variable-length status item, the SF Symbol `sparkles`, and a title of the model name plus 「生成中」. For more than two models, or a joined title longer than about 36 characters, use 「N 个模型生成中」. Put the full model list in the tooltip and accessibility label. Clicking this item opens the same process panel. Under the panel title, show 「生成中」 and the model names. Sample about every 400 milliseconds while generating and about every 500 milliseconds while idle. Sample off the main thread, then apply the result on the main thread.

Provide `./build.sh` for zsh. It draws a 1024-pixel icon, converts it to icns, copies Info.plist, compiles every file in `Sources/*.swift` for arm64 and macOS 14 at `-O`, ad-hoc signs the identifier `local.backgroundapps`, and installs `~/Applications/后台应用.app`. If a process with the same executable name is running, quit it before installation. Do not commit `build/`. Support `--dump`, which prints a tab-separated list, and `--ollama`, which prints the generating model names, `idle`, or `unknown`. Info.plist sets `LSUIElement`, a minimum system version of 14.0, a Simplified Chinese development region, and high resolution. Keep the status controller and UI state on the main thread. The project must compile under Swift 6 strict concurrency checking.

After implementation, check the groups, paths, and front-app exclusion against a live `NSWorkspace` list. If Ollama is installed, run `--ollama` once while generating and once while idle, and confirm that a model name appears only while `is_processing` is true.
