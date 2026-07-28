import Foundation

/// Lightweight value type representing a single photo in the browser.
/// Used throughout the view layer; rating is the source-of-truth from EXIF.
struct PhotoItem: Identifiable, Hashable {
    let id: String   // url.path
    let url: URL
    var rating: Int  // 0 (unrated) ... 5

    var fileName: String { url.lastPathComponent }

    init(url: URL, rating: Int = 0) {
        self.url = url
        self.id = url.path
        self.rating = rating
    }
}
