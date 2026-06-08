import SwiftUI

/// Shared transition namespace for card-style sources (Browse cards, Saved
/// cards, Preview pair chips). Propagating it through the environment lets
/// descendants of a NavigationStack-pushed destination — like the pair
/// chips inside FullScreenPreviewView — register themselves as matched
/// transition sources for the same zoom transition the destination uses.
extension EnvironmentValues {
    @Entry var cardNamespace: Namespace.ID? = nil
}
