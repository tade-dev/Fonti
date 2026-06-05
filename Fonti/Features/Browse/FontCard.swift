import SwiftUI

struct FontCard: View {
    let family: FontFamily
    let displayText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(displayText)
                .font(.custom(family.id, size: 28))
                .foregroundStyle(Color.fontiCream)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                Text(family.displayName.uppercased())
                    .font(.caption2)
                    .tracking(1.2)
                    .foregroundStyle(Color.fontiCream.opacity(0.65))
                Spacer()
                // Heart button placeholder — wired in Task 8.
                Image(systemName: "heart")
                    .foregroundStyle(Color.fontiCream.opacity(0.65))
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(in: .rect(cornerRadius: 22))
    }
}

#Preview {
    ZStack {
        Color.fontiInk.ignoresSafeArea()
        FontCard(
            family: FontFamily(id: "Georgia", displayName: "Georgia"),
            displayText: "The quick brown fox"
        )
        .padding()
    }
}
