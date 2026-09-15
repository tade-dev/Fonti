import Foundation

/// The single place that turns Fonti's own types into widget snapshot entries.
///
/// It exists mainly to answer one question the call sites can't: whether a
/// family is an *imported* font, and if so which file in the App Group holds
/// it. The widget needs that filename to register the face before rendering —
/// without it, an imported font silently renders as the system font.
@MainActor
enum WidgetPublisher {
    /// familyName → filename in `SharedFontContainer`. Populated at launch,
    /// which is also the only time the set of imports can change without the
    /// app being running.
    private static var importedFiles: [String: String] = [:]

    static func indexImports(_ fonts: [ImportedFont]) {
        importedFiles = Dictionary(
            fonts.map { ($0.familyName, $0.filename) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    static func noteImport(_ font: ImportedFont) {
        importedFiles[font.familyName] = font.filename
    }

    static func forgetImport(_ font: ImportedFont) {
        importedFiles.removeValue(forKey: font.familyName)
    }

    /// Push a font to the front of the widget's rotation.
    static func publish(family: FontFamily, sampleText: String?) {
        let fileName = importedFiles[family.id]
        WidgetSnapshotStore.publish(
            familyName: family.id,
            displayName: family.displayName,
            sampleText: sampleText,
            isImported: fileName != nil,
            fileName: fileName
        )
    }

    /// Replace the snapshot with the user's most recent saved fonts.
    static func syncFromSaved(_ saved: [SavedFont], sampleText: String?) {
        let trimmed = sampleText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let sample = trimmed.isEmpty ? "Aa" : trimmed

        let entries = saved.prefix(WidgetSnapshotStore.maxEntries).map { font in
            let fileName = importedFiles[font.familyName]
            return WidgetFontEntry(
                familyName: font.familyName,
                displayName: font.familyName,
                sampleText: sample,
                isImported: fileName != nil,
                fileName: fileName
            )
        }
        WidgetSnapshotStore.replaceAll(with: Array(entries))
    }
}
