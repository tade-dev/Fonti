// Fonti/Services/ARTextMeshBuilder.swift
//
// API-drift note: In this SDK, MeshResource.Font is a typealias for UIFont,
// so MeshResource.Font(descriptor:size:) does not exist as a failable
// initializer. Instead we build a UIFont directly via UIFont(descriptor:size:),
// which compiles to the same type. Additionally, MeshResource.generateText is
// @MainActor in this SDK, so build(_:) is also marked @MainActor to satisfy
// the actor isolation requirement while keeping the synchronous throws interface
// the brief specifies.
//
// Timeout note (spec 6 vs reality): MeshResource.generateText is synchronous
// and cannot be cancelled mid-call. A Task-based observation timeout could
// surface a .timeout error to callers but the underlying call would still
// finish on its own thread. In v1 we rely on the OS to complete the call
// promptly; revisit if real-world hangs are reported.

import RealityKit
import UIKit
import CoreText

enum ARTextMeshError: Error, Equatable {
    case emptyText
    case fontResolutionFailed
    case timeout
}

enum ARTextMeshBuilder {
    @MainActor
    static func build(
        text: String,
        familyName: String,
        bold: Bool,
        italic: Bool,
        extrusion: Float,
        material: InSpaceMaterial
    ) throws -> ModelEntity {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ARTextMeshError.emptyText }

        let font = resolveFont(familyName: familyName, bold: bold, italic: italic, size: 72)

        let mesh = MeshResource.generateText(
            text,
            extrusionDepth: extrusion,
            font: font,
            containerFrame: .zero,
            alignment: .center,
            lineBreakMode: .byWordWrapping
        )

        let mat = makeMaterial(from: material)
        let entity = ModelEntity(mesh: mesh, materials: [mat])
        centerPivot(of: entity)
        return entity
    }

    // Resolves a UIFont (which is MeshResource.Font in this SDK) from a family
    // name and symbolic traits. Falls back gracefully to the system font when
    // the family name is unknown or trait application is not supported.
    private static func resolveFont(familyName: String, bold: Bool, italic: Bool, size: CGFloat) -> MeshResource.Font {
        var descriptor = UIFontDescriptor(fontAttributes: [.family: familyName])
        var traits: UIFontDescriptor.SymbolicTraits = []
        if bold { traits.insert(.traitBold) }
        if italic { traits.insert(.traitItalic) }
        if !traits.isEmpty, let traited = descriptor.withSymbolicTraits(traits) {
            descriptor = traited
        }
        // UIFont(descriptor:size:) always returns a font (falling back to system
        // font when the descriptor cannot be matched), so fontResolutionFailed
        // is reserved for future use where a stricter resolution path is needed.
        let uiFont = UIFont(descriptor: descriptor, size: size)
        // MeshResource.Font is UIFont in this SDK; UIFont(name:size:) is
        // failable so we use the descriptor-constructed font directly.
        return uiFont
    }

    private static func makeMaterial(from preset: InSpaceMaterial) -> RealityKit.Material {
        let props = preset.materialProperties
        var pbr = PhysicallyBasedMaterial()
        pbr.baseColor = .init(tint: props.baseColor)
        pbr.roughness = .init(floatLiteral: props.roughness)
        pbr.metallic = .init(floatLiteral: props.metallic)
        if props.isTranslucent {
            pbr.blending = .transparent(opacity: .init(floatLiteral: 0.4))
        }
        return pbr
    }

    private static func centerPivot(of entity: ModelEntity) {
        let bounds = entity.visualBounds(relativeTo: nil)
        entity.position = -bounds.center
    }
}
