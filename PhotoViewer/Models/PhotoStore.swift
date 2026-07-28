import Foundation
import SwiftUI

/// Central app state. All view layers read from and write to this single
/// @Observable instance injected via `.environment(store)`.
@Observable
final class PhotoStore {

    // MARK: - State

    var currentFolder: URL?
    var photos: [PhotoItem] = []
    var selectedIndex: Int?
    var minRatingFilter: Int = 0     // 0 = show all
    var viewMode: ViewMode = .grid
    var isLoading = false
    var copyState = CopyState.idle

    // MARK: - Enums

    enum ViewMode { case grid, detail }

    enum CopyState: Equatable {
        case idle
        case copying(progress: Double)
        case done(count: Int, destination: URL)
        case failed(message: String)
    }

    // MARK: - Computed

    var filteredPhotos: [PhotoItem] {
        guard minRatingFilter > 0 else { return photos }
        return photos.filter { $0.rating >= minRatingFilter }
    }

    var markedCount: Int {
        photos.filter { $0.rating > 0 }.count
    }

    /// The photo currently being viewed in detail mode (nil if not in detail).
    var currentPhoto: PhotoItem? {
        guard let idx = selectedIndex, idx < filteredPhotos.count else { return nil }
        return filteredPhotos[idx]
    }

    // MARK: - Folder Loading

    func loadFolder(_ url: URL) {
        isLoading = true
        currentFolder = url
        selectedIndex = nil
        copyState = .idle

        DispatchQueue.global(qos: .userInitiated).async {
            let urls = FileService.scanImages(in: url)
            let items = urls.map { url in
                PhotoItem(url: url, rating: ExifService.readRating(url: url))
            }
            DispatchQueue.main.async {
                self.photos = items
                self.isLoading = false
            }
        }
    }

    // MARK: - Rating

    func setRating(_ photo: PhotoItem, rating: Int) {
        // Update in-memory array immediately for responsive UI
        if let idx = photos.firstIndex(where: { $0.id == photo.id }) {
            photos[idx].rating = rating
        }

        // Write EXIF asynchronously (lossless)
        let url = photo.url
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try ExifService.writeRating(url: url, rating: rating)
            } catch {
                #if DEBUG
                print("EXIF write failed for \(url.lastPathComponent): \(error)")
                #endif
            }
        }
    }

    // MARK: - Navigation

    func navigateToDetail(at index: Int) {
        guard indices.contains(index) else { return }
        selectedIndex = index
        viewMode = .detail
    }

    func navigateNext() {
        guard let idx = selectedIndex, idx < filteredPhotos.count - 1 else { return }
        selectedIndex = idx + 1
    }

    func navigatePrev() {
        guard let idx = selectedIndex, idx > 0 else { return }
        selectedIndex = idx - 1
    }

    func exitDetail() {
        viewMode = .grid
        selectedIndex = nil
    }

    // MARK: - Copy

    func copyFiltered(to destination: URL) {
        let urls = filteredPhotos.map { $0.url }
        guard !urls.isEmpty else { return }

        copyState = .copying(progress: 0)

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                for (i, url) in urls.enumerated() {
                    let dest = FileService.uniqueDestination(
                        for: destination.appendingPathComponent(url.lastPathComponent)
                    )
                    try FileManager.default.copyItem(at: url, to: dest)

                    let progress = Double(i + 1) / Double(urls.count)
                    DispatchQueue.main.async {
                        self.copyState = .copying(progress: progress)
                    }
                }
                DispatchQueue.main.async {
                    self.copyState = .done(count: urls.count, destination: destination)
                }
            } catch {
                DispatchQueue.main.async {
                    self.copyState = .failed(message: error.localizedDescription)
                }
            }
        }
    }

    // MARK: - Helpers

    private var indices: Range<Int> {
        0..<filteredPhotos.count
    }
}
