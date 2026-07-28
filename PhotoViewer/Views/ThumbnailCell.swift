import SwiftUI
import AppKit

/// Self-contained grid thumbnail cell.
/// Displays the photo thumbnail, shows a rating overlay on hover,
/// and handles star clicks internally via RatingStars.
struct ThumbnailCell: View {
    let photo: PhotoItem
    @Environment(PhotoStore.self) var store
    @State private var image: NSImage?
    @State private var isHovering = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // Image area
            Group {
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Rectangle()
                        .fill(.quaternary)
                        .overlay(ProgressView())
                }
            }
            .frame(minWidth: 0, maxWidth: .infinity)
            .frame(height: 140)
            .clipped()

            // Rating overlay — visible when rated or on hover
            if photo.rating > 0 || isHovering {
                RatingStars(
                    rating: photo.rating,
                    size: 10,
                    interactive: true,
                    onRate: { rating in store.setRating(photo, rating: rating) }
                )
                .padding(6)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6))
                .padding(6)
                .transition(.opacity)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .task(id: photo.url) {
            let img = await Task.detached(priority: .userInitiated) {
                ThumbnailGenerator.generate(url: photo.url, maxDimension: 300)
            }.value
            if !Task.isCancelled {
                image = img
            }
        }
    }
}
