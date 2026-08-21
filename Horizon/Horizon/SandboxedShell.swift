#if !os(macOS)
import Foundation
import Combine
import UIKit

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}

final class SandboxedShell: ObservableObject {
    @Published var output: [String] = []
    @Published var cwd: URL
    @Published var editorURL: URL?
    @Published var viewerURL: URL?

    private let root: URL
    private var env: [String: String] = ["HOME": "~", "SHELL": "aurora-shell", "TERM": "xterm-256color", "USER": "aurora-user"]
    private var history: [String] = []

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        root = docs.appendingPathComponent("aurora-shell")
        cwd = root
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        output.append("Aurora Shell ⚡ Sandboxed FS — type 'help' for commands")
        output.append("cwd: ~/aurora-shell")
    }

    func run(_ raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        history.append(trimmed)
        let parts = trimmed.components(separatedBy: " ").filter { !$0.isEmpty }
        guard let cmd = parts.first else { return }
        let args = Array(parts.dropFirst())
        output.append("\(cwd.lastPathComponent) % \(trimmed)")

        switch cmd {
        case "cd":
            let target = resolve(args.first ?? "~")
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: target.path, isDirectory: &isDir), isDir.boolValue {
                cwd = target
            } else { output.append("cd: no such directory: \(args.first ?? "")") }

        case "pwd":
            output.append(cwd.path)

        case "ls":
            let target = resolve(args.first(where: { !$0.hasPrefix("-") }))
            let long = args.contains("-l")
            let all = args.contains("-a")
            let fm = FileManager.default
            var items = (try? fm.contentsOfDirectory(atPath: target.path)) ?? []
            if !all { items = items.filter { !$0.hasPrefix(".") } }
            items.sort()
            if items.isEmpty { output.append("(empty)") }
            else if long {
                items.forEach { name in
                    let url = target.appendingPathComponent(name)
                    let attrs = try? fm.attributesOfItem(atPath: url.path)
                    let size = attrs?[.size] as? Int ?? 0
                    let isDir = (attrs?[.type] as? FileAttributeType) == .typeDirectory
                    output.append("\(isDir ? "d" : "-")rw-r--r--  \(String(format: "%8d", size))  \(name)")
                }
            } else { output.append(items.joined(separator: "  ")) }

        case "touch":
            guard let name = args.first else { output.append("touch: missing operand"); return }
            let url = resolve(name)
            if FileManager.default.fileExists(atPath: url.path) {
                try? FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: url.path)
            } else { FileManager.default.createFile(atPath: url.path, contents: nil) }

        case "mkdir":
            guard let name = args.first(where: { !$0.hasPrefix("-") }) else { output.append("mkdir: missing operand"); return }
            do { try FileManager.default.createDirectory(at: resolve(name), withIntermediateDirectories: args.contains("-p")) }
            catch { output.append("mkdir: \(error.localizedDescription)") }

        case "rmdir":
            guard let name = args.first else { output.append("rmdir: missing operand"); return }
            do { try FileManager.default.removeItem(at: resolve(name)) }
            catch { output.append("rmdir: \(error.localizedDescription)") }

        case "rm":
            guard let name = args.first(where: { !$0.hasPrefix("-") }) else { output.append("rm: missing operand"); return }
            do { try FileManager.default.removeItem(at: resolve(name)) }
            catch { output.append("rm: \(error.localizedDescription)") }

        case "cp":
            guard args.count >= 2 else { output.append("cp: missing operand"); return }
            let src = args.first(where: { !$0.hasPrefix("-") })!
            let dst = args.last!
            do { try FileManager.default.copyItem(at: resolve(src), to: resolve(dst)) }
            catch { output.append("cp: \(error.localizedDescription)") }

        case "mv":
            guard args.count >= 2 else { output.append("mv: missing operand"); return }
            do { try FileManager.default.moveItem(at: resolve(args[0]), to: resolve(args[1])) }
            catch { output.append("mv: \(error.localizedDescription)") }

        case "cat":
            guard let name = args.first else { output.append("cat: missing operand"); return }
            if let text = try? String(contentsOf: resolve(name), encoding: .utf8) {
                text.components(separatedBy: "\n").forEach { output.append($0) }
            } else { output.append("cat: \(name): No such file or directory") }

        case "stat":
            guard let name = args.first else { output.append("stat: missing operand"); return }
            let url = resolve(name)
            if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path) {
                let size = attrs[.size] as? Int ?? 0
                let mod = attrs[.modificationDate] as? Date ?? Date()
                let isDir = (attrs[.type] as? FileAttributeType) == .typeDirectory
                output.append("  File: \(name)  Type: \(isDir ? "directory" : "regular file")")
                output.append("  Size: \(size) bytes  Modified: \(mod)")
            } else { output.append("stat: \(name): No such file or directory") }

        case "file":
            guard let name = args.first else { output.append("file: missing operand"); return }
            let url = resolve(name)
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) {
                output.append("\(name): \(isDir.boolValue ? "directory" : "ASCII text")")
            } else { output.append("file: \(name): No such file or directory") }

        case "zip":
            guard args.count >= 2 else { output.append("zip: usage: zip archive.zip file"); return }
            let dst = resolve(args[0])
            let src = resolve(args[1])
            do {
                let data = try Data(contentsOf: src)
                try data.write(to: dst)
                output.append("  adding: \(args[1])")
            } catch { output.append("zip: \(error.localizedDescription)") }

        case "unzip":
            guard let name = args.first else { output.append("unzip: missing operand"); return }
            output.append("unzip: \(name): not a zip file (sandboxed)")

        case "echo":
            let text = args.joined(separator: " ")
            output.append(text.replacingOccurrences(of: "\\n", with: "\n"))

        case "printf":
            output.append(args.dropFirst().joined(separator: " "))

        case "grep":
            guard args.count >= 2 else { output.append("grep: usage: grep pattern file"); return }
            let pattern = args[0]; let fname = args[1]
            if let text = try? String(contentsOf: resolve(fname), encoding: .utf8) {
                let matches = text.components(separatedBy: "\n").filter { $0.contains(pattern) }
                if matches.isEmpty { output.append("(no matches)") }
                else { matches.forEach { output.append($0) } }
            } else { output.append("grep: \(fname): No such file or directory") }

        case "wc":
            guard let name = args.first(where: { !$0.hasPrefix("-") }) else { output.append("wc: missing operand"); return }
            if let text = try? String(contentsOf: resolve(name), encoding: .utf8) {
                let l = text.components(separatedBy: "\n").count
                let w = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
                output.append("\t\(l)\t\(w)\t\(text.count)\t\(name)")
            } else { output.append("wc: \(name): No such file or directory") }

        case "head":
            let n = args.first == "-n" ? Int(args[safe: 1] ?? "10") ?? 10 : 10
            let name = args.first(where: { !$0.hasPrefix("-") }) ?? ""
            if let text = try? String(contentsOf: resolve(name), encoding: .utf8) {
                text.components(separatedBy: "\n").prefix(n).forEach { output.append($0) }
            } else { output.append("head: \(name): No such file or directory") }

        case "tail":
            let n = args.first == "-n" ? Int(args[safe: 1] ?? "10") ?? 10 : 10
            let name = args.first(where: { !$0.hasPrefix("-") }) ?? ""
            if let text = try? String(contentsOf: resolve(name), encoding: .utf8) {
                text.components(separatedBy: "\n").suffix(n).forEach { output.append($0) }
            } else { output.append("tail: \(name): No such file or directory") }

        case "sort":
            guard let name = args.first(where: { !$0.hasPrefix("-") }) else { output.append("sort: missing operand"); return }
            if let text = try? String(contentsOf: resolve(name), encoding: .utf8) {
                let sorted = args.contains("-r")
                    ? text.components(separatedBy: "\n").sorted().reversed().map { String($0) }
                    : text.components(separatedBy: "\n").sorted()
                sorted.forEach { output.append($0) }
            } else { output.append("sort: \(name): No such file or directory") }

        case "uniq":
            guard let name = args.first(where: { !$0.hasPrefix("-") }) else { output.append("uniq: missing operand"); return }
            if let text = try? String(contentsOf: resolve(name), encoding: .utf8) {
                var last = ""
                text.components(separatedBy: "\n").forEach { line in
                    if line != last { output.append(line); last = line }
                }
            } else { output.append("uniq: \(name): No such file or directory") }

        case "vim", "nano", "emacs", "vi":
            guard let name = args.first else { output.append("\(cmd): usage: \(cmd) filename"); return }
            let url = resolve(name)
            if !FileManager.default.fileExists(atPath: url.path) {
                FileManager.default.createFile(atPath: url.path, contents: nil)
            }
            DispatchQueue.main.async { self.editorURL = url }

        case "open":
            guard let name = args.first else { output.append("open: missing operand"); return }
            if name.hasPrefix("-/") {
                let path = String(name.dropFirst(2))
                let url = resolve(path)
                if let filesURL = URL(string: "shareddocuments://\(url.path)") {
                    DispatchQueue.main.async { UIApplication.shared.open(filesURL) }
                }
            } else {
                let url = resolve(name)
                var isDir: ObjCBool = false
                if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) {
                    if isDir.boolValue {
                        cwd = url
                        output.append("cd: \(url.lastPathComponent)")
                    } else {
                        DispatchQueue.main.async { self.viewerURL = url }
                    }
                } else { output.append("open: \(name): No such file or directory") }
            }

        case "curl", "wget":
            guard let urlStr = args.first(where: { !$0.hasPrefix("-") }),
                  let url = URL(string: urlStr) else {
                output.append("\(cmd): invalid URL"); return
            }
            output.append("\(cmd): fetching \(urlStr)...")
            let task = URLSession.shared.dataTask(with: url) { data, response, error in
                DispatchQueue.main.async {
                    if let error { self.output.append("\(cmd): \(error.localizedDescription)"); return }
                    let http = response as? HTTPURLResponse
                    self.output.append("HTTP \(http?.statusCode ?? 0)")
                    if let data, let text = String(data: data, encoding: .utf8) {
                        text.components(separatedBy: "\n").prefix(50).forEach { self.output.append($0) }
                        if text.components(separatedBy: "\n").count > 50 { self.output.append("... (truncated)") }
                    }
                }
            }
            task.resume()

        case "ssh", "ftp", "sftp":
            output.append("\(cmd): not available on iOS sandbox")

        case "python", "python3", "node", "ruby", "perl", "php":
            output.append("\(cmd): not available on iOS sandbox")

        case "ps":
            output.append("  PID  COMMAND")
            output.append("    1  aurora-shell")
        case "kill":
            output.append("kill: not available on iOS sandbox")
        case "top", "htop":
            output.append("\(cmd): not available on iOS sandbox")

        case "env", "printenv":
            env.sorted(by: { $0.key < $1.key }).forEach { output.append("\($0.key)=\($0.value)") }
        case "export":
            guard let pair = args.first, pair.contains("=") else { output.append("export: usage: export KEY=VALUE"); return }
            let kv = pair.components(separatedBy: "=")
            env[kv[0]] = kv.dropFirst().joined(separator: "=")
        case "unset":
            guard let key = args.first else { output.append("unset: missing operand"); return }
            env.removeValue(forKey: key)

        case "history":
            history.enumerated().forEach { output.append("  \($0.offset + 1)  \($0.element)") }
        case "date":
            output.append(Date().description)
        case "whoami":
            output.append("aurora-user")
        case "uname":
            output.append(args.contains("-a") ? "Aurora-Shell iOS sandboxed arm64" : "Aurora-Shell")
        case "hostname":
            output.append("aurora-shell.local")
        case "uptime":
            output.append("aurora-shell up, load average: 0.00")
        case "df":
            if let attrs = try? FileManager.default.attributesOfFileSystem(forPath: root.path) {
                let free = (attrs[.systemFreeSize] as? Int ?? 0) / 1_000_000
                let total = (attrs[.systemSize] as? Int ?? 0) / 1_000_000
                output.append("Filesystem      Size  Used  Avail")
                output.append("sandbox         \(total)M  \(total - free)M  \(free)M")
            }
        case "du":
            let name = args.first(where: { !$0.hasPrefix("-") }) ?? "."
            let url = resolve(name)
            let size = directorySize(url) / 1024
            output.append("\(size)K\t\(name)")

        case "man":
            guard let topic = args.first else { output.append("man: missing operand"); return }
            output.append(manPage(topic))

        case "true": break
        case "false":
            output.append("false: exit 1")
        case "sleep":
            output.append("sleep: \(args.first ?? "0")s (no-op in sandbox)")
        case "clear", "reset":
            output.removeAll()
        case "exit", "quit":
            output.append("exit: cannot exit sandboxed shell")
        case "help":
            output.append("""
            Navigation:  cd  pwd  ls
            Files:       cat  touch  rm  mkdir  rmdir  cp  mv  stat  file  open  zip
            Editors:     vim  nano  emacs  vi
            Text:        echo  grep  wc  head  tail  sort  uniq  printf
            Network:     curl  wget
            System:      env  export  unset  history  date  whoami  uname  hostname  df  du  ps  uptime
            Info:        man  help
            Unavailable: ssh  ftp  python  node  ruby  kill  top
            """)
        default:
            output.append("\(cmd): command not found")
            output.append("Type 'help' for available commands")
        }
    }

    private func resolve(_ path: String?) -> URL {
        guard let path, !path.isEmpty else { return cwd }
        if path == "~" { return root }
        if path == "." { return cwd }
        if path == ".." { return cwd != root ? cwd.deletingLastPathComponent() : root }
        if path.hasPrefix("~/") { return root.appendingPathComponent(String(path.dropFirst(2))) }
        if path.hasPrefix("/") { return root.appendingPathComponent(String(path.dropFirst())) }
        return cwd.appendingPathComponent(path)
    }

    private func directorySize(_ url: URL) -> Int {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
        return enumerator.compactMap { ($0 as? URL).flatMap { try? $0.resourceValues(forKeys: [.fileSizeKey]).fileSize } }.reduce(0, +)
    }

    private func manPage(_ cmd: String) -> String {
        let pages: [String: String] = [
            "ls": "ls [-la] [dir] — list directory contents",
            "cd": "cd [dir] — change directory",
            "pwd": "pwd — print working directory",
            "cat": "cat file — print file contents",
            "rm": "rm [-r] file — remove file",
            "mkdir": "mkdir [-p] dir — make directory",
            "cp": "cp src dst — copy file",
            "mv": "mv src dst — move/rename file",
            "grep": "grep pattern file — search for pattern",
            "curl": "curl url — fetch URL",
            "wget": "wget url — download URL",
            "vim": "vim file — open file in editor",
            "open": "open ~/file (in-app) or open -/file (Files app)",
            "echo": "echo text — print text",
            "wc": "wc file — word/line/char count",
            "head": "head [-n N] file — first N lines",
            "tail": "tail [-n N] file — last N lines",
            "sort": "sort [-r] file — sort lines",
            "history": "history — show command history",
            "df": "df — disk free space",
            "du": "du [path] — disk usage",
        ]
        return pages[cmd] ?? "man: no manual entry for \(cmd)"
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
#endif
