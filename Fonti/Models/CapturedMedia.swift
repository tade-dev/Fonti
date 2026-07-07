import Foundation

enum CapturedMedia {
    case photo(URL)
    case video(URL)
    case livePhoto(jpgURL: URL, movURL: URL)
}
