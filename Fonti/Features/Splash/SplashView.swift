import SwiftUI

struct SplashView: View {
    let onComplete: () -> Void

    @State private var fontIndex = 0
    @State private var didComplete = false

    private let perFontHold: UInt64 = 650_000_000
    private let finalHold: UInt64 = 1_500_000_000

    var body: some View {
        ZStack {
            Color.fontiInk
            SplashBackdrop()
            SplashWordmark(index: fontIndex)
        }
        // The whole stack, not just the colour. Putting `ignoresSafeArea` on
        // the fill alone left the ZStack sized to the safe area, so on iPhone
        // Duo — where the vertical bar takes ~84pt off the trailing edge — the
        // wordmark centred on 867pt of a 951pt display and sat 42pt, exactly
        // half the inset, left of true centre. A splash has nothing to protect
        // from the edges, so it should centre on the display itself.
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .onTapGesture { complete() }
        .task { await runSequence() }
    }

    private func runSequence() async {
        for i in 1..<SplashWordmark.steps.count {
            try? await Task.sleep(nanoseconds: perFontHold)
            if didComplete { return }
            withAnimation(.easeInOut(duration: 0.45)) {
                fontIndex = i
            }
        }
        try? await Task.sleep(nanoseconds: finalHold)
        complete()
    }

    private func complete() {
        guard !didComplete else { return }
        didComplete = true
        onComplete()
    }
}
