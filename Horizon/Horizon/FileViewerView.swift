#if !os(macOS)
import SwiftUI

struct FileViewerView: View {
    let url: URL
    let onClose: () -> Void
    @State private var text: String = ""

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Text(url.lastPathComponent)
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(.green)
                    Spacer()
                    Button("Close") { onClose() }
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(.green)
                }
                .padding(12)
                .background(.black.opacity(0.8))

                ScrollView {
                    Text(text)
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(.green)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                }
            }
        }
        .onAppear { text = (try? String(contentsOf: url, encoding: .utf8)) ?? "(binary file)" }
    }
}
#endif
