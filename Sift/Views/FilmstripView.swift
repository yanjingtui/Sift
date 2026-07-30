import SwiftUI

/// Horizontal scrolling thumbnail strip shown at the bottom of the detail view.
struct FilmstripView: View {
    @Environment(PhotoStore.self) var store

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 4) {
                    ForEach(
                        Array(store.filteredPhotos.enumerated()),
                        id: \.element.id
                    ) { index, photo in
                        FilmstripCell(photo: photo, isSelected: index == store.selectedIndex)
                            .id(photo.id)
                            .onTapGesture {
                                store.selectedIndex = index
                            }
                    }
                }
                .padding(.horizontal)
            }
            .onChange(of: store.selectedIndex) { _, newIndex in
                guard let idx = newIndex, idx < store.filteredPhotos.count else { return }
                withAnimation(.easeInOut(duration: 0.2)) {
                    proxy.scrollTo(store.filteredPhotos[idx].id, anchor: .center)
                }
            }
        }
    }
}

// MARK: - Filmstrip Cell

private struct FilmstripCell: View {
    let photo: PhotoItem
    let isSelected: Bool
    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Rectangle().fill(.quaternary)
            }
        }
        .frame(width: 70, height: 70)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(
                    isSelected ? Color.accentColor : Color.clear,
                    lineWidth: 3
                )
        )
        .overlay(alignment: .topLeading) {
            if let bucket = PhotoRating.from(rating: photo.rating) {
                Image(systemName: bucket.icon)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(3)
                    .background(Circle().fill(bucket.color))
                    .padding(3)
            }
        }
        .task(id: photo.url) {
            let url = photo.url
            if let cached = ThumbnailGenerator.cachedThumbnail(url: url) {
                image = cached
                return
            }
            let img = await withTaskGroup(of: NSImage?.self) { group in
                group.addTask { ThumbnailGenerator.thumbnail(url: url) }
                return await group.next() ?? nil
            }
            if !Task.isCancelled {
                image = img
            }
        }
    }
}
