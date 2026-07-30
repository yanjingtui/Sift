import SwiftUI
import AppKit

/// Self-contained grid thumbnail cell.
/// Displays the photo thumbnail, a persistent rating badge when rated, and a
/// compact rating picker on hover. Selection border is driven by the parent.
struct ThumbnailCell: View {
    let photo: PhotoItem
    var isSelected: Bool = false
    var cellHeight: CGFloat = 140
    var onSingleClick: () -> Void = {}
    var onDoubleClick: () -> Void = {}
    @Environment(PhotoStore.self) var store
    @State private var image: NSImage?
    @State private var isHovering = false
    /// Per-cell timestamp so we can distinguish a true double-click from two
    /// single clicks without waiting on SwiftUI's TapGesture(count: 2), which
    /// always delays the first click by the system double-click interval.
    @State private var lastTapTime: Date = .distantPast

    private var bucket: PhotoRating? { PhotoRating.from(rating: photo.rating) }

    var body: some View {
        ZStack(alignment: .bottom) {
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
            .frame(height: cellHeight)
            .clipped()

            // Persistent rating badge (top-leading). Hidden while hovering so
            // it does not crowd the compact picker.
            if !isHovering, let bucket {
                Image(systemName: bucket.icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(5)
                    .background(Circle().fill(bucket.color))
                    .shadow(radius: 1)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(6)
            }

            // Compact rating picker shown on hover.
            if isHovering {
                RatingPicker(rating: photo.rating, compact: true) { rating in
                    store.setRating(photo, rating: rating)
                }
                .padding(6)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                .padding(6)
                .transition(.opacity)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.accentColor, lineWidth: isSelected ? 3 : 0)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            // Single click fires immediately — no waiting on a double-click
            // timeout. A second tap within 0.35s is treated as a double-click
            // and opens the detail view.
            let now = Date()
            if now.timeIntervalSince(lastTapTime) < 0.35 {
                onDoubleClick()
                lastTapTime = .distantPast
            } else {
                onSingleClick()
                lastTapTime = now
            }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .task(id: photo.url) {
            let url = photo.url
            // Fast path: already cached (no I/O, no threading overhead)
            if let cached = ThumbnailGenerator.cachedThumbnail(url: url) {
                image = cached
                return
            }
            // Generate on a background task that inherits cancellation.
            // When the cell scrolls off-screen, generate() bails out at
            // the semaphore instead of queuing up file I/O.
            let img = await withTaskGroup(of: NSImage?.self) { group in
                group.addTask { ThumbnailGenerator.thumbnail(url: url) }
                return await group.next() ?? nil
            }
            if !Task.isCancelled {
                image = img
            }
        }
        .background(
            GeometryReader { geo in
                Color.clear.preference(
                    key: CellFrameKey.self,
                    value: [photo.id: geo.frame(in: .named("grid"))]
                )
            }
        )
    }
}
