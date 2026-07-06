import SwiftUI
import RealityKit
import AVFoundation
import ARKit

struct InSpaceView: View {
    let text: String
    let familyName: String
    let bold: Bool
    let italic: Bool

    @Environment(\.dismiss) private var dismiss
    @AppStorage("hasSeenInSpaceHint") private var hasSeenHint = false

    @State private var mode: InSpaceMode = .photo
    @State private var material: InSpaceMaterial = .cream
    @State private var arView: ARView?
    @State private var textEntity: ModelEntity?
    @State private var meshError: String?
    @State private var isBusy = false
    @State private var captured: CapturedMedia?
    @State private var errorState: ErrorState?
    @State private var showHint = false
    @State private var toastMessage: String?
    @State private var coordinator: ARCaptureCoordinator?

    init(text: String, familyName: String, initialSize: CGFloat, bold: Bool, italic: Bool) {
        self.text = text
        self.familyName = familyName
        self.bold = bold
        self.italic = italic
    }

    var body: some View {
        ZStack {
            if !ARWorldTrackingConfiguration.isSupported {
                unsupportedView
            } else {
                sceneAndControls
            }
        }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .fullScreenCover(item: $captured) { media in
            CapturePreviewSheet(media: media) {
                captured = nil
            }
        }
        .alert(
            errorState?.title ?? "",
            isPresented: Binding(
                get: { errorState != nil },
                set: { if !$0 { errorState = nil } }
            ),
            presenting: errorState
        ) { state in
            state.primaryButton
            Button("Close", role: .cancel) { dismiss() }
        } message: { state in
            Text(state.message)
        }
        .task {
            if coordinator == nil {
                coordinator = ARCaptureCoordinator(
                    snapshotter: { nil },
                    recorder: ReplayKitScreenRecorder()
                )
            }
            await checkPermissionAndShowHint()
        }
        .task(id: arView) {
            guard let v = arView else { return }
            coordinator?.updateSnapshotter { await v.snapshotImage() }
        }
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }

    private var sceneAndControls: some View {
        ZStack {
            InSpaceScene(
                text: text,
                familyName: familyName,
                bold: bold,
                italic: italic,
                material: $material,
                arView: $arView,
                textEntity: $textEntity,
                meshError: $meshError
            )
            .ignoresSafeArea()

            InSpaceControls(
                mode: $mode,
                material: $material,
                isRecording: coordinator?.isRecording ?? false,
                onShutter: shutterTapped,
                onReset: resetTextEntity,
                onMaterialCycle: { material = material.next() },
                onClose: { dismiss() }
            )

            if showHint {
                VStack {
                    Spacer()
                    hintOverlay
                        .padding(.bottom, 160)
                }
            }
        }
        .overlay(alignment: .top) {
            if let msg = toastMessage {
                Text(msg)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.fontiCream)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .glassEffect(in: .capsule)
                    .padding(.top, 60)
                    .transition(.opacity)
                    .task {
                        try? await Task.sleep(nanoseconds: 3_000_000_000)
                        withAnimation { toastMessage = nil }
                    }
            }
        }
        .onChange(of: meshError) { _, err in
            if let err {
                withAnimation { toastMessage = err }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: ProcessInfo.thermalStateDidChangeNotification)) { _ in
            switch ProcessInfo.processInfo.thermalState {
            case .serious, .critical:
                arView?.renderOptions.insert(.disableCameraGrain)
                if ProcessInfo.processInfo.thermalState == .critical {
                    withAnimation { toastMessage = "Cool down — AR quality reduced." }
                }
            default:
                arView?.renderOptions.remove(.disableCameraGrain)
            }
        }
        .onAppear { checkStorage() }
    }

    private var unsupportedView: some View {
        VStack(spacing: 16) {
            Text("In Space works on iPhone XS and newer.")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.fontiCream)
                .multilineTextAlignment(.center)
            Button("Close") { dismiss() }
                .foregroundStyle(Color.fontiInk)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.fontiCream, in: .capsule)
        }
        .padding(40)
        .background(Color.fontiInk.ignoresSafeArea())
    }

    private var hintOverlay: some View {
        Text("Pinch to scale. Drag to move. Two fingers to rotate.")
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Color.fontiCream)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .glassEffect(in: .capsule)
            .transition(.opacity)
    }

    private func shutterTapped() {
        guard let coordinator else { return }
        if mode == .video, coordinator.isRecording {
            coordinator.stopRecordingEarly()
            return
        }
        guard !isBusy else { return }
        Task {
            isBusy = true
            do {
                let media = try await coordinator.capture(mode: mode)
                captured = media
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            } catch {
                errorState = ErrorState(
                    title: "Capture failed",
                    message: "\(error)",
                    primaryButton: Button("OK") {}
                )
            }
            isBusy = false
        }
    }

    private func resetTextEntity() {
        guard let entity = textEntity else { return }
        var t = entity.transform
        t.translation = SIMD3<Float>(0, 0, -0.4)
        t.scale = SIMD3<Float>(repeating: 0.15)
        t.rotation = simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0))
        entity.move(to: t, relativeTo: nil, duration: 0.4, timingFunction: .easeInOut)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func checkPermissionAndShowHint() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .notDetermined {
            _ = await AVCaptureDevice.requestAccess(for: .video)
        }
        let newStatus = AVCaptureDevice.authorizationStatus(for: .video)
        if newStatus != .authorized {
            errorState = .cameraDenied
            return
        }
        if !hasSeenHint {
            withAnimation(.easeInOut(duration: 0.5)) { showHint = true }
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            withAnimation(.easeInOut(duration: 0.5)) { showHint = false }
            hasSeenHint = true
        }
    }

    private func checkStorage() {
        let values = try? URL(fileURLWithPath: NSHomeDirectory())
            .resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        let free = values?.volumeAvailableCapacityForImportantUsage ?? 0
        let mb = free / 1_000_000
        if mb < 100 {
            withAnimation { toastMessage = "Low storage — only Photo available." }
        }
    }
}

extension CapturedMedia: Identifiable {
    var id: String {
        switch self {
        case .photo(let u): return "photo-\(u.path)"
        case .video(let u): return "video-\(u.path)"
        case .livePhoto(let j, let m): return "live-\(j.path)-\(m.path)"
        }
    }
}

struct ErrorState: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let primaryButton: Button<Text>

    static let cameraDenied = ErrorState(
        title: "Camera access needed",
        message: "Fonti needs the camera to place your type in the world.",
        primaryButton: Button("Open Settings") {
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        }
    )

    static let captureFailed = ErrorState(
        title: "Capture failed",
        message: "Something went wrong. Try again.",
        primaryButton: Button("OK") {}
    )
}

extension ARView {
    @MainActor
    func snapshotImage() async -> UIImage? {
        await withCheckedContinuation { cont in
            self.snapshot(saveToHDR: false) { image in cont.resume(returning: image) }
        }
    }
}
