#if os(macOS)
import Foundation
import Combine

final class ShellViewModel: ObservableObject {
    @Published var lines: [ShellLine] = []
    private let engine = TerminalEngine()
    private var cancellables = Set<AnyCancellable>()

    init() {
        engine.output
            .receive(on: DispatchQueue.main)
            .sink { [weak self] data in
                if let text = String(data: data, encoding: .utf8) {
                    self?.lines.append(ShellLine(text: text))
                }
            }
            .store(in: &cancellables)
        engine.start()
    }

    func handle(command: String) {
        lines.append(ShellLine(text: command))
        engine.sendRaw((command + "\n").data(using: .utf8)!)
    }
}
#endif
