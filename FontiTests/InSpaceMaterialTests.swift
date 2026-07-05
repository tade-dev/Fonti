import XCTest
@testable import Fonti

final class InSpaceMaterialTests: XCTestCase {
    func test_next_cyclesCreamGlassAmberCream() {
        XCTAssertEqual(InSpaceMaterial.cream.next(), .glass)
        XCTAssertEqual(InSpaceMaterial.glass.next(), .amber)
        XCTAssertEqual(InSpaceMaterial.amber.next(), .cream)
    }

    func test_materialProperties_amberIsMetallic() {
        let props = InSpaceMaterial.amber.materialProperties
        XCTAssertEqual(props.metallic, 1.0)
        XCTAssertEqual(props.roughness, 0.25)
        XCTAssertFalse(props.isTranslucent)
    }

    func test_materialProperties_glassIsTranslucent() {
        let props = InSpaceMaterial.glass.materialProperties
        XCTAssertTrue(props.isTranslucent)
        XCTAssertEqual(props.roughness, 0.05)
    }

    func test_allCases_hasThreeMaterials() {
        XCTAssertEqual(InSpaceMaterial.allCases.count, 3)
    }
}
