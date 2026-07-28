import SwiftUI

/// Grid of photo thumbnails. Main browsing view.
struct PhotoGridView: View {
    @Environment(PhotoStore.self) var store

    private let columns = [GridItem(.adaptive(minimum: 140), spacing: 8)]

    var body: some View {
        Group {
            if store.filteredPhotos.isEmpty && store.minRatingFilter > 0 {
                NoResultsView()
            } else if store.filteredPhotos.isEmpty {
                // Folder open but no supported images found
                ContentUnavailableView(
                    "No Photos Found",
                    systemImage: "photo",
                    description: Text("This folder doesn't contain any supported image files.")
                )
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(store.filteredPhotos) { photo in
                            ThumbnailCell(photo: photo)
                                .onTapGesture(count: 2) {
                                    if let idx = store.filteredPhotos.firstIndex(of: photo) {
                                        store.navigateToDetail(at: idx)
                                    }
                                }
                        }
                    }
                    .padding()
                }
            }
        }
        .toolbar {
            if store.minRatingFilter > 0 && !store.filteredPhotos.isEmpty {
                ToolbarItem(placement: .primaryAction) {
                    Text("\(store.filteredPhotos.count) photos")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            }
        }
    }
}
