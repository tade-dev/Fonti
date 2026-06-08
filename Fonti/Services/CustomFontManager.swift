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
    /// `<AppSupport>/Fonts/` — where every imported font file lives.
    static let fontsDirectory: URL = {
        let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
        let dir = appSupport.appendingPathComponent("Fonts", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

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
        for font in fonts {
            let url = fontsDirectory.appendingPathComponent(font.filename)
            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }

    /// Unregister, delete the file, and remove the record.
    static func remove(_ font: ImportedFont, from context: ModelContext) {
        let url = fontsDirectory.appendingPathComponent(font.filename)
        CTFontManagerUnregisterFontsForURL(url as CFURL, .process, nil)
        try? FileManager.default.removeItem(at: url)
        context.delete(font)
        try? context.save()
    }
}
