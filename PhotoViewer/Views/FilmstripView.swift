import SwiftUI

/// Horizontal scrolling thumbnail strip shown at the bottom of the detail view.
struct FilmstripView: View {
    @Environment(PhotoStore.self) var store

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
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
        .task(id: photo.url) {
            let img = await Task.detached(priority: .userInitiated) {
                ThumbnailGenerator.generate(url: photo.url, maxDimension: 140)
            }.value
            if !Task.isCancelled {
                image = img
            }
        }
    }
}
