import Foundation

struct ShellLine: Identifiable {
    let id = UUID()
    let prompt: String?
    let text: String
    let isError: Bool

    init(prompt: String? = nil, text: String, isError: Bool = false) {
        self.prompt = prompt
        self.text = text
        self.isError = isError
    }
}

final class ShellModel {
    var prompt: String = "aurora-shell %"   // MUST be var
    var lines: [ShellLine] = []
}
