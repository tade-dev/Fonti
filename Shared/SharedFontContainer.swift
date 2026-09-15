import Foundation
import CoreText

/// The App Group folder that holds every imported font file.
///
/// Imported fonts used to live in the app's own Application Support directory,
/// which the widget extension — a separate process, separate container — could
/// never read. That made the widget silently substitute a system face for an
/// imported one: the worst possible failure in a typography app. Anything the
/// widget has to render lives here instead, reachable by both processes.
enum SharedFontContainer {
    static let appGroupID = WidgetSnapshotStore.appGroupID

    /// `<AppGroup>/Fonts/`. Nil only when the App Group entitlement is missing.
    static var fontsDirectory: URL? {
        guard let container = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
        else { return nil }

        let directory = container.appendingPathComponent("Fonts", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    static func url(for fileName: String) -> URL? {
        guard !fileName.isEmpty else { return nil }
        return fontsDirectory?.appendingPathComponent(fileName)
    }

    // Core Text registration is per-process, and re-registering the same URL
    // logs noisy errors, so remember what this process has already done.
    private static var registeredFileNames: Set<String> = []

    /// Register one font file with Core Text. Cheap and safe to call on every
    /// widget render — the first call does the work, the rest hit the cache.
    @discardableResult
    static func register(fileName: String) -> Bool {
        guard !fileName.isEmpty else { return false }
        if registeredFileNames.contains(fileName) { return true }

        guard
            let url = url(for: fileName),
            FileManager.default.fileExists(atPath: url.path)
        else { return false }

        guard CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil) else { return false }
        registeredFileNames.insert(fileName)
        return true
    }

    /// Register every font file in the shared folder.
    static func registerAll() {
        guard
            let directory = fontsDirectory,
            let names = try? FileManager.default.contentsOfDirectory(atPath: directory.path)
        else { return }

        for name in names where !name.hasPrefix(".") {
            register(fileName: name)
        }
    }

    static func unregister(fileName: String) {
        guard let url = url(for: fileName) else { return }
        CTFontManagerUnregisterFontsForURL(url as CFURL, .process, nil)
        registeredFileNames.remove(fileName)
    }

    /// True when the named file exists in the shared folder *and* Core Text
    /// accepted it — i.e. `Font.custom` will resolve to the real typeface.
    static func canRender(fileName: String?) -> Bool {
        guard let fileName else { return false }
        return register(fileName: fileName)
    }
}
