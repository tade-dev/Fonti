//
//  CustomTabBar.swift
//  Adapted from Kavsoft InstagramStyleTabBar (Balaji Venkatesh)
//

import SwiftUI

extension View {
    @ViewBuilder
    func hideNativeTabBar() -> some View {
        self
            .toolbarVisibility(.hidden, for: .tabBar)
    }
}

extension ScrollView {
    @ViewBuilder
    func adoptForIGTabBar(_ progress: Binding<CGFloat>) -> some View {
        self
            .modifier(IGTabBarViewModifier(progress: progress))
    }
}

struct IGStyleTabBar<Value: CaseIterable>: UIViewRepresentable where Value: Hashable {
    @Binding var selection: Value
    var symbolImage: (Value) -> UIImage
    var onInteraction: () -> Void

    func makeUIView(context: Context) -> CustomSegmentedControl {
        let images = Array(Value.allCases).compactMap(symbolImage)
        let control = CustomSegmentedControl(items: images)
        control.selectedSegmentIndex = Array(Value.allCases).firstIndex(of: selection) ?? 0
        control.selectedSegmentTintColor = UIColor(Color.gray.opacity(0.25))
        control.addTarget(
            context.coordinator,
            action: #selector(context.coordinator.valueChanged(_:)),
            for: .valueChanged
        )

        control.onTouchBegan = onInteraction

        /// Removing Background
        DispatchQueue.main.async {
            for subview in control.subviews {
                if subview is UIImageView && subview != control.subviews.last {
                    subview.alpha = 0
                }
            }
        }

        return control
    }

    func updateUIView(_ uiView: CustomSegmentedControl, context: Context) {
        /// Updating Control, if there is an outside update
        let selectedIndex = Array(Value.allCases).firstIndex(of: selection) ?? 0
        if uiView.selectedSegmentIndex != selectedIndex {
            uiView.selectedSegmentIndex = selectedIndex
        }
    }

    /// Custom Sizing!
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: CustomSegmentedControl, context: Context) -> CGSize? {
        .init(
            width: proposal.replacingUnspecifiedDimensions().width,
            height: 50
        )
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    class Coordinator: NSObject {
        var parent: IGStyleTabBar
        init(parent: IGStyleTabBar) {
            self.parent = parent
        }

        @objc
        func valueChanged(_ sender: UISegmentedControl) {
            parent.selection = Array(Value.allCases)[sender.selectedSegmentIndex]
        }
    }
}

class CustomSegmentedControl: UISegmentedControl {
    var onTouchBegan: (() -> Void)?

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        onTouchBegan?()
    }
}

fileprivate struct IGTabBarViewModifier: ViewModifier {
    /// 0- means expanded
    /// 1- means minimized
    @Binding var progress: CGFloat
    /// View Properties
    @GestureState private var isDragging: Bool = false
    @State private var isScrolledUp: Bool?
    @State private var shiftOffset: CGFloat = 0
    @State private var scrollOffset: CGFloat = 0
    @State private var isLargerContent: Bool = false
    @State private var scrollPhase: ScrollPhase = .idle

    func body(content: Content) -> some View {
        content
            /// If you add this modifier, then no need for hide tab bar modifier to be added!
            .toolbarVisibility(.hidden, for: .tabBar)
            /// Adjusting Tab Bar Height!
            .safeAreaPadding(.bottom, 50)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(.rect)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .scrollView)
                    .updating($isDragging) { _, out, _ in
                        out = true
                    }
                    .onEnded { value in
                        guard scrollPhase != .idle else { return }
                        /// Softer velocity → less snappy settle.
                        let velocity = -value.velocity.height / 8
                        let resultOffset = scrollOffset + velocity
                        let rawProgress = (resultOffset - shiftOffset) / distance
                        let clampedProgress = max(0, min(1, rawProgress))

                        withAnimation(settleAnimation) {
                            self.progress = resultOffset > (distance / 2) && isLargerContent
                                ? (clampedProgress > 0.5 ? 1 : 0)
                                : 0
                        }

                        isScrolledUp = nil
                        /// Adjusting Shift Offset accordingly!
                        shiftOffset = scrollOffset - (progress * distance)
                    }
            )
            .onScrollPhaseChange { _, newPhase in
                scrollPhase = newPhase
            }
            .onScrollGeometryChange(for: CGFloat.self, of: {
                $0.contentSize.height - $0.containerSize.height
            }, action: { _, newValue in
                isLargerContent = newValue > 0
            })
            .onScrollGeometryChange(for: CGFloat.self) {
                $0.contentOffset.y + $0.contentInsets.top
            } action: { oldValue, newValue in
                guard isDragging else { return }
                scrollOffset = newValue
                let isScrolledUp = oldValue < newValue

                if self.isScrolledUp != isScrolledUp {
                    self.isScrolledUp = isScrolledUp
                    /// Store Shift Offset
                    self.shiftOffset = newValue - (progress * distance)
                }

                let rawProgress = (newValue - shiftOffset) / distance
                let clampedProgress = max(0, min(1, rawProgress))

                // Finger-follow while dragging (no spring) — settle animates on end.
                self.progress = clampedProgress
            }
    }

    /// Slightly longer distance = gentler collapse curve.
    private var distance: CGFloat {
        130
    }

    private var settleAnimation: Animation {
        .smooth(duration: 0.45)
    }
}
