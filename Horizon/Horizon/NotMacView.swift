#if !os(macOS)
import SwiftUI

struct NotMacView: View {
    @StateObject private var shell = SandboxedShell()
    @State private var input = ""
    @FocusState private var focused: Bool

    var body: some View {
        ZStack(alignment: .bottom) {
            LiquidBackground()

            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(Array(shell.output.enumerated()), id: \.offset) { _, line in
                                Text(line)
                                    .font(.system(.footnote, design: .monospaced))
                                    .foregroundStyle(.green)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .padding(12)
                        .id("bottom")
                    }
                    .onChange(of: shell.output.count) { _, _ in
                        withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
                    }
                }

                HStack {
                    Text("\(shell.cwd.lastPathComponent) %")
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(.green)
                        .fixedSize()
                    TextField("command", text: $input)
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(.green)
                        .tint(.green)
                        .focused($focused)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onSubmit {
                            shell.run(input)
                            input = ""
                        }
                }
                .padding(12)
                .background(.black.opacity(0.6))
            }
            .background(.ultraThinMaterial.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.15), lineWidth: 1))
            .padding(12)
        }
        .ignoresSafeArea(.keyboard)
        .onAppear { focused = true }
        .sheet(item: $shell.editorURL) { url in
            EditorView(url: url) { shell.editorURL = nil }
        }
        .sheet(item: $shell.viewerURL) { url in
            FileViewerView(url: url) { shell.viewerURL = nil }
        }
    }
}
#endif
