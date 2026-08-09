import SwiftUI
#if os(macOS)
import Intents
#endif

// MARK: - Tab Model
struct TerminalTab: Identifiable {
    let id = UUID()
    var title: String
    let engine: TerminalEngine

    init(index: Int) {
        self.title = "Shell \(index)"
        self.engine = TerminalEngine()
    }
}

// MARK: - Main Entry
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
    @State private var tabs: [TerminalTab] = [TerminalTab(index: 1)]
    @State private var selectedTab: UUID? = nil
    @State private var isLocked: Bool = true

    var activeTab: TerminalTab? {
        tabs.first { $0.id == selectedTab } ?? tabs.first
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── Tab Bar ──────────────────────────────────────────────
            HStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(tabs) { tab in
                            TabButton(
                                tab: tab,
                                isSelected: (selectedTab ?? tabs.first?.id) == tab.id,
                                onSelect: { selectedTab = tab.id },
                                onClose: { closeTab(tab) }
                            )
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                }

                // New tab button
                Button {
                    addTab()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.trailing, 8)
            }
            .background(.ultraThinMaterial)
            .overlay(alignment: .bottom) {
                Divider().opacity(0.3)
            }

            // ── Terminal Area ────────────────────────────────────────
            ZStack {
                LiquidBackground()

                if let tab = activeTab {
                    TerminalViewRepresentable(engine: tab.engine)
                        .background(.clear)
                        .padding(8)
                        .blur(radius: isLocked ? 12 : 0)
                        .allowsHitTesting(!isLocked)
                        .animation(.easeInOut(duration: 0.3), value: isLocked)
                        .id(tab.id) // re-create view when tab changes
                }

                if isLocked {
                    LockScreenView(isLocked: $isLocked)
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                }
            }
            .animation(.easeInOut(duration: 0.3), value: isLocked)
        }
        .ignoresSafeArea(edges: .bottom)
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
                .keyboardShortcut("l", modifiers: [.command, .shift])
            }

            ToolbarItem(placement: .automatic) {
                Button { addTab() } label: {
                    Image(systemName: "plus.square")
                        .foregroundStyle(.white.opacity(0.7))
                }
                .help("New Tab")
                .keyboardShortcut("t", modifiers: .command)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .lockTerminal)) { _ in
            withAnimation { isLocked = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: .newTerminalTab)) { _ in
            addTab()
        }
    }

    func addTab() {
        let tab = TerminalTab(index: tabs.count + 1)
        tabs.append(tab)
        selectedTab = tab.id
    }

    func closeTab(_ tab: TerminalTab) {
        guard tabs.count > 1 else { return }
        if selectedTab == tab.id {
            let idx = tabs.firstIndex(where: { $0.id == tab.id }) ?? 0
            let nextIdx = idx > 0 ? idx - 1 : 1
            selectedTab = tabs[nextIdx].id
        }
        tabs.removeAll { $0.id == tab.id }
    }
}

// MARK: - Tab Button
private struct TabButton: View {
    let tab: TerminalTab
    let isSelected: Bool
    let onSelect: () -> Void
    let onClose: () -> Void
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "terminal")
                .font(.system(size: 10))
                .foregroundStyle(isSelected ? .white : .white.opacity(0.5))

            Text(tab.title)
                .font(.system(size: 12))
                .foregroundStyle(isSelected ? .white : .white.opacity(0.5))
                .lineLimit(1)

            Button {
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.white.opacity(hovering ? 0.8 : 0.3))
            }
            .buttonStyle(.plain)
            .opacity(hovering || isSelected ? 1 : 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.white.opacity(0.12) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.white.opacity(isSelected ? 0.15 : 0), lineWidth: 1)
        )
        .onTapGesture { onSelect() }
        .onHover { hovering = $0 }
    }
}

// MARK: - Notifications
extension Notification.Name {
    static let lockTerminal  = Notification.Name("aurora.lockTerminal")
    static let newTerminalTab = Notification.Name("aurora.newTerminalTab")
}
#endif
