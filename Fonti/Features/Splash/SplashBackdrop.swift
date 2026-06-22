import SwiftUI

struct SplashBackdrop: View {
    private struct SymbolConfig: Identifiable {
        let id = UUID()
        let symbol: String
        let position: CGPoint
        let size: CGFloat
        let rotation: Double
        let opacity: Double
        let driftX: CGFloat
        let driftY: CGFloat
        let duration: Double
    }

    private static let symbolNames = [
        "textformat", "textformat.size", "textformat.abc",
        "textformat.alt", "textformat.subscript", "textformat.superscript",
        "textformat.123",
        "text.alignleft", "text.alignright", "text.aligncenter",
        "text.justify", "text.justify.left",
        "character", "character.book.closed", "character.cursor.ibeam",
        "character.textbox", "character.bubble",
        "pencil", "pencil.tip", "highlighter",
        "bold", "italic", "underline", "strikethrough",
        "a.book.closed", "abc", "books.vertical",
        "text.book.closed"
    ]

    @State private var symbols: [SymbolConfig] = []
    @State private var animating = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(symbols) { config in
                    Image(systemName: config.symbol)
                        .font(.system(size: config.size, weight: .medium))
                        .foregroundStyle(Color.fontiCream.opacity(config.opacity))
                        .rotationEffect(.degrees(config.rotation))
                        .position(
                            x: config.position.x * proxy.size.width,
                            y: config.position.y * proxy.size.height
                        )
                        .offset(
                            x: animating ? config.driftX : -config.driftX,
                            y: animating ? config.driftY : -config.driftY
                        )
                        .animation(
                            .easeInOut(duration: config.duration)
                                .repeatForever(autoreverses: true),
                            value: animating
                        )
                }
            }
            .task {
                if symbols.isEmpty {
                    symbols = Self.makeSymbols()
                }
                try? await Task.sleep(nanoseconds: 50_000_000)
                animating = true
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private static let symbolCount = 42

    private static func makeSymbols() -> [SymbolConfig] {
        (0..<symbolCount).map { _ in
            SymbolConfig(
                symbol: symbolNames.randomElement() ?? "textformat",
                position: CGPoint(
                    x: .random(in: 0.04...0.96),
                    y: .random(in: 0.04...0.96)
                ),
                size: .random(in: 16...38),
                rotation: .random(in: -25...25),
                opacity: .random(in: 0.06...0.16),
                driftX: .random(in: -30...30),
                driftY: .random(in: -30...30),
                duration: .random(in: 4...7)
            )
        }
    }
}
