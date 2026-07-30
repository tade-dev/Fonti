import SwiftUI

/// Layout picker — same chip language as Background.
struct TemplateChipStrip: View {
    let selection: SpecimenTemplate
    var onSelect: (SpecimenTemplate) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Layout")
                .font(.caption2)
                .tracking(1.4)
                .textCase(.uppercase)
                .foregroundStyle(Color.fontiCream.opacity(0.55))

            HStack(spacing: 10) {
                ForEach(SpecimenTemplate.allCases) { template in
                    chip(for: template)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 4)
        }
    }

    private func chip(for template: SpecimenTemplate) -> some View {
        let selected = selection == template

        return Button {
            guard selection != template else { return }
            onSelect(template)
        } label: {
            Image(systemName: template.symbolName)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(selected ? Color.fontiInk : Color.fontiCream.opacity(0.85))
                .frame(width: 36, height: 36)
                .background {
                    Circle()
                        .fill(selected ? Color.fontiAmber : Color.fontiCream.opacity(0.08))
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
        .accessibilityLabel("\(template.title) layout")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
