import SwiftUI
import UIKit


struct SpecimenCard<Content: View>: View {
    let background: PreviewBackground
    let customImage: UIImage?
    let rotationY: Double
    var isFlipping: Bool = false
    var compact: Bool = false
    var onTap: (() -> Void)? = nil
    @ViewBuilder var content: () -> Content

    @AppStorage("fonti.hapticsEnabled") private var hapticsEnabled: Bool = true

    @State private var drag: CGSize = .zero
    @State private var isDragging = false

    private var corner: CGFloat { compact ? 22 : 28 }
    private let maxTilt: Double = 14

    var body: some View {
        GeometryReader { geo in
            let size = geo.size

            ZStack {
                if background != .liquidGlass {
                    background
                        .fill(customImage: customImage)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                }

                content()
                    .padding(.horizontal, compact ? 16 : 28)
                    .padding(.vertical, compact ? 12 : 36)

                // Soft glare that tracks the finger — sells the “physical” surface.
                glare(in: size)
                    .opacity(isDragging && !isFlipping ? 1 : 0)
                    .allowsHitTesting(false)
            }
            .frame(width: size.width, height: size.height)
            .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
            .modifier(LiquidGlassCardModifier(enabled: background == .liquidGlass, corner: corner))
            .overlay {
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .strokeBorder(
                        Color.fontiCream.opacity(background == .cream ? 0 : 0.08),
                        lineWidth: 1
                    )
            }
            .compositingGroup()
            .shadow(
                color: .black.opacity(isDragging ? 0.45 : 0.32),
                radius: isDragging ? 28 : 18,
                x: tiltY * 0.6,
                y: 10 + abs(tiltX) * 0.4
            )
            // Finger tilt (disabled while the background flip owns the Y axis).
            .rotation3DEffect(
                .degrees(isFlipping ? 0 : tiltX),
                axis: (x: 1, y: 0, z: 0),
                perspective: 0.55
            )
            .rotation3DEffect(
                .degrees(rotationY + (isFlipping ? 0 : tiltY)),
                axis: (x: 0, y: 1, z: 0),
                perspective: 0.55
            )
            .scaleEffect(isDragging && !isFlipping && !compact ? 0.985 : 1)
            .gesture(compact ? nil : tiltGesture(in: size))
        }
        // Idle: board aspect. Editing: short strip that leaves room for the keyboard.
        .modifier(SpecimenCardSizing(compact: compact))
        .animation(.interactiveSpring(response: 0.28, dampingFraction: 0.72), value: drag)
        .animation(.spring(response: 0.36, dampingFraction: 0.78), value: isDragging)
    }

    // MARK: - Tilt math

    /// Finger below center → top edge tips toward you (negative X).
    private var tiltX: Double {
        clamped(-Double(drag.height) / 12, limit: maxTilt)
    }

    /// Finger right of center → left edge tips toward you (positive Y).
    private var tiltY: Double {
        clamped(Double(drag.width) / 12, limit: maxTilt)
    }

    private func clamped(_ value: Double, limit: Double) -> Double {
        min(max(value, -limit), limit)
    }

    private func glare(in size: CGSize) -> some View {
        let cx = 0.5 + (drag.width / max(size.width, 1)) * 0.55
        let cy = 0.5 + (drag.height / max(size.height, 1)) * 0.55

        return RadialGradient(
            colors: [
                Color.white.opacity(0.28),
                Color.white.opacity(0.06),
                .clear,
            ],
            center: UnitPoint(x: cx, y: cy),
            startRadius: 4,
            endRadius: max(size.width, size.height) * 0.65
        )
        .blendMode(.softLight)
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
    }

    private func tiltGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                guard !isFlipping else { return }

                if !isDragging {
                    isDragging = true
                    if hapticsEnabled {
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.55)
                    }
                }

                // Offset from card center so tilt matches where you’re pressing.
                drag = CGSize(
                    width: value.location.x - size.width / 2,
                    height: value.location.y - size.height / 2
                )
            }
            .onEnded { value in
                let travel = hypot(value.translation.width, value.translation.height)

                withAnimation(.spring(response: 0.42, dampingFraction: 0.68)) {
                    drag = .zero
                    isDragging = false
                }

                // Light press without a real drag → treat as tap (open editor).
                if travel < 10, !isFlipping {
                    onTap?()
                }
            }
    }
}

private struct SpecimenCardSizing: ViewModifier {
    let compact: Bool

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity)
            .aspectRatio(compact ? 2.2 : 1.2, contentMode: .fit)
            .frame(maxHeight: compact ? 148 : .infinity)
    }
}

private struct LiquidGlassCardModifier: ViewModifier {
    let enabled: Bool
    let corner: CGFloat

    func body(content: Content) -> some View {
        if enabled {
            content.glassEffect(in: .rect(cornerRadius: corner))
        } else {
            content
        }
    }
}
