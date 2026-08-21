#if os(macOS)
import SwiftUI
import SwiftTerm
import Combine

struct TerminalViewRepresentable: NSViewRepresentable {
    let engine: TerminalEngine

    func makeCoordinator() -> Coordinator { Coordinator(engine: engine) }

    func makeNSView(context: Context) -> TerminalView {
        let term = TerminalView(frame: .zero)
        term.terminalDelegate = context.coordinator
        term.nativeBackgroundColor = .clear
        term.wantsLayer = true
        term.layer?.backgroundColor = .clear
        let cols = term.terminal.cols > 0 ? term.terminal.cols : 80
        let rows = term.terminal.rows > 0 ? term.terminal.rows : 24
        engine.start(cols: cols, rows: rows)
        engine.output
            .receive(on: DispatchQueue.main)
            .sink { data in term.feed(byteArray: ArraySlice(data)) }
            .store(in: &context.coordinator.cancellables)
        return term
    }

    func updateNSView(_ nsView: TerminalView, context: Context) {}

    class Coordinator: NSObject, TerminalViewDelegate {
        var cancellables = Set<AnyCancellable>()
        let engine: TerminalEngine

        init(engine: TerminalEngine) { self.engine = engine }

        func send(source: TerminalView, data: ArraySlice<UInt8>) { engine.sendRaw(Data(data)) }
        func sizeChanged(source: TerminalView, newCols: Int, newRows: Int) {
            engine.setSize(cols: newCols, rows: newRows)
        }
        func setTerminalTitle(source: TerminalView, title: String) {}
        func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}
        func scrolled(source: TerminalView, position: Double) {}
        func requestOpenLink(source: TerminalView, link: String, params: [String: String]) {}
        func bell(source: TerminalView) {}
        func clipboardCopy(source: TerminalView, content: Data) {}
        func iTermContent(source: TerminalView, content: ArraySlice<UInt8>) {}
        func rangeChanged(source: TerminalView, startY: Int, endY: Int) {}
    }
}
#endif
