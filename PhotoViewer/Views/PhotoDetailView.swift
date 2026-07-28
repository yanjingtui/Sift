import SwiftUI
import AppKit

/// Full-screen photo detail view with keyboard navigation and filmstrip.
struct PhotoDetailView: View {
    @Environment(PhotoStore.self) var store
    @State private var image: NSImage?

    private var photo: PhotoItem? {
        store.currentPhoto
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.ignoresSafeArea()

            // Main photo
            Group {
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    ProgressView()
                        .tint(.white)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Bottom floating control bar
            if let photo {
                VStack(spacing: 0) {
                    // Rating row
                    HStack {
                        Text(photo.fileName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        Spacer()

                        RatingStars(
                            rating: photo.rating,
                            size: 18,
                            interactive: true,
                            onRate: { rating in
                                store.setRating(photo, rating: rating)
                            }
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)

                    // Filmstrip
                    FilmstripView()
                        .frame(height: 86)
                        .padding(.bottom, 8)
                }
                .background(.ultraThinMaterial)
            }
        }
        .focusable()
        .onKeyPress(.leftArrow) {
            store.navigatePrev()
            return .handled
        }
        .onKeyPress(.rightArrow) {
            store.navigateNext()
            return .handled
        }
        .onKeyPress(.escape) {
            store.exitDetail()
            return .handled
        }
        .onKeyPress { press in
            // Number keys 0–5 for quick rating
            if let num = press.key.character.wholeNumberValue,
               (0...5).contains(num) {
                if let photo {
                    store.setRating(photo, rating: num)
                }
                return .handled
            }
            return .ignored
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    store.exitDetail()
                } label: {
                    Label("Grid", systemImage: "square.grid.2x2")
                }
            }
        }
        .task(id: photo?.url) {
            guard let url = photo?.url else {
                image = nil
                return
            }
            let img = await Task.detached(priority: .userInitiated) {
                ThumbnailGenerator.generate(url: url, maxDimension: 4000)
            }.value
            if !Task.isCancelled {
                image = img
            }
        }
    }
}
