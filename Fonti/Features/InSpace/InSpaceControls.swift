// Fonti/Features/InSpace/InSpaceControls.swift
import SwiftUI

struct InSpaceControls: View {
    @Binding var mode: InSpaceMode
    @Binding var material: InSpaceMaterial
    let isRecording: Bool
    let onShutter: () -> Void
    let onReset: () -> Void
    let onMaterialCycle: () -> Void
    let onClose: () -> Void

    @State private var blinkOn: Bool = true

    var body: some View {
        VStack {
            HStack {
                closeButton
                Spacer()
                if isRecording { recordingIndicator }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            Spacer()

            VStack(spacing: 20) {
                modeChipStrip
                    .opacity(isRecording ? 0.15 : 1.0)
                shutterRow
            }
            .padding(.bottom, 32)
        }
    }

    private var closeButton: some View {
        Button(action: onClose) {
            Image(systemName: "xmark")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.fontiCream)
                .frame(width: 44, height: 44)
        }
        .glassEffect(in: .circle)
        .accessibilityLabel("Close")
    }

    private var recordingIndicator: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.red)
                .frame(width: 10, height: 10)
                .opacity(blinkOn ? 0.9 : 0.25)
                .task(id: isRecording) {
                    guard isRecording else { blinkOn = true; return }
                    while !Task.isCancelled && isRecording {
                        withAnimation(.easeInOut(duration: 0.45)) { blinkOn.toggle() }
                        try? await Task.sleep(nanoseconds: 450_000_000)
                    }
                }
            Text("REC")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.fontiCream)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .glassEffect(in: .capsule)
    }

    private var modeChipStrip: some View {
        HStack(spacing: 8) {
            ForEach(InSpaceMode.allCases, id: \.self) { m in
                Button {
                    mode = m
                    UISelectionFeedbackGenerator().selectionChanged()
                } label: {
                    Text(m.title)
                        .font(.system(size: 14, weight: .medium))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .foregroundStyle(mode == m ? Color.fontiInk : Color.fontiCream)
                        .background(mode == m ? Color.fontiCream : Color.clear, in: .capsule)
                }
            }
        }
        .padding(6)
        .glassEffect(in: .capsule)
    }

    private var shutterRow: some View {
        HStack(spacing: 40) {
            Button(action: onReset) {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.fontiCream)
                    .frame(width: 48, height: 48)
            }
            .glassEffect(in: .circle)

            Button(action: onShutter) {
                ZStack {
                    Circle()
                        .strokeBorder(Color.fontiCream, lineWidth: 3)
                        .frame(width: 76, height: 76)
                    Circle()
                        .fill(shutterInnerColor)
                        .frame(width: 60, height: 60)
                }
            }
            .accessibilityLabel("Capture")

            Button(action: onMaterialCycle) {
                Text(material.displayName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.fontiCream)
                    .frame(width: 48, height: 48)
            }
            .glassEffect(in: .circle)
        }
    }

    private var shutterInnerColor: Color {
        switch mode {
        case .photo: return .fontiCream
        case .video: return isRecording ? .red : .fontiAmber
        case .live: return .fontiAmber
        }
    }
}

#Preview {
    @Previewable @State var mode: InSpaceMode = .photo
    @Previewable @State var material: InSpaceMaterial = .cream
    ZStack {
        Color.fontiInk.ignoresSafeArea()
        InSpaceControls(
            mode: $mode,
            material: $material,
            isRecording: false,
            onShutter: {},
            onReset: {},
            onMaterialCycle: { material = material.next() },
            onClose: {}
        )
    }
}
