import SwiftUI
import UIKit

/// Background styles for the Full Screen Preview specimen card.
enum PreviewBackground: String, CaseIterable, Identifiable, Hashable {
    case ink
    case cream
    case amberWash
    case mesh
    case liquidGlass
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ink: return "Ink"
        case .cream: return "Cream"
        case .amberWash: return "Amber"
        case .mesh: return "Mesh"
        case .liquidGlass: return "Glass"
        case .custom: return "Photo"
        }
    }

    /// Glyph / label color that stays readable on this board.
    var glyphColor: Color {
        switch self {
        case .cream: return .fontiInk
        default: return .fontiCream
        }
    }

    var secondaryGlyphColor: Color {
        glyphColor.opacity(0.55)
    }

    /// Presets shown as chips (custom is always last).
    static var chipOrder: [PreviewBackground] {
        [.ink, .cream, .amberWash, .mesh, .liquidGlass, .custom]
    }
}

// MARK: - Fill

extension PreviewBackground {
    /// Visual fill for the live specimen card. Liquid Glass is applied by the
    /// card chrome itself via `.glassEffect` — this returns a clear base.
    @ViewBuilder
    func fill(customImage: UIImage?) -> some View {
        switch self {
        case .ink:
            Color.fontiInk
        case .cream:
            Color.fontiCream
        case .amberWash:
            LinearGradient(
                colors: [
                    Color.fontiInk,
                    Color.fontiAmber.opacity(0.55),
                    Color(red: 0.18, green: 0.08, blue: 0.02),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .mesh:
            MeshGradient(
                width: 3,
                height: 3,
                points: [
                    [0, 0], [0.5, 0], [1, 0],
                    [0, 0.5], [0.5, 0.5], [1, 0.5],
                    [0, 1], [0.5, 1], [1, 1],
                ],
                colors: [
                    .fontiInk, Color(red: 0.2, green: 0.12, blue: 0.08), .fontiAmber.opacity(0.7),
                    Color(red: 0.1, green: 0.08, blue: 0.14), .fontiCream.opacity(0.35), .fontiInk,
                    .fontiAmber.opacity(0.45), .fontiInk, Color(red: 0.12, green: 0.1, blue: 0.08),
                ]
            )
        case .liquidGlass:
            Color.clear
        case .custom:
            // Color lays out to the offered size; photo is an overlay so
            // `scaledToFill` can't inflate the card beyond its frame.
            Color.fontiInk
                .overlay {
                    if let customImage {
                        Image(uiImage: customImage)
                            .resizable()
                            .scaledToFill()
                    }
                }
                .overlay(Color.black.opacity(customImage == nil ? 0 : 0.38))
                .clipped()
        }
    }

    /// Flattened fill for `ImageRenderer` share export (no live glass).
    @ViewBuilder
    func exportFill(customImage: UIImage?) -> some View {
        switch self {
        case .liquidGlass:
            // Approximate liquid glass for the PNG — real glass won't rasterize.
            ZStack {
                Color.fontiInk
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.14),
                        Color.white.opacity(0.04),
                        Color.white.opacity(0.10),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        case .custom:
            Color.fontiInk
                .overlay {
                    if let customImage {
                        Image(uiImage: customImage)
                            .resizable()
                            .scaledToFill()
                    }
                }
                .overlay(Color.black.opacity(customImage == nil ? 0 : 0.38))
                .clipped()
        default:
            fill(customImage: customImage)
        }
    }
}
