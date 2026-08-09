import SwiftUI
#if os(macOS)
import Intents
#endif

@main
struct Aurora_shellApp: App {
    var body: some Scene {
#if os(macOS)
        WindowGroup {
            MainView()
                .preferredColorScheme(.dark)
                .onOpenURL { url in
                    // shell.aurora posts aurora-shell://lock to trigger lock screen
                    if url.host == "lock" {
                        NotificationCenter.default.post(name: .lockTerminal, object: nil)
                    } else if url.host == "newtab" {
                        NotificationCenter.default.post(name: .newTerminalTab, object: nil)
                    }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1100, height: 700)
        .commands {
            CommandGroup(after: .newItem) {
                Button("New Tab") {
                    NotificationCenter.default.post(name: .newTerminalTab, object: nil)
                }
                .keyboardShortcut("t", modifiers: .command)
            }
        }
#else
        WindowGroup {
            MainView()
                .preferredColorScheme(.dark)
        }
#endif
    }
}
