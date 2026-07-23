import SwiftUI
import PhotosUI
import UIKit

/// Horizontal strip of background thumbnails. Tapping flips the specimen card;
/// the Photo chip opens the system picker when no image is set yet (or on
/// a second intentional pick via long-press).
struct BackgroundChipStrip: View {
    @Binding var selection: PreviewBackground
    @Binding var customImage: UIImage?
    let isFlipping: Bool
    let onSelect: (PreviewBackground) -> Void

    @State private var photoItem: PhotosPickerItem?
    @State private var showPhotoPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Background")
                .font(.caption2)
                .tracking(1.4)
                .textCase(.uppercase)
                .foregroundStyle(Color.fontiCream.opacity(0.55))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(PreviewBackground.chipOrder) { style in
                        chip(for: style)
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 4)
            }
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $photoItem, matching: .images)
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    customImage = image
                    onSelect(.custom)
                }
            }
        }
    }

    @ViewBuilder
    private func chip(for style: PreviewBackground) -> some View {
        let selected = selection == style

        Button {
            tap(style)
        } label: {
            ZStack {
                chipFill(for: style)
                    .frame(width: 36, height: 36)
                    .clipShape(Circle())

                if style == .custom && customImage == nil {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.fontiCream.opacity(0.85))
                }

                if style == .liquidGlass {
                    Image(systemName: "rectangle.on.rectangle.angled")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.fontiCream.opacity(0.75))
                }
            }
            .overlay {
                Circle()
                    .strokeBorder(
                        selected ? Color.fontiAmber : Color.fontiCream.opacity(0.15),
                        lineWidth: selected ? 2 : 1
                    )
            }
            .scaleEffect(selected ? 1.08 : 1)
            .animation(.spring(response: 0.32, dampingFraction: 0.7), value: selected)
        }
        .buttonStyle(.plain)
        .disabled(isFlipping)
        .opacity(isFlipping && !selected ? 0.55 : 1)
        .accessibilityLabel("\(style.title) background")
        .accessibilityAddTraits(selected ? .isSelected : [])
        .contextMenu {
            if style == .custom {
                Button {
                    showPhotoPicker = true
                } label: {
                    Label(
                        customImage == nil ? "Choose Photo" : "Change Photo",
                        systemImage: "photo"
                    )
                }
            }
        }
    }

    private func tap(_ style: PreviewBackground) {
        if style == .custom {
            if customImage == nil {
                showPhotoPicker = true
            } else {
                onSelect(.custom)
            }
            return
        }
        onSelect(style)
    }

    @ViewBuilder
    private func chipFill(for style: PreviewBackground) -> some View {
        switch style {
        case .liquidGlass:
            Color.fontiCream.opacity(0.12)
                .glassEffect(in: .circle)
        case .custom:
            Color.fontiCream.opacity(0.08)
                .overlay {
                    if let customImage {
                        Image(uiImage: customImage)
                            .resizable()
                            .scaledToFill()
                    }
                }
                .clipped()
        default:
            style.fill(customImage: nil)
        }
    }
}
