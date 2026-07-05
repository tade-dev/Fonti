// Fonti/Features/InSpace/CapturePreviewSheet.swift
import SwiftUI
import AVKit
import PhotosUI

struct CapturePreviewSheet: View {
    let media: CapturedMedia
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.fontiInk.ignoresSafeArea()
            VStack(spacing: 24) {
                previewContent
                    .frame(maxHeight: .infinity)
                    .padding(.top, 40)
                shareRow
                    .padding(.bottom, 40)
            }
        }
        .presentationBackground(.clear)
    }

    @ViewBuilder
    private var previewContent: some View {
        switch media {
        case .photo(let url):
            if let img = UIImage(contentsOfFile: url.path) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .padding(.horizontal, 24)
            }
        case .video(let url):
            LoopingPlayer(url: url)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .padding(.horizontal, 24)
        case .livePhoto(let jpg, let mov):
            LivePhotoPreview(jpgURL: jpg, movURL: mov)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .padding(.horizontal, 24)
        }
    }

    private var shareRow: some View {
        HStack(spacing: 20) {
            Button("Retake", action: onDismiss)
                .foregroundStyle(Color.fontiCream)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .glassEffect(in: .capsule)

            shareButton
        }
    }

    @ViewBuilder
    private var shareButton: some View {
        switch media {
        case .photo(let url), .video(let url):
            ShareLink(item: url) {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                    Text("Share")
                }
                .foregroundStyle(Color.fontiInk)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.fontiCream, in: .capsule)
            }
        case .livePhoto(let jpg, let mov):
            Button {
                shareLivePhoto(jpg: jpg, mov: mov)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                    Text("Share")
                }
                .foregroundStyle(Color.fontiInk)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.fontiCream, in: .capsule)
            }
        }
    }

    private func shareLivePhoto(jpg: URL, mov: URL) {
        let controller = UIActivityViewController(activityItems: [jpg, mov], applicationActivities: nil)
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.keyWindow?.rootViewController?
            .present(controller, animated: true)
    }
}

private final class LoopingPlayerView: UIView {
    var playerLayer: AVPlayerLayer?
    var looper: AVPlayerLooper?

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer?.frame = bounds
    }
}

private struct LoopingPlayer: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> LoopingPlayerView {
        let container = LoopingPlayerView()
        let player = AVQueuePlayer()
        let item = AVPlayerItem(url: url)
        container.looper = AVPlayerLooper(player: player, templateItem: item)

        let layer = AVPlayerLayer(player: player)
        layer.videoGravity = .resizeAspect
        container.layer.addSublayer(layer)
        container.playerLayer = layer
        player.play()
        return container
    }

    func updateUIView(_ view: LoopingPlayerView, context: Context) {
        view.setNeedsLayout()
    }
}

private struct LivePhotoPreview: UIViewRepresentable {
    let jpgURL: URL
    let movURL: URL

    func makeUIView(context: Context) -> PHLivePhotoView {
        let view = PHLivePhotoView()
        view.contentMode = .scaleAspectFit
        PHLivePhoto.request(withResourceFileURLs: [jpgURL, movURL], placeholderImage: nil, targetSize: .zero, contentMode: .aspectFit) { livePhoto, _ in
            if let lp = livePhoto { view.livePhoto = lp; view.startPlayback(with: .full) }
        }
        return view
    }

    func updateUIView(_ view: PHLivePhotoView, context: Context) {}
}
