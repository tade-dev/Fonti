import SwiftUI

struct FullScreenPreviewView: View {
    let family: FontFamily
    let initialText: String

    @State private var text: String
    @State private var size: CGFloat = 48

    init(family: FontFamily, initialText: String) {
        self.family = family
        self.initialText = initialText
        _text = State(initialValue: initialText.isEmpty ? family.displayName : initialText)
    }

    var body: some View {
        VStack {
            Spacer()
            Text(text)
                .font(.custom(family.id, size: size))
                .foregroundStyle(Color.fontiCream)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Spacer()
            controls
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.fontiInk.ignoresSafeArea())
        .navigationTitle(family.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var controls: some View {
        VStack(spacing: 14) {
            HStack {
                Text("12").font(.caption).foregroundStyle(Color.fontiCream.opacity(0.6))
                Slider(value: $size, in: 12...96)
                    .tint(.fontiAmber)
                Text("96").font(.caption).foregroundStyle(Color.fontiCream.opacity(0.6))
            }
        }
        .padding(16)
        .glassEffect(in: .rect(cornerRadius: 22))
    }
}

#Preview {
    NavigationStack {
        FullScreenPreviewView(
            family: FontFamily(id: "Georgia", displayName: "Georgia"),
            initialText: "The quick brown fox jumps over the lazy dog"
        )
    }
}
