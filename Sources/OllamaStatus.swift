import Darwin
import Foundation

/// Ollama 的 `/api/ps` 在模型只是驻留内存时也有记录。生成与否要看 llama-server 的 `/slots`。
enum OllamaSampler {
    /// `nil` 表示这次没问到，调用方应保留上一次的状态。
    static func sample() -> [String]? {
        let runners = Self.runners()
        if runners.isEmpty { return [] }

        var generating: [String] = []
        var unknown = false
        for runner in runners {
            switch slotState(port: runner.port) {
            case .yes:
                generating.append(runner.modelPath)
            case .no:
                break
            case .unknown:
                unknown = true
            }
        }
        if generating.isEmpty {
            return unknown ? nil : []
        }

        let names = namesByDigest()
        let loaded = loadedNames()
        var seen = Set<String>()
        var labels: [String] = []
        for path in generating {
            let label = displayName(modelPath: path, names: names, loaded: loaded)
            if seen.insert(label).inserted {
                labels.append(label)
            }
        }
        return labels
    }

    private struct Runner {
        var port: Int
        var modelPath: String
    }

    private enum SlotState {
        case yes
        case no
        case unknown
    }

    private static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 0.5
        config.timeoutIntervalForResource = 0.6
        config.waitsForConnectivity = false
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: config)
    }()

    private static func runners() -> [Runner] {
        var result: [Runner] = []
        var seen = Set<Int>()
        for pid in allPids() {
            guard processPath(pid).hasSuffix("/llama-server") else { continue }
            let args = arguments(pid)
            guard let portString = flag(args, "--port"),
                  let port = Int(portString),
                  (1..<65536).contains(port),
                  seen.insert(port).inserted else { continue }
            let host = flag(args, "--host") ?? "127.0.0.1"
            guard isLoopback(host) else { continue }
            result.append(Runner(port: port, modelPath: flag(args, "--model") ?? ""))
        }
        return result
    }

    private static func slotState(port: Int) -> SlotState {
        guard let url = URL(string: "http://127.0.0.1:\(port)/slots"),
              let data = get(url) else { return .unknown }
        guard let slots = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return .unknown
        }
        let busy = slots.contains { ($0["is_processing"] as? Bool) == true }
        return busy ? .yes : .no
    }

    private static func loadedNames() -> [String] {
        guard let url = URL(string: "http://127.0.0.1:11434/api/ps"),
              let data = get(url),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let models = obj["models"] as? [[String: Any]] else { return [] }
        return models.compactMap { $0["name"] as? String }
    }

    private static func displayName(modelPath: String, names: [String: [String]], loaded: [String]) -> String {
        let digest = normalizeDigest((modelPath as NSString).lastPathComponent)
        let candidates = names[digest] ?? []
        if let hit = loaded.first(where: { candidates.contains($0) }) {
            return hit
        }
        if let shortest = candidates.min(by: { $0.count < $1.count }) {
            return shortest
        }
        return "本地模型"
    }

    private static func namesByDigest() -> [String: [String]] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let roots = [
            home.appendingPathComponent(".ollama/models/manifests"),
            home.appendingPathComponent(".ollama/models/manifests-v2"),
        ]
        var map: [String: [String]] = [:]
        for root in roots {
            guard let enumerator = FileManager.default.enumerator(
                at: root,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) else { continue }
            for case let url as URL in enumerator {
                // 新版本清单是指向 blob 的符号链接，isRegularFile 对链接本身为 false。
                var isDirectory: ObjCBool = false
                guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
                      !isDirectory.boolValue else { continue }
                let relative = url.path.replacingOccurrences(of: root.path + "/", with: "")
                guard let name = modelName(relativePath: relative),
                      let data = try? Data(contentsOf: url),
                      let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let layers = obj["layers"] as? [[String: Any]] else { continue }
                for layer in layers {
                    let media = layer["mediaType"] as? String ?? ""
                    guard media == "application/vnd.ollama.image.model" else { continue }
                    guard let digest = layer["digest"] as? String else { continue }
                    let key = normalizeDigest(digest)
                    var list = map[key] ?? []
                    if !list.contains(name) { list.append(name) }
                    map[key] = list
                }
            }
        }
        return map
    }

    private static func modelName(relativePath: String) -> String? {
        let parts = relativePath.split(separator: "/").map(String.init)
        guard parts.count >= 2 else { return nil }
        let tag = parts[parts.count - 1]
        let name = parts[parts.count - 2]
        if parts.count >= 3, parts[parts.count - 3] != "library" {
            return "\(parts[parts.count - 3])/\(name):\(tag)"
        }
        return "\(name):\(tag)"
    }

    private static func normalizeDigest(_ raw: String) -> String {
        var text = raw
        if let range = text.range(of: "sha256:", options: .caseInsensitive) {
            text = String(text[range.upperBound...])
        } else if let range = text.range(of: "sha256-", options: .caseInsensitive) {
            text = String(text[range.upperBound...])
        }
        return text.lowercased()
    }

    private static func isLoopback(_ host: String) -> Bool {
        switch host.lowercased() {
        case "", "127.0.0.1", "localhost", "::1", "[::1]", "0.0.0.0", "[::]":
            return true
        default:
            return false
        }
    }

    private static func flag(_ args: [String], _ name: String) -> String? {
        for (index, arg) in args.enumerated() {
            if arg == name, index + 1 < args.count {
                return args[index + 1]
            }
            let prefix = name + "="
            if arg.hasPrefix(prefix) {
                return String(arg.dropFirst(prefix.count))
            }
        }
        return nil
    }

    private static func get(_ url: URL) -> Data? {
        var request = URLRequest(url: url)
        request.timeoutInterval = 0.5
        let semaphore = DispatchSemaphore(value: 0)
        var body: Data?
        var succeeded = false
        let task = session.dataTask(with: request) { data, response, _ in
            if let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) {
                body = data
                succeeded = true
            }
            semaphore.signal()
        }
        task.resume()
        if semaphore.wait(timeout: .now() + 0.7) == .timedOut {
            task.cancel()
            return nil
        }
        return succeeded ? body : nil
    }

    private static func allPids() -> [pid_t] {
        let guess = max(proc_listallpids(nil, 0), 1)
        var pids = [pid_t](repeating: 0, count: Int(guess) + 32)
        let bytes = Int32(pids.count * MemoryLayout<pid_t>.size)
        let count = pids.withUnsafeMutableBufferPointer { buffer -> Int32 in
            guard let base = buffer.baseAddress else { return 0 }
            return proc_listallpids(base, bytes)
        }
        guard count > 0 else { return [] }
        return Array(pids.prefix(Int(count)))
    }

    private static func processPath(_ pid: pid_t) -> String {
        var buffer = [CChar](repeating: 0, count: Int(PATH_MAX))
        let length = proc_pidpath(pid, &buffer, UInt32(buffer.count))
        guard length > 0 else { return "" }
        return String(cString: buffer)
    }

    private static func arguments(_ pid: pid_t) -> [String] {
        var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
        var size = 0
        guard sysctl(&mib, 3, nil, &size, nil, 0) == 0, size > 0 else { return [] }
        var data = [UInt8](repeating: 0, count: size)
        let result = data.withUnsafeMutableBytes { raw -> Int32 in
            guard let base = raw.baseAddress else { return -1 }
            return sysctl(&mib, 3, base, &size, nil, 0)
        }
        guard result == 0, size >= 4 else { return [] }
        data.removeLast(data.count - size)
        let argc = data.withUnsafeBytes { $0.load(as: Int32.self) }
        guard argc > 0 else { return [] }
        var index = 4
        while index < data.count, data[index] != 0 { index += 1 }
        while index < data.count, data[index] == 0 { index += 1 }
        var args: [String] = []
        while args.count < argc, index < data.count {
            let start = index
            while index < data.count, data[index] != 0 { index += 1 }
            if start < index, let text = String(bytes: data[start..<index], encoding: .utf8) {
                args.append(text)
            }
            index += 1
        }
        return args
    }
}
