#if !os(macOS)
import SwiftUI

struct EditorView: View {
    let url: URL
    let onClose: () -> Void
    @State private var text: String = ""
    @State private var saved = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Text(url.lastPathComponent)
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(.green)
                    Spacer()
                    Button("Save") {
                        try? text.write(to: url, atomically: true, encoding: .utf8)
                        saved = true
                    }
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(.green)
                    Button("Close") { onClose() }
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundStyle(.green)
                        .padding(.leading, 12)
                }
                .padding(12)
                .background(.black.opacity(0.8))

                TextEditor(text: $text)
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(.green)
                    .scrollContentBackground(.hidden)
                    .background(Color.black)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
        }
        .onAppear { text = (try? String(contentsOf: url, encoding: .utf8)) ?? "" }
        .overlay(alignment: .top) {
            if saved {
                Text("Saved").foregroundStyle(.green).padding(8)
                    .background(.black.opacity(0.8)).clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.top, 50)
                    .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { saved = false } }
            }
        }
    }
}
#endif
