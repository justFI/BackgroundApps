# 后台应用 / Background Apps

[中文](#中文) · [English](#english)

macOS 菜单栏应用。列出当前在后台运行的程序，显示名称、作用和文件位置。Ollama 正在用本地模型生成时，菜单栏会另外显示模型名，生成结束后消失。

A macOS menu-bar app. It lists programs running in the background, with a name, a purpose, and a file location. While Ollama is generating with a local model, the menu bar also shows that model’s name. The indicator disappears when generation stops.

协议 / License: [MIT](LICENSE) · 实现提示词 / Implementation prompt: [AGENT_PROMPT.md](AGENT_PROMPT.md)

## 中文

### 它做什么

- 菜单栏图标是三层叠放的方块。点击打开面板，再点一次或按 Esc 关闭。点面板外面也会关闭。
- 面板按类型分组：菜单栏与辅助应用、后台代理、窗口在后台、内嵌辅助与扩展、其他进程。前三类默认展开。
- 每一行有图标、名称、作用和路径。点开一行可以在访达中显示、拷贝位置、切换到前台，或请求退出。
- 最前面的普通窗口不在列表里，写在面板底部的「前台」。
- 本地模型正在生成时，菜单栏多出一个火花图标和模型名，例如 `lfm3:1.7b 生成中`。模型只是留在内存里、没有生成时不显示。

作用说明按这个顺序取得：常见应用的内置说明、按路径判断的类型（网页进程、输入法、小组件、扩展等）、应用自己的简介、系统分类，最后才是一句笼统说明。不认识的程序也会出现，只是说明可能比较短。

### 环境

- Apple 芯片（arm64）
- macOS 14 或更新
- Xcode 命令行工具：`xcode-select --install`
- 可选：本机 [Ollama](https://ollama.com)，默认地址 `http://127.0.0.1:11434`。没装 Ollama 时，列表功能不受影响。

仓库不提供可直接双击的安装包。`build.sh` 使用临时签名，只能在编译它的这台 Mac 上打开。

### 安装

在仓库目录执行：

```zsh
./build.sh
```

脚本会编译、签名，并安装到 `~/Applications/后台应用.app`，然后可以直接从菜单栏使用。如果旧进程还在，脚本会先结束它。

从浏览器下载源码后，若系统提示无法验证开发者，请使用上面的命令自己编译，不要依赖别人发来的临时签名包。

### 使用

| 操作 | 结果 |
| --- | --- |
| 左键点菜单栏图标 | 打开或关闭面板 |
| 右键点菜单栏图标 | 打开或退出本应用 |
| 点一行 | 展开位置、版本、进程号和操作 |
| 在 Finder 中显示 | 访达里选中该文件 |
| 拷贝位置 | 把路径放到剪贴板 |
| 切换到前台 | 把它的窗口带到最前面，并关闭面板 |
| 退出 | 先确认，再请该应用自行退出。未保存的内容可能丢失 |
| 齿轮菜单 | 开关「登录时启动」，或退出本应用 |
| Command-R | 重新读取进程列表 |
| Command-F | 聚焦搜索 |
| Esc | 关闭面板 |

搜索匹配名称、作用、包名、路径、进程号和所属应用。

登录时启动如果需要系统允许，按提示打开「系统设置 → 通用 → 登录项与扩展」。

以下关键系统组件没有退出按钮：登录窗口、程序坞、窗口管理、系统界面服务、控制中心、菜单栏宿主。其他系统进程仍可能退出，退出前请看确认框里的说明。

Ollama 状态只看本机 `llama-server` 是否正在处理请求，不把「模型已加载但空闲」当成生成中。点这个状态图标会打开同一个面板，面板顶部也会显示「生成中」和模型名。

### 免责声明

本软件按「现状」提供，不提供任何明示或暗示的保证，包括对适销性、特定用途适用性和不侵权的保证。作者和版权人不对使用或无法使用本软件造成的任何损失负责，包括数据丢失、工作中断、系统不稳定，以及因退出进程而产生的后果。

本应用会读取当前用户会话中的运行进程，并可能读取本机 Ollama 推理进程的命令行，以便判断是否正在生成。这些访问只用于在本机显示状态，软件本身不会把进程列表上传到作者的服务器。退出操作调用的是系统的正常退出请求，不是强制结束进程；它仍可能关掉你正在使用的应用。请不要用它退出自己不了解的系统进程。

本项目与 Apple、Ollama 没有关联。菜单栏里的名称和图标只用于说明对应功能。临时签名的构建产物不受 Gatekeeper 的开发者验证保护，请只运行你自己编译的副本。

完整协议见 [LICENSE](LICENSE)。

## English

### What it does

- The menu-bar icon is a stack of three squares. Click it to open the panel. Click again, press Esc, or click outside the panel to close it.
- Rows are grouped into menu-bar and accessory apps, background agents, windowed apps that are not frontmost, embedded helpers and extensions, and other processes. The first three groups start expanded.
- Each row shows an icon, a name, a purpose, and a path. Expand a row to reveal it in Finder, copy the path, bring it forward, or ask it to quit.
- The frontmost normal window is omitted from the list. Its name is shown as “Front” at the bottom of the panel. The app UI itself is in Chinese; that footer label is 「前台」.
- While a local model is generating, a second menu-bar item appears with a sparkles icon and the model name, for example `lfm3:1.7b 生成中`. A model that is only resident in memory does not produce this item.

Purpose text is chosen in this order: a built-in description for a known app, a structural guess from the path (web process, input method, widget, extension, and so on), the app’s own about text, the system category, then a generic sentence. Unknown programs are still listed. Their description may be generic.

### Requirements

- Apple silicon (arm64)
- macOS 14 or later
- Xcode Command Line Tools: `xcode-select --install`
- Optional: local [Ollama](https://ollama.com) at `http://127.0.0.1:11434`. The process list works without it.

This repository does not ship a double-clickable binary. `build.sh` applies an ad-hoc signature, so the result opens on the Mac that built it.

### Install

From the repository directory:

```zsh
./build.sh
```

The script compiles, signs, and installs `~/Applications/后台应用.app`. If an older copy is running, the script quits it first.

If macOS says a downloaded build cannot be verified, compile it yourself with the command above. Do not trust an ad-hoc signed app sent by someone else.

### Use

| Action | Result |
| --- | --- |
| Left-click the menu-bar icon | Open or close the panel |
| Right-click the menu-bar icon | Open this app or quit it |
| Click a row | Show location, version, pid, and actions |
| Show in Finder | Select the file in Finder |
| Copy location | Put the path on the clipboard |
| Bring to front | Activate its windows and close the panel |
| Quit | Ask for confirmation, then send a normal quit request. Unsaved work may be lost |
| Gear menu | Toggle launch at login, or quit this app |
| Command-R | Reload the process list |
| Command-F | Focus search |
| Esc | Close the panel |

Search matches name, purpose, bundle identifier, path, process id, and host app.

If launch at login needs approval, use System Settings → General → Login Items & Extensions.

These critical system components have no Quit button: login window, Dock, WindowManager, SystemUIServer, Control Center, and MenuBarAgent. Other system processes can still be quit. Read the confirmation before doing that.

The Ollama indicator follows whether a local `llama-server` is processing a request. A loaded but idle model is not shown as generating. Clicking the indicator opens the same panel, which also shows the generating model at the top.

### Disclaimer

THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. THE AUTHORS OR COPYRIGHT HOLDERS ARE NOT LIABLE FOR ANY CLAIM, DAMAGES, OR OTHER LIABILITY ARISING FROM THE USE OF OR INABILITY TO USE THE SOFTWARE, INCLUDING LOST DATA, INTERRUPTED WORK, SYSTEM INSTABILITY, OR THE RESULT OF QUITTING A PROCESS.

The app reads running processes in the current user session. It may also read the command line of a local Ollama runner to decide whether generation is in progress. That information is shown on the same Mac. This software does not upload the process list to the author’s server. Quit sends the system’s normal termination request rather than a forced kill. It can still close an app you are using. Do not quit system processes you do not understand.

This project is not affiliated with Apple or Ollama. Names and icons in the menu bar identify the corresponding feature. An ad-hoc signature is not checked by Gatekeeper as a Developer ID. Run a copy you built yourself.

The full license is [LICENSE](LICENSE).
