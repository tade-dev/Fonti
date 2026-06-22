import SwiftUI

struct SplashView: View {
    let onComplete: () -> Void

    @State private var fontIndex = 0
    @State private var didComplete = false

    private let perFontHold: UInt64 = 650_000_000
    private let finalHold: UInt64 = 1_500_000_000

    var body: some View {
        ZStack {
            Color.fontiInk.ignoresSafeArea()
            SplashBackdrop()
            SplashWordmark(index: fontIndex)
        }
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
