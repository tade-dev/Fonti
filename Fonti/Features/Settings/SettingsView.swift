import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var saved: [SavedFont]
    @Query(sort: \ImportedFont.familyName) private var imports: [ImportedFont]

    // Appearance is disabled — Fonti is dark-only for v1. See RootView for the matching
    // .preferredColorScheme(.dark) hardcode. Re-enable here + in RootView + uncomment
    // appearanceSection below to bring back theme switching.
    // @AppStorage("fonti.appearance")         private var appearance: AppAppearance = .dark
    @AppStorage("fonti.defaultSampleText")  private var defaultSampleText: String = ""
    @AppStorage("fonti.defaultPreviewSize") private var defaultPreviewSize: Double = 48
    @AppStorage("fonti.hapticsEnabled")     private var hapticsEnabled: Bool = true

    @State private var confirmClear = false
    @State private var showingImporter = false
    @State private var importError: String?

    private let githubURL = URL(string: "https://github.com/tade-dev/Fonti")!

    var body: some View {
        Form {
            // appearanceSection — disabled; Fonti is dark-only for v1.
            myFontsSection
            defaultsSection
            feedbackSection
            librarySection
            aboutSection
        }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.font, UTType("public.truetype-font") ?? .font, UTType("public.opentype-font") ?? .font],
            allowsMultipleSelection: true
        ) { result in
            handleImport(result)
        }
        .alert("Import failed", isPresented: Binding(
            get: { importError != nil },
            set: { if !$0 { importError = nil } }
        ), presenting: importError) { _ in
            Button("OK") { importError = nil }
        } message: { message in
            Text(message)
        }
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.immediately)
        .background(Color.fontiInk.ignoresSafeArea())
        .dismissKeyboardOnBackgroundTap()
        .foregroundStyle(Color.fontiCream)
        .tint(.fontiAmber)
        .navigationTitle("Settings")
        .toolbarTitleDisplayMode(.inlineLarge)
        .alert("Clear all saved fonts?", isPresented: $confirmClear) {
            Button("Clear", role: .destructive) { clearSaved() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This can't be undone.")
        }
    }

    // Disabled — Fonti is dark-only for v1. Restore by uncommenting the AppStorage
    // binding above and adding `appearanceSection` back to the Form.
    /*
    private var appearanceSection: some View {
        Section("Appearance") {
            Picker("Theme", selection: $appearance) {
                ForEach(AppAppearance.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
        }
    }
    */

    private var myFontsSection: some View {
        Section {
            Button {
                showingImporter = true
            } label: {
                Label("Import Fonts", systemImage: "plus.square.on.square")
            }

            ForEach(imports) { font in
                HStack(spacing: 10) {
                    Circle()
                        .fill(Color.fontiAmber)
                        .frame(width: 6, height: 6)
                    Text(font.familyName)
                        .font(.custom(font.familyName, size: 17))
                    Spacer()
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        remove(font)
                    } label: {
                        Label("Remove", systemImage: "trash")
                    }
                }
            }
        } header: {
            Text("My Fonts")
        } footer: {
            if imports.isEmpty {
                Text("Import .ttf or .otf files to preview them alongside the system fonts.")
            } else {
                Text("\(imports.count) imported \(imports.count == 1 ? "font" : "fonts"). Swipe to remove.")
            }
        }
    }

    private var defaultsSection: some View {
        Section {
            TextField(
                "e.g. Find your type.",
                text: $defaultSampleText
            )
            .textInputAutocapitalization(.sentences)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Preview size")
                    Spacer()
                    Text("\(Int(defaultPreviewSize)) pt")
                        .foregroundStyle(Color.fontiCream.opacity(0.6))
                        .monospacedDigit()
                }
                Slider(value: $defaultPreviewSize, in: 12...96, step: 1)
            }
            .padding(.vertical, 2)
        } header: {
            Text("Defaults")
        } footer: {
            Text("Used when the Browse input bar is empty, and as the starting size for previews.")
        }
    }

    private var feedbackSection: some View {
        Section("Feedback") {
            Toggle("Haptics", isOn: $hapticsEnabled)
        }
    }

    private var librarySection: some View {
        Section {
            Button(role: .destructive) {
                confirmClear = true
            } label: {
                Label("Clear Saved Fonts", systemImage: "trash")
            }
            .disabled(saved.isEmpty)
        } header: {
            Text("Library")
        } footer: {
            if !saved.isEmpty {
                Text("Removes all \(saved.count) saved \(saved.count == 1 ? "font" : "fonts").")
            }
        }
    }

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Version", value: appVersion)
            LabeledContent("Build", value: appBuild)
            Text("Designed in 2026 by Akintade Oluwaseun")
                .font(.footnote)
                .foregroundStyle(Color.fontiCream.opacity(0.6))
            Link(destination: githubURL) {
                HStack {
                    Text("View on GitHub")
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.footnote)
                }
            }
            .accessibilityLabel("View Fonti source on GitHub")
        }
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    private var appBuild: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
    }

    private func clearSaved() {
        withAnimation(.snappy(duration: 0.3)) {
            for entry in saved {
                modelContext.delete(entry)
            }
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            importError = error.localizedDescription
        case .success(let urls):
            var firstFailure: String?
            for url in urls {
                do {
                    _ = try CustomFontManager.import(from: url, into: modelContext)
                } catch let error as CustomFontError {
                    if firstFailure == nil { firstFailure = error.errorDescription }
                } catch {
                    if firstFailure == nil { firstFailure = error.localizedDescription }
                }
            }
            if let firstFailure { importError = firstFailure }
        }
    }

    private func remove(_ font: ImportedFont) {
        withAnimation(.snappy(duration: 0.25)) {
            CustomFontManager.remove(font, from: modelContext)
        }
    }
}

#Preview {
    NavigationStack { SettingsView() }
        .modelContainer(for: SavedFont.self, inMemory: true)
}
