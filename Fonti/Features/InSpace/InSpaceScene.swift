// Fonti/Features/InSpace/InSpaceScene.swift
//
// UIViewRepresentable wrapping ARView for world-tracked 3-D text with
// pinch/pan/rotate gesture handling.

import SwiftUI
import RealityKit
import ARKit

struct InSpaceScene: UIViewRepresentable {
    let text: String
    let familyName: String
    let bold: Bool
    let italic: Bool
    @Binding var material: InSpaceMaterial
    @Binding var arView: ARView?
    @Binding var textEntity: ModelEntity?

    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero, cameraMode: .ar, automaticallyConfigureSession: false)
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = []
        config.environmentTexturing = .automatic
        view.session.run(config)
        view.environment.lighting.intensityExponent = 1.0

        let anchor = AnchorEntity(world: SIMD3<Float>(0, 0, -0.4))
        view.scene.anchors.append(anchor)

        do {
            let entity = try ARTextMeshBuilder.build(
                text: text,
                familyName: familyName,
                bold: bold,
                italic: italic,
                extrusion: 0.02,
                material: material
            )
            entity.scale = SIMD3<Float>(repeating: 0.001)
            anchor.addChild(entity)

            var target = entity.transform
            target.scale = SIMD3<Float>(repeating: 0.15)
            entity.move(to: target, relativeTo: entity.parent, duration: 0.4, timingFunction: .easeOut)

            DispatchQueue.main.async {
                self.textEntity = entity
                self.arView = view
            }
        } catch {
            // Mesh failure — handled by parent view.
        }

        installGestures(on: view, context: context)
        return view
    }

    func updateUIView(_ view: ARView, context: Context) {
        guard let entity = textEntity else { return }
        entity.model?.materials = [makePBR(for: material)]
    }

    private func installGestures(on view: ARView, context: Context) {
        let pinch = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePinch(_:)))
        let pan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        let rotate = UIRotationGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleRotate(_:)))
        for g in [pinch as UIGestureRecognizer, pan, rotate] { view.addGestureRecognizer(g) }
        context.coordinator.parent = self
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    @MainActor
    final class Coordinator: NSObject {
        var parent: InSpaceScene?
        private var startingScale: Float = 0.15
        private var startingRotation: Float = 0
        private var startingPosition: SIMD3<Float> = SIMD3(0, 0, -0.4)

        @objc func handlePinch(_ g: UIPinchGestureRecognizer) {
            guard let entity = parent?.textEntity else { return }
            switch g.state {
            case .began:
                startingScale = entity.scale.x
            case .changed:
                let raw = startingScale * Float(g.scale)
                let old = entity.scale.x
                let clamped = InSpaceGestures.clampScale(raw)
                entity.scale = SIMD3<Float>(repeating: clamped)
                if InSpaceGestures.hapticTick(oldScale: old, newScale: clamped) {
                    UISelectionFeedbackGenerator().selectionChanged()
                }
            default: break
            }
        }

        @objc func handlePan(_ g: UIPanGestureRecognizer) {
            guard let entity = parent?.textEntity, let view = g.view else { return }
            switch g.state {
            case .began:
                startingPosition = entity.position(relativeTo: nil)
            case .changed:
                let t = g.translation(in: view)
                let dx = Float(t.x) / 800
                let dy = Float(-t.y) / 800
                entity.setPosition(startingPosition + SIMD3<Float>(dx, dy, 0), relativeTo: nil)
            default: break
            }
        }

        private var currentSignedRotation: Float = 0

        @objc func handleRotate(_ g: UIRotationGestureRecognizer) {
            guard let entity = parent?.textEntity else { return }
            switch g.state {
            case .began:
                startingRotation = currentSignedRotation
            case .changed:
                let raw = startingRotation - Float(g.rotation)
                currentSignedRotation = raw
                entity.setOrientation(simd_quatf(angle: raw, axis: SIMD3<Float>(0, 1, 0)), relativeTo: nil)
            case .ended:
                let snapped = InSpaceGestures.snapRotation(currentSignedRotation)
                currentSignedRotation = snapped
                entity.setOrientation(simd_quatf(angle: snapped, axis: SIMD3<Float>(0, 1, 0)), relativeTo: nil)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            default: break
            }
        }
    }

    private func makePBR(for preset: InSpaceMaterial) -> RealityKit.Material {
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
}

private extension simd_quatf {
    // Extracts the rotation angle (in radians) around the principal axis.
    // 2 * acos(real) gives the total angle for unit quaternions.
    var quaternionAngle: Float { 2 * acos(max(-1, min(1, self.real))) }
}
