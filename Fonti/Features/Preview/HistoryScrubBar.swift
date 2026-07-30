import SwiftUI
import UIKit

/// Camera-filter style scrubber for recent preview strings.
struct HistoryScrubBar: View {
    let entries: [String]
    /// What's on the specimen right now (may differ until user scrubs).
    let currentText: String
    @Binding var selectedIndex: Int
    var onSelect: (String) -> Void

    @AppStorage("fonti.hapticsEnabled") private var hapticsEnabled: Bool = true

    private var safeIndex: Int {
        guard !entries.isEmpty else { return 0 }
        return min(max(selectedIndex, 0), entries.count - 1)
    }

    private var label: String {
        let trimmed = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "—" : trimmed
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                scrubButton(systemName: "chevron.left", enabled: safeIndex < entries.count - 1) {
                    step(+1) // older
                }

                Text(label)
                    .font(.footnote)
                    .foregroundStyle(Color.fontiCream.opacity(0.75))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
                    .contentTransition(.opacity)

                scrubButton(systemName: "chevron.right", enabled: safeIndex > 0) {
                    step(-1) // newer
                }
            }

            if entries.count > 1 {
                HStack(spacing: 5) {
                    ForEach(0..<min(entries.count, 8), id: \.self) { i in
                        Circle()
                            .fill(Color.fontiCream.opacity(i == safeIndex ? 0.85 : 0.22))
                            .frame(width: i == safeIndex ? 6 : 4, height: i == safeIndex ? 6 : 4)
                    }
                }
                .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .glassEffect(in: .rect(cornerRadius: 18))
        .gesture(dragGesture)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Preview text history")
        .accessibilityValue(label)
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: step(-1)
            case .decrement: step(+1)
            @unknown default: break
            }
        }
    }

    private func scrubButton(systemName: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.fontiCream.opacity(enabled ? 0.85 : 0.25))
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { value in
                if value.translation.width < -40 {
                    step(+1) // swipe left → older
                } else if value.translation.width > 40 {
                    step(-1) // swipe right → newer
                }
            }
    }

    private func step(_ delta: Int) {
        guard !entries.isEmpty else { return }
        let next = min(max(safeIndex + delta, 0), entries.count - 1)
        guard next != safeIndex else { return }

        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
            selectedIndex = next
        }
        onSelect(entries[next])

        if hapticsEnabled {
            UISelectionFeedbackGenerator().selectionChanged()
        }
    }
}
