import Foundation
import SwiftUI
import AppKit

/// Central app state. All view layers read from and write to this single
/// @Observable instance injected via `.environment(store)`.
@Observable
final class PhotoStore {

    // MARK: - State

    var currentFolder: URL?
    var photos: [PhotoItem] = []
    var selectedIndex: Int?
    /// Empty = show all photos. Otherwise photos whose normalised rating is in
    /// the set are shown. Values are restricted to {0, 1, 3, 5}.
    var selectedRatings: Set<Int> = []
    var viewMode: ViewMode = .grid
    var isLoading = false
    var copyState = CopyState.idle

    // Selection (multi-select in grid)
    var selectedIDs: Set<String> = []
    var lastClickedIndex: Int?

    // Delete confirmation
    var showDeleteConfirmation = false
    var pendingDeleteCount = 0

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
        guard !selectedRatings.isEmpty else { return photos }
        return photos.filter { selectedRatings.contains($0.rating) }
    }

    /// True when a filter is actively narrowing the grid.
    var isFilterActive: Bool { !selectedRatings.isEmpty }

    var markedCount: Int {
        photos.filter { $0.rating > 0 }.count
    }

    /// The photo currently being viewed in detail mode (nil if not in detail).
    var currentPhoto: PhotoItem? {
        guard let idx = selectedIndex, idx < filteredPhotos.count else { return nil }
        return filteredPhotos[idx]
    }

    var selectedPhotos: [PhotoItem] {
        filteredPhotos.filter { selectedIDs.contains($0.id) }
    }

    var hasSelection: Bool {
        !selectedIDs.isEmpty
    }

    // MARK: - Folder Loading

    func loadFolder(_ url: URL) {
        isLoading = true
        currentFolder = url
        selectedIndex = nil
        copyState = .idle
        selectedIDs = []
        lastClickedIndex = nil
        photos = []

        DispatchQueue.global(qos: .userInitiated).async {
            let urls = FileService.scanImages(in: url)

            if urls.isEmpty {
                DispatchQueue.main.async { self.isLoading = false }
                return
            }

            // Phase 1: populate the grid immediately with default ratings so
            // thumbnails show without waiting on per-file metadata reads.
            let items = urls.map { PhotoItem(url: $0, rating: 0) }
            DispatchQueue.main.async {
                self.photos = items
                self.isLoading = false
            }

            // Phase 2: read ratings concurrently in the background and patch
            // them in as they arrive.
            self.populateRatings(urls: urls)
        }
    }

    /// Concurrently read ratings for already-loaded photos and update them
    /// in batches. Runs entirely in the background at low priority so visible
    /// cells always win I/O slots over prefetch.
    private func populateRatings(urls: [URL]) {
        DispatchQueue.global(qos: .background).async {
            let groupSize = 4
            for start in stride(from: 0, to: urls.count, by: groupSize) {
                let end = min(start + groupSize, urls.count)
                let count = end - start
                var ratings = [Int](repeating: 0, count: count)
                DispatchQueue.concurrentPerform(iterations: count) { i in
                    let url = urls[start + i]
                    // Normalise 2→1 and 4→3 so the picker only ever sees
                    // {0,1,3,5}; the underlying file is untouched.
                    ratings[i] = PhotoRating.normalize(ExifService.readRating(url: url))
                    // Pre-generate the thumbnail into the shared cache so
                    // grid scrolling hits cache instead of reading the SD card.
                    _ = ThumbnailGenerator.thumbnail(url: url)
                }

                let changed = (0..<count).filter { ratings[$0] > 0 }
                if !changed.isEmpty {
                    DispatchQueue.main.async {
                        for i in changed {
                            let idx = start + i
                            if idx < self.photos.count {
                                self.photos[idx].rating = ratings[i]
                            }
                        }
                    }
                }
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

    // MARK: - Rating Filter

    /// Replace the active filter with a single rating bucket.
    func setRatingFilter(_ ratings: Set<Int>) {
        selectedRatings = ratings
    }

    /// Toggle one bucket on/off (Cmd+click in sidebar). Toggling the last
    /// remaining bucket off returns to "show all".
    func toggleRatingFilter(_ rating: Int) {
        if selectedRatings.contains(rating) {
            selectedRatings.remove(rating)
        } else {
            selectedRatings.insert(rating)
        }
    }

    func clearRatingFilter() {
        selectedRatings.removeAll()
    }

    /// Count of photos that match a given rating bucket (0 = unrated).
    func count(forRating rating: Int) -> Int {
        photos.filter { $0.rating == rating }.count
    }

    // MARK: - Selection

    /// Handle a click on a grid cell, respecting modifier keys.
    /// - No modifier: clear selection, navigate to detail.
    /// - Cmd: toggle this photo in the selection.
    /// - Shift: select range from last clicked to here.
    func handleCellClick(photo: PhotoItem, index: Int) {
        let flags = NSEvent.modifierFlags
        if flags.contains(.command) {
            if selectedIDs.contains(photo.id) {
                selectedIDs.remove(photo.id)
            } else {
                selectedIDs.insert(photo.id)
            }
            lastClickedIndex = index
        } else if flags.contains(.shift), let start = lastClickedIndex {
            let from = min(start, index)
            let to = max(start, index)
            for i in from...to {
                guard i < filteredPhotos.count else { break }
                selectedIDs.insert(filteredPhotos[i].id)
            }
        } else {
            // Single click: select only this photo
            selectedIDs = [photo.id]
            lastClickedIndex = index
        }
    }

    func selectAll() {
        selectedIDs = Set(filteredPhotos.map { $0.id })
    }

    func clearSelection() {
        selectedIDs.removeAll()
    }

    func setSelection(_ ids: Set<String>) {
        selectedIDs = ids
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
        copyItems(urls: urls, to: destination)
    }

    func copySelected(to destination: URL) {
        let urls = selectedPhotos.map { $0.url }
        copyItems(urls: urls, to: destination)
    }

    private func copyItems(urls: [URL], to destination: URL) {
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

    // MARK: - Delete

    func requestDeleteSelected() {
        let urls = selectedPhotos.map { $0.url }
        guard !urls.isEmpty else { return }
        requestDelete(urls: urls)
    }

    func requestDeleteCurrent() {
        guard let photo = currentPhoto else { return }
        requestDelete(urls: [photo.url])
    }

    func requestDelete(url: URL) {
        requestDelete(urls: [url])
    }

    private func requestDelete(urls: [URL]) {
        if UserDefaults.standard.bool(forKey: "skipDeleteConfirmation") {
            performDelete(urls: urls)
        } else {
            pendingDeleteCount = urls.count
            pendingDeleteURLs = urls
            showDeleteConfirmation = true
        }
    }

    func confirmDelete(alwaysSkip: Bool) {
        if alwaysSkip {
            UserDefaults.standard.set(true, forKey: "skipDeleteConfirmation")
        }
        let urls = pendingDeleteURLs
        pendingDeleteURLs = []
        showDeleteConfirmation = false
        performDelete(urls: urls)
    }

    func cancelDelete() {
        pendingDeleteURLs = []
        showDeleteConfirmation = false
    }

    private var pendingDeleteURLs: [URL] = []

    private func performDelete(urls: [URL]) {
        let urlPaths = Set(urls.map { $0.path })
        DispatchQueue.global(qos: .userInitiated).async {
            for url in urls {
                var resultURL: NSURL?
                try? FileManager.default.trashItem(at: url, resultingItemURL: &resultURL)

                // Trash the .xmp sidecar too if present, so we don't leave
                // orphan rating files behind when the image is deleted.
                let sidecar = ExifService.sidecarURL(for: url)
                if FileManager.default.fileExists(atPath: sidecar.path) {
                    var sidecarResultURL: NSURL?
                    try? FileManager.default.trashItem(at: sidecar, resultingItemURL: &sidecarResultURL)
                }
            }
            DispatchQueue.main.async {
                self.photos.removeAll { urlPaths.contains($0.url.path) }
                self.selectedIDs.subtract(urlPaths)
                // Clamp selectedIndex if the current detail photo was deleted
                if let idx = self.selectedIndex {
                    if self.filteredPhotos.isEmpty {
                        self.exitDetail()
                    } else if idx >= self.filteredPhotos.count {
                        self.selectedIndex = self.filteredPhotos.count - 1
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private var indices: Range<Int> {
        0..<filteredPhotos.count
    }
}
