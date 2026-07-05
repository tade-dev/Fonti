import Foundation

enum InSpaceMode: CaseIterable, Equatable {
    case photo, video, live

    var title: String {
        switch self {
        case .photo: return "Photo"
        case .video: return "Video"
        case .live: return "Live"
        }
    }
}
