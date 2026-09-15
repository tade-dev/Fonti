import Foundation
import CoreText
import SwiftData

enum CustomFontError: LocalizedError {
    case invalidFont
    case duplicateFamily(String)
    case fileSystemError(String)

    var errorDescription: String? {
        switch self {
        case .invalidFont:
            return "That doesn't look like a valid .ttf or .otf font."
        case .duplicateFamily(let name):
            return "\(name) is already in your library."
        case .fileSystemError(let message):
            return message
        }
    }
}

@MainActor
enum CustomFontManager {
    /// Where every imported font file lives — the App Group container, so the
    /// widget extension can register and render imported faces too.
    ///
    /// Falls back to the app's own Application Support folder if the App Group
    /// is somehow unavailable; imports keep working, the widget just can't show
    /// them.
    static var fontsDirectory: URL {
        SharedFontContainer.fontsDirectory ?? legacyFontsDirectory
    }

    /// `<AppSupport>/Fonts/` — where imports lived before the move to the App
    /// Group. Still read on launch so existing libraries migrate.
    static let legacyFontsDirectory: URL = {
        let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
        let dir = appSupport.appendingPathComponent("Fonts", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    /// Move any pre-App-Group imports into the shared container.
    ///
    /// Idempotent and cheap once drained — the legacy folder ends up empty and
    /// `contentsOfDirectory` returns nothing on every later launch.
    static func migrateLegacyFontsIfNeeded() {
        guard let shared = SharedFontContainer.fontsDirectory else { return }
        let manager = FileManager.default
        guard
            let names = try? manager.contentsOfDirectory(atPath: legacyFontsDirectory.path),
            !names.isEmpty
        else { return }

        for name in names where !name.hasPrefix(".") {
            let source = legacyFontsDirectory.appendingPathComponent(name)
            let destination = shared.appendingPathComponent(name)

            if manager.fileExists(atPath: destination.path) {
                try? manager.removeItem(at: source)
                continue
            }
            // Core Text may hold the old URL from a previous launch in this
            // process; unregister before moving so the file isn't pinned.
            CTFontManagerUnregisterFontsForURL(source as CFURL, .process, nil)
            try? manager.moveItem(at: source, to: destination)
        }
    }

    /// Copy the file out of the picker URL into the sandbox, register it with
    /// Core Text, read its family name, and persist an `ImportedFont` record.
    /// Throws `CustomFontError` on any failure (rolling back any side-effects).
    static func `import`(from sourceURL: URL, into context: ModelContext) throws -> ImportedFont {
        let needsScope = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if needsScope { sourceURL.stopAccessingSecurityScopedResource() }
        }

        // Copy file into sandbox with a UUID-prefixed filename
        let ext = sourceURL.pathExtension.isEmpty ? "ttf" : sourceURL.pathExtension
        let filename = "\(UUID().uuidString).\(ext)"
        let destination = fontsDirectory.appendingPathComponent(filename)

        do {
            try FileManager.default.copyItem(at: sourceURL, to: destination)
        } catch {
            throw CustomFontError.fileSystemError(error.localizedDescription)
        }

        // Register
        var errorRef: Unmanaged<CFError>?
        guard CTFontManagerRegisterFontsForURL(destination as CFURL, .process, &errorRef) else {
            try? FileManager.default.removeItem(at: destination)
            throw CustomFontError.invalidFont
        }

        // Extract family name
        guard
            let rawDescriptors = CTFontManagerCreateFontDescriptorsFromURL(destination as CFURL),
            let descriptors = rawDescriptors as? [CTFontDescriptor],
            let descriptor = descriptors.first,
            let familyName = CTFontDescriptorCopyAttribute(descriptor, kCTFontFamilyNameAttribute) as? String,
            !familyName.isEmpty
        else {
            CTFontManagerUnregisterFontsForURL(destination as CFURL, .process, nil)
            try? FileManager.default.removeItem(at: destination)
            throw CustomFontError.invalidFont
        }

        // Duplicate check
        let descriptorQuery = FetchDescriptor<ImportedFont>(
            predicate: #Predicate { $0.familyName == familyName }
        )
        if let existing = try? context.fetch(descriptorQuery), !existing.isEmpty {
            CTFontManagerUnregisterFontsForURL(destination as CFURL, .process, nil)
            try? FileManager.default.removeItem(at: destination)
            throw CustomFontError.duplicateFamily(familyName)
        }

        // Persist
        let record = ImportedFont(familyName: familyName, filename: filename)
        context.insert(record)
        try? context.save()
        return record
    }

    /// Re-register every persisted import with Core Text. Call once at app
    /// launch — registration doesn't survive across launches.
    static func registerAll(_ fonts: [ImportedFont]) {
        migrateLegacyFontsIfNeeded()

        for font in fonts {
            let url = fontsDirectory.appendingPathComponent(font.filename)
            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
        FontAvailability.refresh()
    }

    /// Unregister, delete the file, and remove the record.
    static func remove(_ font: ImportedFont, from context: ModelContext) {
        // Check both locations — a library that hasn't migrated yet still has
        // its files in the legacy folder.
        for directory in [fontsDirectory, legacyFontsDirectory] {
            let url = directory.appendingPathComponent(font.filename)
            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            CTFontManagerUnregisterFontsForURL(url as CFURL, .process, nil)
            try? FileManager.default.removeItem(at: url)
        }
        FontAvailability.refresh()
        context.delete(font)
        try? context.save()
    }
}
