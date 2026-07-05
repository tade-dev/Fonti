// FontiTests/ARTextMeshBuilderTests.swift
import XCTest
import RealityKit
@testable import Fonti

@MainActor
final class ARTextMeshBuilderTests: XCTestCase {
    func test_build_returnsEntityWithNonZeroBounds() throws {
        let entity = try ARTextMeshBuilder.build(
            text: "Aa",
            familyName: "Helvetica Neue",
            bold: false,
            italic: false,
            extrusion: 0.02,
            material: .cream
        )
        let bounds = entity.visualBounds(relativeTo: nil)
        XCTAssertGreaterThan(bounds.extents.x, 0)
        XCTAssertGreaterThan(bounds.extents.y, 0)
        XCTAssertGreaterThan(bounds.extents.z, 0)
    }

    func test_build_emptyText_throws() {
        XCTAssertThrowsError(
            try ARTextMeshBuilder.build(
                text: "",
                familyName: "Helvetica Neue",
                bold: false,
                italic: false,
                extrusion: 0.02,
                material: .cream
            )
        ) { error in
            XCTAssertEqual(error as? ARTextMeshError, .emptyText)
        }
    }

    func test_build_unknownFont_fallsBackWithoutThrowing() throws {
        let entity = try ARTextMeshBuilder.build(
            text: "Aa",
            familyName: "ThisFontDoesNotExist-12345",
            bold: false,
            italic: false,
            extrusion: 0.02,
            material: .cream
        )
        XCTAssertGreaterThan(entity.visualBounds(relativeTo: nil).extents.x, 0)
    }

    func test_build_boldTraitAppliedWhenSupported() throws {
        let plain = try ARTextMeshBuilder.build(
            text: "MMMM",
            familyName: "Helvetica Neue",
            bold: false,
            italic: false,
            extrusion: 0.02,
            material: .cream
        )
        let bold = try ARTextMeshBuilder.build(
            text: "MMMM",
            familyName: "Helvetica Neue",
            bold: true,
            italic: false,
            extrusion: 0.02,
            material: .cream
        )
        XCTAssertGreaterThan(
            bold.visualBounds(relativeTo: nil).extents.x,
            plain.visualBounds(relativeTo: nil).extents.x * 1.02
        )
    }
}
