import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var saved: [SavedFont]

    // Appearance is disabled — Fonti is dark-only for v1. See RootView for the matching
    // .preferredColorScheme(.dark) hardcode. Re-enable here + in RootView + uncomment
    // appearanceSection below to bring back theme switching.
    // @AppStorage("fonti.appearance")         private var appearance: AppAppearance = .dark
    @AppStorage("fonti.defaultSampleText")  private var defaultSampleText: String = ""
    @AppStorage("fonti.defaultPreviewSize") private var defaultPreviewSize: Double = 48
    @AppStorage("fonti.hapticsEnabled")     private var hapticsEnabled: Bool = true

    @State private var confirmClear = false

    private let githubURL = URL(string: "https://github.com/tade-dev/Fonti")!

    var body: some View {
        Form {
            // appearanceSection — disabled; Fonti is dark-only for v1.
            defaultsSection
            feedbackSection
            librarySection
            aboutSection
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
}

#Preview {
    NavigationStack { SettingsView() }
        .modelContainer(for: SavedFont.self, inMemory: true)
}
