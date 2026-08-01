import SwiftUI

/// Specimen board layouts — more than a single centered line.
enum SpecimenTemplate: String, CaseIterable, Identifiable, Hashable {
    case wordmark
    case headline
    case body
    case poster

    var id: String { rawValue }

    var title: String {
        switch self {
        case .wordmark: return "Wordmark"
        case .headline: return "Headline"
        case .body: return "Body"
        case .poster: return "Poster"
        }
    }

    var symbolName: String {
        switch self {
        case .wordmark: return "textformat"
        case .headline: return "text.aligncenter"
        case .body: return "text.alignleft"
        case .poster: return "rectangle.portrait"
        }
    }

    /// Multiplier on the preview size slider.
    var sizeMultiplier: CGFloat {
        switch self {
        case .wordmark: return 1.0
        case .headline: return 0.85
        case .body: return 0.42
        case .poster: return 0.92
        }
    }

    var lineLimit: Int {
        switch self {
        case .wordmark: return 2
        case .headline: return 3
        case .body: return 8
        case .poster: return 3
        }
    }

    var multilineAlignment: TextAlignment {
        switch self {
        case .body: return .leading
        default: return .center
        }
    }

    var textAlignment: Alignment {
        switch self {
        case .body: return .leading
        default: return .center
        }
    }

    /// Suggested copy when the field is empty / still a seed — optional UX helper.
    var suggestedCopy: String {
        switch self {
        case .wordmark: return "Find your type."
        case .headline: return "Type that stops the scroll."
        case .body: return "Typography is the craft of endowing human language with a durable visual form. Choose a face that carries the voice."
        case .poster: return "NEW TYPE"
        }
    }
}
