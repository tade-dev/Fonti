import SwiftUI

/// Asks before adding a font that arrived from outside the app.
///
/// Opening a file from Files is one tap, and that shouldn't be enough to put a
/// typeface in someone's library permanently. The sheet shows the face itself —
/// rendered straight from the file, without installing it — so the decision is
/// made looking at the type rather than at a filename.
struct ImportFontSheet: View {
    let inspection: CustomFontManager.Inspection
    let fileName: String
    let onAdd: () -> Void
    let onCancel: () -> Void

    @AppStorage("fonti.hapticsEnabled") private var hapticsEnabled: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("ADD TO FONTI")
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.6)
                .foregroundStyle(Color.fontiAmber)
                .padding(.bottom, 24)

            // The specimen is the point of the sheet: this is the typeface
            // you're deciding about.
            Text("Aa Bb Cc")
                .font(Font(inspection.previewFont))
                .foregroundStyle(Color.fontiCream)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 20)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(inspection.familyName)
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(Color.fontiCream)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)

                Text(metadataLine)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.fontiCream.opacity(0.5))
                    .lineLimit(2)
                    .truncationMode(.middle)
            }

            if inspection.isDuplicate {
                Text("Already in your library. Adding again will be rejected.")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.fontiAmber.opacity(0.9))
                    .padding(.top, 14)
            }

            Spacer(minLength: 28)

            HStack(spacing: 12) {
                Button(role: .cancel, action: onCancel) {
                    Text("Not now")
                        .font(.system(size: 16, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.fontiCream.opacity(0.7))
                .glassEffect(in: .capsule)

                Button(action: onAdd) {
                    Text("Add Font")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.fontiInk)
                .background(Color.fontiAmber, in: .capsule)
                .disabled(inspection.isDuplicate)
                .opacity(inspection.isDuplicate ? 0.4 : 1)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.fontiInk)
        .presentationDetents([.height(380)])
        .presentationDragIndicator(.visible)
        .sensoryFeedback(.impact(weight: .light), trigger: inspection.familyName) { _, _ in
            hapticsEnabled
        }
    }

    private var metadataLine: String {
        var parts: [String] = []
        if let style = inspection.styleName, !style.isEmpty { parts.append(style) }
        parts.append(fileName)
        return parts.joined(separator: " · ")
    }
}
