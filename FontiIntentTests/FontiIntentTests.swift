import XCTest
import AppIntentsTesting

/// Runs Fonti's App Intents the way Siri does — out-of-process against the
/// installed app — so the whole Apple Intelligence surface is verifiable on a
/// simulator instead of needing a device and a spoken phrase.
///
/// This is a UI testing bundle rather than a unit test target on purpose.
/// `AppIntentsTesting` talks to the installed app over XPC, and a hosted unit
/// test links the app and runs inside it, which makes every call fail with
/// "transport cancelled". XCTest rather than Swift Testing for the same
/// reason: a UI testing bundle can't import Swift Testing at all.
///
/// Most of this needs no fixtures. Fonti's entities are backed by the system
/// font catalogue, identical on every run of a given simulator, so "does
/// Helvetica resolve" and "is Arial similar to Helvetica" are directly
/// assertable. Only saved-state would need seeding, and nothing here uses it.
final class FontiIntentTests: XCTestCase {
    let definitions = IntentDefinitions(bundleIdentifier: "com.tade.Fonti")

    private var fontEntity: AppEntityDefinition { definitions.entities["FontEntity"] }

    private func names(_ entities: [AnyAppEntity]) throws -> [String] {
        try entities.map { try $0.name.as(String.self) }
    }

    // MARK: - Entity resolution
    //
    // The part compiling can't prove: an entity that builds fine can still
    // fail to resolve a spoken name.

    func testResolvesSpokenName() async throws {
        let results = try await fontEntity.entities(matching: "Helvetica")
        XCTAssertFalse(results.isEmpty)
        XCTAssertTrue(try names(results).contains("Helvetica"))
    }

    func testResolvesPartialName() async throws {
        let found = try names(try await fontEntity.entities(matching: "helv"))
        XCTAssertTrue(found.contains("Helvetica"))
        XCTAssertTrue(found.contains("Helvetica Neue"))
    }

    func testResolvesNothingForNonsense() async throws {
        let results = try await fontEntity.entities(matching: "zzzznotafont")
        XCTAssertTrue(results.isEmpty)
    }

    /// Identifiers are a persisted contract — a saved shortcut replays one.
    func testResolvesByIdentifier() async throws {
        let results = try await fontEntity.entities(identifiers: ["Georgia"])
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(try results[0].name.as(String.self), "Georgia")
    }

    func testSuggestsEntities() async throws {
        let suggested = try await fontEntity.suggestedEntities()
        XCTAssertFalse(suggested.isEmpty, "An empty picker makes the entity feel unpickable")
    }

    // MARK: - Category search
    //
    // Regression cover for a real bug: matching the category by substring made
    // "sansserif".contains("serif") true, so asking for serif faces returned
    // Arial, Avenir and Helvetica.

    func testSerifSearchExcludesSansSerif() async throws {
        let found = try names(try await fontEntity.entities(matching: "serif"))
        XCTAssertFalse(found.isEmpty)

        for offender in ["Helvetica", "Helvetica Neue", "Arial", "Avenir", "Futura"] {
            XCTAssertFalse(
                found.contains(offender),
                "\(offender) is sans-serif and must not match a request for 'serif'"
            )
        }
    }

    func testMonospaceSearchReturnsMonospace() async throws {
        let found = try names(try await fontEntity.entities(matching: "monospace"))
        XCTAssertTrue(found.contains("Menlo"))
        XCTAssertFalse(found.contains("Helvetica"))
    }

    // MARK: - Intent execution

    func testOpensFont() async throws {
        let font = fontEntity.makeReference(identifier: "Georgia")
        try await definitions.intents["OpenFontIntent"].makeIntent(target: font).run()
    }

    func testOpeningMissingFontThrows() async throws {
        let font = fontEntity.makeReference(identifier: "Definitely Not A Real Typeface")
        do {
            try await definitions.intents["OpenFontIntent"].makeIntent(target: font).run()
            XCTFail("Expected OpenFontIntent to reject a font that isn't installed")
        } catch {
            // Expected: FontiIntentError.fontUnavailable
        }
    }

    func testFindsFonts() async throws {
        let result = try await definitions.intents["FindFontsIntent"]
            .makeIntent(criteria: "Helvetica")
            .run()

        let fonts: [AnyAppEntity] = try result.value
        XCTAssertTrue(try names(fonts).contains("Helvetica"))
    }

    // MARK: - Typographic relationships
    //
    // Similarity is measured rather than tagged, so these assert the
    // measurements still agree with what a designer would say.

    func testSimilarToHelveticaIncludesArial() async throws {
        let result = try await definitions.intents["FindSimilarFontsIntent"]
            .makeIntent(font: fontEntity.makeReference(identifier: "Helvetica"))
            .run()

        let fonts: [AnyAppEntity] = try result.value
        XCTAssertTrue(try names(fonts).contains("Arial"))
    }

    func testSimilarToFuturaIsGeometricSans() async throws {
        let result = try await definitions.intents["FindSimilarFontsIntent"]
            .makeIntent(font: fontEntity.makeReference(identifier: "Futura"))
            .run()

        let fonts: [AnyAppEntity] = try result.value
        let found = try names(fonts)

        XCTAssertTrue(found.contains("Avenir"), "Avenir is the canonical geometric match for Futura")

        // Regression cover: PingFang and Hiragino classify as sans-serif with
        // plausible Latin proportions, and once crowded Avenir out entirely.
        for name in found where name.hasPrefix("PingFang") || name.hasPrefix("Hiragino") {
            XCTFail("\(name) is designed for another writing system and shouldn't rank as similar")
        }
    }

    func testScriptSimilarityStaysInCategory() async throws {
        let result = try await definitions.intents["FindSimilarFontsIntent"]
            .makeIntent(font: fontEntity.makeReference(identifier: "Snell Roundhand"))
            .run()

        let fonts: [AnyAppEntity] = try result.value
        // `category` is an AppEnum, so it comes back as AnyAppEnum — reading it
        // as a String fails with castingFailed(AppEnumSpecification, String).
        let categories: [String] = try fonts.map { font in
            let category: AnyAppEnum = try font.category
            return category.rawValue
        }

        XCTAssertFalse(categories.isEmpty)
        XCTAssertTrue(
            categories.allSatisfy { $0 == "script" },
            "A script face must only ever be similar to other script faces, got \(categories)"
        )
    }

    func testFindsPairings() async throws {
        let result = try await definitions.intents["FindFontPairingsIntent"]
            .makeIntent(font: fontEntity.makeReference(identifier: "Georgia"))
            .run()

        let fonts: [AnyAppEntity] = try result.value
        XCTAssertFalse(fonts.isEmpty)
    }

    func testComparingAFontWithItselfThrows() async throws {
        let font = fontEntity.makeReference(identifier: "Georgia")
        do {
            try await definitions.intents["CompareFontsIntent"]
                .makeIntent(firstFont: font, secondFont: font)
                .run()
            XCTFail("Expected CompareFontsIntent to reject comparing a font with itself")
        } catch {
            // Expected: FontiIntentError.sameFontTwice
        }
    }

    func testComparesTwoFonts() async throws {
        try await definitions.intents["CompareFontsIntent"]
            .makeIntent(
                firstFont: fontEntity.makeReference(identifier: "Georgia"),
                secondFont: fontEntity.makeReference(identifier: "Helvetica Neue")
            )
            .run()
    }
}
