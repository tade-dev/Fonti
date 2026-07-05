import UIKit

enum InSpaceMaterial: CaseIterable, Equatable {
    case cream
    case glass
    case amber

    var displayName: String {
        switch self {
        case .cream: return "cream"
        case .glass: return "glass"
        case .amber: return "amber"
        }
    }

    func next() -> InSpaceMaterial {
        let all = InSpaceMaterial.allCases
        let idx = all.firstIndex(of: self) ?? 0
        return all[(idx + 1) % all.count]
    }

    var materialProperties: (baseColor: UIColor, roughness: Float, metallic: Float, isTranslucent: Bool) {
        switch self {
        case .cream:
            return (UIColor(red: 0.961, green: 0.941, blue: 0.910, alpha: 1.0), 0.85, 0.0, false)
        case .glass:
            return (UIColor(white: 1.0, alpha: 0.4), 0.05, 0.0, true)
        case .amber:
            return (UIColor(red: 0.910, green: 0.627, blue: 0.251, alpha: 1.0), 0.25, 1.0, false)
        }
    }
}
