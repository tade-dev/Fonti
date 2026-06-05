import SwiftUI

struct SavedFontCard: View {
    let family: FontFamily

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(family.displayName)
                .font(.custom(family.id, size: 22))
                .foregroundStyle(Color.fontiCream)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("Aa Bb")
                .font(.custom(family.id, size: 36))
                .foregroundStyle(Color.fontiCream.opacity(0.85))
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)

            Text(family.displayName.uppercased())
                .font(.caption2)
                .tracking(1.2)
                .foregroundStyle(Color.fontiCream.opacity(0.55))
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
        .glassEffect(in: .rect(cornerRadius: 22))
    }
}

#Preview {
    ZStack {
        Color.fontiInk.ignoresSafeArea()
        SavedFontCard(family: FontFamily(id: "Georgia", displayName: "Georgia"))
            .padding()
    }
}
