import SwiftUI

struct MainView: View {
    var body: some View {
#if os(macOS)
        MacTerminalView()
#else
        NotMacView()
#endif
    }
}

#if os(macOS)
private struct MacTerminalView: View {
    @StateObject private var engine = TerminalEngine()
    @State private var isLocked: Bool = true  // lock on launch

    var body: some View {
        ZStack {
            LiquidBackground()
            TerminalViewRepresentable(engine: engine)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.15), lineWidth: 1))
                .padding(12)
                .blur(radius: isLocked ? 12 : 0)
                .allowsHitTesting(!isLocked)
                .animation(.easeInOut(duration: 0.3), value: isLocked)

            if isLocked {
                LockScreenView(isLocked: $isLocked)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.3), value: isLocked)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    withAnimation { isLocked = true }
                } label: {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(.white.opacity(0.7))
                }
                .help("Lock Terminal")
                .disabled(isLocked)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .lockTerminal)) { _ in
            withAnimation { isLocked = true }
        }
    }
}

extension Notification.Name {
    static let lockTerminal = Notification.Name("aurora.lockTerminal")
}
#endif
