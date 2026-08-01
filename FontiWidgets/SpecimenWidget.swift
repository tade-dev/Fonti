import WidgetKit
import SwiftUI

struct SpecimenEntry: TimelineEntry {
    let date: Date
    let font: WidgetFontEntry
}

struct SpecimenProvider: TimelineProvider {
    func placeholder(in context: Context) -> SpecimenEntry {
        SpecimenEntry(date: .now, font: WidgetSnapshotStore.fallback)
    }

    func getSnapshot(in context: Context, completion: @escaping (SpecimenEntry) -> Void) {
        let fonts = WidgetSnapshotStore.load()
        completion(SpecimenEntry(date: .now, font: fonts[0]))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SpecimenEntry>) -> Void) {
        let fonts = WidgetSnapshotStore.load()
        let now = Date()
        // Rotate every 45 minutes across saved favourites.
        let entries: [SpecimenEntry] = fonts.enumerated().map { index, font in
            SpecimenEntry(
                date: now.addingTimeInterval(TimeInterval(index) * 45 * 60),
                font: font
            )
        }
        let refresh = now.addingTimeInterval(TimeInterval(max(fonts.count, 1)) * 45 * 60)
        completion(Timeline(entries: entries, policy: .after(refresh)))
    }
}

struct SpecimenWidget: Widget {
    let kind = "FontiSpecimenWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SpecimenProvider()) { entry in
            SpecimenWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    Color(red: 0x0D / 255, green: 0x0D / 255, blue: 0x0D / 255)
                }
        }
        .configurationDisplayName("Specimen")
        .description("A live sample of a font you love.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct SpecimenWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SpecimenEntry

    private var ink: Color { Color(red: 0x0D / 255, green: 0x0D / 255, blue: 0x0D / 255) }
    private var cream: Color { Color(red: 0xF5 / 255, green: 0xF0 / 255, blue: 0xE8 / 255) }
    private var amber: Color { Color(red: 0xE8 / 255, green: 0xA0 / 255, blue: 0x40 / 255) }

    private var deepLink: URL {
        var components = URLComponents()
        components.scheme = "fonti"
        components.host = "preview"
        components.queryItems = [
            URLQueryItem(name: "family", value: entry.font.familyName)
        ]
        return components.url ?? URL(string: "fonti://preview")!
    }

    var body: some View {
        Group {
            switch family {
            case .systemMedium:
                medium
            default:
                small
            }
        }
        .widgetURL(deepLink)
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Aa")
                .font(.custom(entry.font.familyName, size: 44))
                .foregroundStyle(cream)
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            Spacer(minLength: 0)

            Text(entry.font.displayName)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(cream.opacity(0.7))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(14)
    }

    private var medium: some View {
        HStack(alignment: .center, spacing: 16) {
            Text(sampleGlyphs)
                .font(.custom(entry.font.familyName, size: 52))
                .foregroundStyle(cream)
                .minimumScaleFactor(0.4)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 6) {
                Text("FONTI")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(2)
                    .foregroundStyle(amber.opacity(0.9))

                Text(entry.font.displayName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(cream)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)

                Text(entry.font.sampleText)
                    .font(.system(size: 11))
                    .foregroundStyle(cream.opacity(0.45))
                    .multilineTextAlignment(.trailing)
                    .lineLimit(2)
            }
            .frame(width: 120, alignment: .trailing)
        }
        .padding(16)
    }

    private var sampleGlyphs: String {
        let sample = entry.font.sampleText.trimmingCharacters(in: .whitespacesAndNewlines)
        if sample.isEmpty { return "Aa" }
        if sample.count <= 4 { return sample }
        // Prefer a short punchy mark for the medium hero.
        return "Aa"
    }
}

#Preview(as: .systemSmall) {
    SpecimenWidget()
} timeline: {
    SpecimenEntry(date: .now, font: WidgetSnapshotStore.fallback)
}

#Preview(as: .systemMedium) {
    SpecimenWidget()
} timeline: {
    SpecimenEntry(
        date: .now,
        font: WidgetFontEntry(
            familyName: "Georgia",
            displayName: "Georgia",
            sampleText: "Find your type."
        )
    )
}
