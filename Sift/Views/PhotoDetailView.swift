import SwiftUI
import AppKit

/// Full-screen photo detail view with keyboard navigation and filmstrip.
struct PhotoDetailView: View {
    @Environment(PhotoStore.self) var store
    @State private var image: NSImage?
    @FocusState private var isFocused: Bool

    /// Zoom state held in an @Observable so pinch/scroll updates only
    /// invalidate the photo sub-tree, not the whole detail view body.
    @State private var zoom = ZoomState()
    @State private var scrollMonitor: Any?

    private var photo: PhotoItem? {
        store.currentPhoto
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.ignoresSafeArea()

            // Main photo
            Group {
                if let image {
                    ZoomablePhoto(image: image, zoom: zoom)
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

                        RatingPicker(
                            rating: photo.rating,
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
        .focused($isFocused)
        .onAppear {
            isFocused = true
            installScrollMonitor()
        }
        .onDisappear {
            removeScrollMonitor()
        }
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
        .onKeyPress(.delete) {
            store.requestDeleteCurrent()
            return .handled
        }
        .onKeyPress(.deleteForward) {
            store.requestDeleteCurrent()
            return .handled
        }
        .onKeyPress { press in
            // 0 = unrated, 1/2/3 = the three buckets (maybe/good/love)
            guard let num = press.key.character.wholeNumberValue,
                  (0...3).contains(num) else { return .ignored }
            let target: Int
            switch num {
            case 0:  target = 0
            case 1:  target = PhotoRating.maybe.rawValue
            case 2:  target = PhotoRating.good.rawValue
            default: target = PhotoRating.love.rawValue
            }
            if let photo {
                store.setRating(photo, rating: target)
            }
            return .handled
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    store.exitDetail()
                } label: {
                    Label("Grid", systemImage: "square.grid.2x2")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 2) {
                    Image(systemName: "minus.magnifyingglass")
                        .foregroundStyle(.secondary)
                        .imageScale(.small)
                        .frame(width: 14)
                    Slider(value: Binding(
                        get: { zoom.scale },
                        set: { newValue in
                            zoom.scale = newValue
                            zoom.baseScale = newValue
                            if newValue <= 1 { zoom.reset() }
                        }
                    ), in: ZoomState.range)
                    .controlSize(.small)
                    .frame(width: 90)
                    Image(systemName: "plus.magnifyingglass")
                        .foregroundStyle(.secondary)
                        .imageScale(.small)
                        .frame(width: 14)
                }
                .padding(.horizontal, 6)
                .help("Zoom (pinch on trackpad, double-click photo to reset)")
            }
            ToolbarItem(placement: .primaryAction) {
                Button(role: .destructive) {
                    store.requestDeleteCurrent()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .task(id: photo?.url) {
            // Reset zoom/pan whenever the displayed photo changes.
            zoom.silentReset()

            guard let url = photo?.url else {
                image = nil
                return
            }
            // Phase 1: placeholder from the cached grid thumbnail (instant).
            // On cache miss, generate a quick 300px thumbnail first.
            if let cached = ThumbnailGenerator.cachedThumbnail(url: url) {
                image = cached
            } else {
                let preview = await withTaskGroup(of: NSImage?.self) { group in
                    group.addTask { ThumbnailGenerator.thumbnail(url: url) }
                    return await group.next() ?? nil
                }
                if !Task.isCancelled { image = preview }
            }

            // Phase 2: full-resolution decode, replaces the placeholder
            let full = await withTaskGroup(of: NSImage?.self) { group in
                group.addTask { ThumbnailGenerator.generate(url: url, maxDimension: 2560) }
                return await group.next() ?? nil
            }
            if !Task.isCancelled { image = full }
        }
    }

    // MARK: - Two-finger scroll → pan

    /// When zoomed in, two-finger scroll on the trackpad pans the photo. We
    /// install a local scroll-wheel monitor (instead of wrapping in a
    /// ScrollView) so pinch-zoom and drag-pan keep working unchanged. Events
    /// are returned unaltered so they still reach other scroll views when not
    /// zoomed.
    private func installScrollMonitor() {
        scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak zoom] event in
            guard let zoom, zoom.scale > 1.001 else { return event }
            let dx = event.scrollingDeltaX
            let dy = event.scrollingDeltaY
            guard dx != 0 || dy != 0 else { return event }
            // Natural-scroll mapping: content follows the fingers.
            zoom.offset.width += dx
            zoom.offset.height += dy
            zoom.baseOffset.width += dx
            zoom.baseOffset.height += dy
            return event
        }
    }

    private func removeScrollMonitor() {
        if let scrollMonitor {
            NSEvent.removeMonitor(scrollMonitor)
            self.scrollMonitor = nil
        }
    }
}

// MARK: - Zoom state

/// Isolated zoom/pan model. Kept in its own @Observable so a pinch does not
/// invalidate the whole `PhotoDetailView` body (which would re-evaluate the
/// filmstrip, toolbar and control bar on every frame).
@Observable
final class ZoomState {
    var scale: CGFloat = 1
    var baseScale: CGFloat = 1
    var offset: CGSize = .zero
    var baseOffset: CGSize = .zero
    var anchor: UnitPoint = .center
    /// Latch set on the first onChanged of a pinch so the anchor-switch
    /// compensation runs exactly once per gesture.
    var gestureInProgress = false

    static let range: ClosedRange<CGFloat> = 1...8

    func reset() {
        withAnimation(.easeOut(duration: 0.2)) { applyReset() }
    }

    /// Reset without animation — used when switching photos.
    func silentReset() {
        applyReset()
    }

    private func applyReset() {
        scale = 1
        baseScale = 1
        offset = .zero
        baseOffset = .zero
        anchor = .center
        gestureInProgress = false
    }
}

// MARK: - Zoomable photo

/// The photo plus its pinch / drag / double-click interactions. Lives in its
/// own view so zoom updates re-render only this subtree.
private struct ZoomablePhoto: View {
    let image: NSImage
    let zoom: ZoomState

    var body: some View {
        // GeometryReader gives us the frame size needed for the anchor-switch
        // compensation math (in points).
        GeometryReader { geo in
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: geo.size.width, height: geo.size.height)
                .scaleEffect(zoom.scale, anchor: zoom.anchor)
                .offset(zoom.offset)
                .contentShape(Rectangle())
                .gesture(zoomGesture(size: geo.size))
                .onTapGesture(count: 2) { zoom.reset() }
        }
    }

    /// Combined pinch + drag. `simultaneously` lets drag-pan continue tracking
    /// while a pinch is in progress (and vice-versa).
    private func zoomGesture(size: CGSize) -> some Gesture {
        MagnifyGesture()
            .onChanged { value in
                if !zoom.gestureInProgress {
                    // The pinch anchor follows the cursor (two-finger
                    // midpoint). Compensate the offset so the image does not
                    // visually jump when the anchor moves away from the
                    // previous one. Derived from scaleEffect's transform:
                    //   screen = scale * point + (1 - scale) * anchor + offset
                    // Keeping `screen` fixed while anchor/offset change gives:
                    //   Δoffset = (1 - scale) * (oldAnchor - newAnchor) * size
                    let old = zoom.anchor
                    let new = value.startAnchor
                    zoom.offset.width += (1 - zoom.scale) * (old.x - new.x) * size.width
                    zoom.offset.height += (1 - zoom.scale) * (old.y - new.y) * size.height
                    zoom.baseOffset = zoom.offset
                    zoom.anchor = new
                    zoom.gestureInProgress = true
                }
                zoom.scale = min(ZoomState.range.upperBound,
                                 max(ZoomState.range.lowerBound, zoom.baseScale * value.magnification))
            }
            .onEnded { _ in
                zoom.baseScale = zoom.scale
                zoom.gestureInProgress = false
                if zoom.scale <= 1 { zoom.reset() }
            }
            .simultaneously(with: DragGesture()
                .onChanged { value in
                    guard zoom.scale > 1 else { return }
                    zoom.offset = CGSize(
                        width: zoom.baseOffset.width + value.translation.width,
                        height: zoom.baseOffset.height + value.translation.height
                    )
                }
                .onEnded { _ in
                    zoom.baseOffset = zoom.offset
                }
            )
    }
}
