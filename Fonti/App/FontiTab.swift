import SwiftUI

/// App tabs — mirrors Kavsoft's `AppTab` pattern.
enum FontiTab: String, CaseIterable {
    case browse
    case saved
    case settings

    var symbolImage: String {
        switch self {
        case .browse: return "textformat"
        case .saved: return "heart"
        case .settings: return "gear"
        }
    }
}
