import SwiftUI

/// App tabs — mirrors Kavsoft's `AppTab` pattern.
enum FontiTab: String, CaseIterable {
    case browse
    case saved
    case settings

    /// Shown beside the symbol in the tab bar. Required rather than optional:
    /// on iPhone Duo the bar moves to a vertical strip and overflows into the
    /// system menu, which labels items by title.
    var title: String {
        switch self {
        case .browse: return "Browse"
        case .saved: return "Saved"
        case .settings: return "Settings"
        }
    }

    var symbolImage: String {
        switch self {
        case .browse: return "textformat"
        case .saved: return "heart"
        case .settings: return "gear"
        }
    }
}
