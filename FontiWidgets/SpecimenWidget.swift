import WidgetKit
import SwiftUI
import AppIntents

struct SpecimenEntry: TimelineEntry {
    let date: Date
    let font: WidgetFontEntry
    var source: WidgetFontSource = .featured
    /// True when the user has no saved fonts but asked for their favourite —
    /// we show an invitation rather than a seed pretending to be their taste.
    var isEmpty: Bool = false
}

struct SpecimenProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SpecimenEntry {
        SpecimenEntry(date: .now, font: WidgetSnapshotStore.fallback)
    }

    func snapshot(
        for configuration: SpecimenConfigurationIntent,
        in context: Context
    ) async -> SpecimenEntry {
        entry(for: configuration)
    }

    func timeline(
        for configuration: SpecimenConfigurationIntent,
        in context: Context
    ) async -> Timeline<SpecimenEntry> {
        // One entry, one reload a day at local midnight. Content only changes
        // when the featured font rolls over or the app publishes a new
        // favourite — and publishing reloads us directly, so a rotation timer
        // would only spend refresh budget to redraw the same thing.
        Timeline(entries: [entry(for: configuration)], policy: .after(nextMidnight()))
    }

    private func entry(for configuration: SpecimenConfigurationIntent) -> SpecimenEntry {
        // Imported faces live in the App Group; pull them into this process
        // before anything tries to render them.
        SharedFontContainer.registerAll()
        FontAvailability.refresh()

        switch configuration.source {
        case .featured:
            return SpecimenEntry(date: .now, font: FeaturedFont.entry(), source: .featured)

        case .favourite:
            guard !WidgetSnapshotStore.hasNoUserFonts,
                  let latest = WidgetSnapshotStore.load().first
            else {
                return SpecimenEntry(
                    date: .now,
                    font: WidgetSnapshotStore.fallback,
                    source: .favourite,
                    isEmpty: true
                )
            }
            return SpecimenEntry(date: .now, font: latest, source: .favourite)

        case .specific:
            guard let name = configuration.font?.id, !name.isEmpty else {
                // Configured for a specific font but none chosen yet — the
                // featured face is a better answer than an error.
                return SpecimenEntry(date: .now, font: FeaturedFont.entry(), source: .featured)
            }
            // Prefer the stored snapshot: it carries the user's own sample text
            // and, for imports, the filename needed to register the face.
            if let match = WidgetSnapshotStore.load().first(where: {
                $0.familyName.caseInsensitiveCompare(name) == .orderedSame
            }) {
                return SpecimenEntry(date: .now, font: match, source: .specific)
            }
            return SpecimenEntry(
                date: .now,
                font: WidgetFontEntry(
                    familyName: name,
                    displayName: name,
                    sampleText: FeaturedFont.specimenLine()
                ),
                source: .specific
            )
        }
    }

    private func nextMidnight(from date: Date = .now, calendar: Calendar = .current) -> Date {
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: date) else {
            return date.addingTimeInterval(86_400)
        }
        return calendar.startOfDay(for: tomorrow)
    }
}

struct SpecimenWidget: Widget {
    let kind = "FontiSpecimenWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: SpecimenConfigurationIntent.self,
            provider: SpecimenProvider()
        ) { entry in
            SpecimenWidgetView(entry: entry)
                .containerBackground(for: .widget) { Color.fontiInk }
        }
        .configurationDisplayName("Specimen")
        .description("A piece of typography for your Home Screen.")
        .supportedFamilies(Self.supportedFamilies)
    }

    private static var supportedFamilies: [WidgetFamily] {
        var families: [WidgetFamily] = [
            .systemSmall,
            .systemMedium,
            .systemLarge,
            // iPad and Mac only; harmless to declare from an iPhone app.
            .systemExtraLarge
        ]
        // The full-page iPhone widget, new in iOS 27. Added conditionally so
        // Fonti keeps its 26.2 deployment target.
        if #available(iOS 27.0, *) {
            families.append(.systemExtraLargePortrait)
        }
        return families
    }
}

struct SpecimenWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode

    let entry: SpecimenEntry

    private enum Layout { case small, medium, large, poster }

    private var layout: Layout {
        if #available(iOS 27.0, *) {
            if family == .systemExtraLargePortrait { return .poster }
        }
        switch family {
        case .systemSmall: return .small
        case .systemMedium: return .medium
        // `.systemExtraLarge` (iPad/Mac) is landscape — wide and short — so the
        // large composition fits it far better than the portrait poster would.
        default: return .large
        }
    }

    private var font: ResolvedFont { ResolvedFont(entry.font) }

    private var sourceLabel: String? {
        switch entry.source {
        case .featured: return "Today"
        case .favourite: return "Favourite"
        case .specific: return nil
        }
    }

    private func deepLink(to familyName: String) -> URL {
        var components = URLComponents()
        components.scheme = "fonti"
        components.host = "preview"
        components.queryItems = [URLQueryItem(name: "family", value: familyName)]
        return components.url ?? URL(string: "fonti://preview")!
    }

    var body: some View {
        Group {
            if entry.isEmpty {
                emptyState
            } else {
                switch layout {
                case .small: small
                case .medium: medium
                case .large: large
                case .poster: poster
                }
            }
        }
        .environment(\.palette, WidgetPalette(mode: renderingMode))
        .widgetURL(deepLink(to: entry.font.familyName))
    }

    // MARK: - Small — one font, one impression

    private var small: some View {
        VStack(alignment: .leading, spacing: 0) {
            FontiWidgetHeader(label: sourceLabel)

            Spacer(minLength: 4)

            FontSpecimen(font: font, text: "Aa", size: 56)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 4)

            FontMetadata(font: font, size: 12)
        }
    }

    // MARK: - Medium — the face, and what it's called

    private var medium: some View {
        VStack(alignment: .leading, spacing: 0) {
            FontiWidgetHeader(label: sourceLabel)

            // Centre the pair in whatever height is left, rather than letting a
            // Spacer shove it to the bottom edge.
            HStack(alignment: .center, spacing: 18) {
                FontSpecimen(font: font, text: "Aa", size: 60)

                VStack(alignment: .leading, spacing: 10) {
                    FontMetadata(font: font, size: 14, caption: captionForFace)
                    if let pairing = font.pairing {
                        FontPairingPreview(pairing: pairing, size: 17)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }

    // MARK: - Large — an editorial specimen

    private var large: some View {
        VStack(alignment: .leading, spacing: 0) {
            FontiWidgetHeader(label: sourceLabel)

            Spacer(minLength: 12)

            FontSpecimen(
                font: font,
                text: entry.font.sampleText,
                size: 34,
                lineLimit: 4,
                lineSpacing: -1
            )

            Spacer(minLength: 12)

            WidgetRule()
                .padding(.bottom, 10)

            HStack(alignment: .bottom) {
                FontMetadata(font: font, size: 14, caption: captionForFace)
                Spacer(minLength: 8)
                WidgetFooter()
            }
        }
    }

    // MARK: - Poster — the full page

    private var poster: some View {
        // Two blocks — specimen at the top, credits at the bottom — with a
        // single flexible gap between them. Even spacers would spread the slack
        // into four vague gaps; one gap reads as deliberate negative space.
        VStack(alignment: .leading, spacing: 0) {
            FontiWidgetHeader(label: sourceLabel, size: 11)
                .padding(.bottom, 28)

            FontSpecimen(
                font: font,
                text: entry.font.sampleText,
                size: 54,
                lineLimit: 4,
                lineSpacing: 2
            )
            .padding(.bottom, 18)

            FontSpecimen(font: font, text: "AaBbCc 0123", size: 26)
                .opacity(0.5)

            Spacer(minLength: 24)

            WidgetRule()
                .padding(.bottom, 12)

            FontMetadata(font: font, size: 17, caption: captionForFace)

            if let pairing = font.pairing {
                WidgetRule()
                    .padding(.top, 16)
                    .padding(.bottom, 12)

                // Tapping the pairing opens *that* face, reusing the same
                // deep-link verb rather than inventing a second one.
                Link(destination: deepLink(to: pairing)) {
                    FontPairingPreview(pairing: pairing, size: 30)
                }
            }

            WidgetFooter()
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.top, 18)
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 0) {
            FontiWidgetHeader()
                .padding(.bottom, layout == .small ? 10 : 22)

            Text("Find a typeface\nworth keeping.")
                .font(.system(size: layout == .small ? 17 : 28, design: .serif))
                .foregroundStyle(Color.fontiCream)
                .lineSpacing(2)
                .lineLimit(3)
                .minimumScaleFactor(0.6)
                .widgetAccentable()

            Spacer(minLength: 10)

            WidgetFooter(title: "Explore fonts")
        }
        // Without this the stack shrinks to the width of its widest child and
        // the system centres it, pulling the wordmark off the left margin.
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Fonti. Find a typeface worth keeping. Open to explore fonts.")
    }

    /// Only worth saying when the real face can't be shown — otherwise the
    /// specimen above already speaks for itself.
    private var captionForFace: String? {
        font.canRenderTypeface ? nil : "Preview unavailable"
    }
}
