import SwiftUI

struct LiquidBackground: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let w = size.width, h = size.height
                // Deep space base
                ctx.fill(Path(CGRect(origin: .zero, size: size)),
                         with: .color(Color(red: 0.02, green: 0.02, blue: 0.08)))

                // Aurora blobs
                let blobs: [(CGFloat, CGFloat, CGFloat, CGFloat, Color)] = [
                    (0.2, 0.3, 0.55, 0.35, Color(red: 0.0, green: 0.8, blue: 0.6)),
                    (0.6, 0.5, 0.50, 0.30, Color(red: 0.4, green: 0.2, blue: 0.9)),
                    (0.4, 0.7, 0.45, 0.25, Color(red: 0.0, green: 0.6, blue: 1.0)),
                    (0.8, 0.2, 0.40, 0.28, Color(red: 0.8, green: 0.1, blue: 0.6)),
                ]
                for (bx, by, bw, bh, color) in blobs {
                    let ox = sin(t * 0.4 + bx * 5) * 0.08
                    let oy = cos(t * 0.3 + by * 4) * 0.06
                    let cx = (bx + ox) * w
                    let cy = (by + oy) * h
                    let rx = bw * w
                    let ry = bh * h
                    let rect = CGRect(x: cx - rx, y: cy - ry, width: rx * 2, height: ry * 2)
                    ctx.fill(Path(ellipseIn: rect),
                             with: .color(color.opacity(0.25)))
                }
            }
        }
        .ignoresSafeArea()
    }
}
