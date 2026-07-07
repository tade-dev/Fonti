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

        // MeshResource.generateText treats the font's pointSize as world
        // units (meters). A 1.0 base makes glyphs ≈1 m tall unscaled;
        // combined with the 0.15 initial scale in InSpaceScene that lands
        // at ≈15 cm tall, matching the spec's "readable at 40 cm distance".
        let font = resolveFont(familyName: familyName, bold: bold, italic: italic, size: 1.0)

        let mesh = MeshResource.generateText(
            text,
            extrusionDepth: extrusion,
            font: font,
            containerFrame: .zero,
            alignment: .center,
            lineBreakMode: .byWordWrapping
        )

        let mat = makeMaterial(from: material)
        let textEntity = ModelEntity(mesh: mesh, materials: [mat])
        let bounds = textEntity.visualBounds(relativeTo: nil)
        textEntity.position = -bounds.center

        // Container's local origin sits at the text's visual center. Callers
        // manipulate the container's transform (position/scale/rotation)
        // without disturbing the centered offset applied to the child.
        let container = ModelEntity()
        container.addChild(textEntity)
        return container
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
        // SimpleMaterial responds to DirectionalLight and doesn't require the
        // environment-texturing pass that PhysicallyBasedMaterial depends on,
        // which is unreliable in the first seconds of an AR session.
        let props = preset.materialProperties
        var mat = SimpleMaterial(
            color: props.baseColor,
            roughness: .init(floatLiteral: props.roughness),
            isMetallic: props.metallic > 0.5
        )
        if props.isTranslucent {
            mat.color = .init(tint: props.baseColor.withAlphaComponent(0.5), texture: nil)
        }
        return mat
    }

}
