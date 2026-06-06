import SwiftUI
import UIKit

extension UIApplication {
    /// Resigns first responder on the key window — dismisses any active keyboard.
    func endEditing() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

extension View {
    /// Adds a transparent tap layer behind the content. Tapping anywhere the
    /// foreground doesn't intercept (gaps between cards, empty Form rows, etc.)
    /// dismisses the keyboard. Tappable child views (buttons, NavigationLinks,
    /// card onTapGesture handlers) still win their taps via the SwiftUI gesture
    /// hierarchy.
    func dismissKeyboardOnBackgroundTap() -> some View {
        background {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    UIApplication.shared.endEditing()
                }
        }
    }
}
