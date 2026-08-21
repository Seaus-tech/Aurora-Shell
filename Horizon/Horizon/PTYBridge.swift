#if os(macOS)
import Foundation
import Darwin

@discardableResult
func spawnShellWithPTY(shellPath: String = "/bin/zsh", cols: Int = 80, rows: Int = 24) -> Int32 {
    var masterFD: Int32 = -1
    var ws = winsize(ws_row: UInt16(rows), ws_col: UInt16(cols), ws_xpixel: 0, ws_ypixel: 0)
    let pid = forkpty(&masterFD, nil, nil, &ws)
    if pid == -1 { perror("forkpty"); return -1 }
    if pid == 0 {
        setenv("TERM", "xterm-256color", 1)
        setenv("COLORTERM", "truecolor", 1)
        let args: [UnsafeMutablePointer<CChar>?] = [strdup(shellPath), strdup("-l"), nil]
        execv(shellPath, args)
        perror("execv")
        _exit(1)
    }
    return masterFD
}
#endif
