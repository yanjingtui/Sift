import SwiftUI

/// PreferenceKey for collecting cell frames during drag-selection.
struct CellFrameKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

/// Grid of photo thumbnails. Main browsing view.
/// Supports click-to-open, Cmd/Shift multi-select, drag-rectangle select,
/// Cmd+A select all, Delete to trash, and right-click context menus.
struct PhotoGridView: View {
    @Environment(PhotoStore.self) var store
    @State private var cellFrames: [String: CGRect] = [:]
    @State private var dragStart: CGPoint?
    @State private var dragEnd: CGPoint?

    /// Current thumbnail tile size. Pinch on the trackpad or drag the toolbar
    /// slider to adjust. `baseThumbnailSize` anchors the pinch gesture so the
    /// reported magnification is always relative to where the gesture began.
    @State private var thumbnailSize: CGFloat = 140
    @State private var baseThumbnailSize: CGFloat = 140
    private let sizeRange: ClosedRange<CGFloat> = 80...260

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: thumbnailSize), spacing: 8)]
    }

    /// The current drag-selection rectangle in "grid" coordinate space.
    private var selectionRect: CGRect? {
        guard let start = dragStart, let end = dragEnd else { return nil }
        return CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )
    }

    var body: some View {
        Group {
            if store.filteredPhotos.isEmpty && store.isFilterActive {
                NoResultsView()
            } else if store.filteredPhotos.isEmpty {
                ContentUnavailableView(
                    "No Photos Found",
                    systemImage: "photo",
                    description: Text("This folder doesn't contain any supported image files.")
                )
            } else {
                gridContent
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                HStack(spacing: 10) {
                    // Count label sits left of the slider. The group is
                    // right-aligned, so the slider's right edge stays put
                    // while this label grows/shrinks to its left.
                    if store.hasSelection {
                        Text("\(store.selectedIDs.count) selected")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    } else if store.isFilterActive && !store.filteredPhotos.isEmpty {
                        Text("\(store.filteredPhotos.count) photos")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }

                    HStack(spacing: 2) {
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                            .imageScale(.small)
                            .frame(width: 14)
                        Slider(value: Binding(
                            get: { thumbnailSize },
                            set: { newValue in
                                thumbnailSize = newValue
                                baseThumbnailSize = newValue
                            }
                        ), in: sizeRange)
                        .controlSize(.small)
                        .frame(width: 100)
                        Image(systemName: "photo.fill")
                            .foregroundStyle(.secondary)
                            .imageScale(.small)
                            .frame(width: 14)
                    }
                }
                .padding(.horizontal, 6)
                .help("Adjust thumbnail size (pinch on trackpad)")
            }
        }
        // Hidden buttons provide global keyboard shortcuts (no focus required).
        .background {
            Group {
                Button("Select All") { store.selectAll() }
                    .keyboardShortcut("a", modifiers: .command)
                Button("Delete Selected") { store.requestDeleteSelected() }
                    .keyboardShortcut(.delete, modifiers: [])
                Button("Deselect") { store.clearSelection() }
                    .keyboardShortcut(.escape, modifiers: [])
            }
            .hidden()
        }
    }

    @ViewBuilder
    private var gridContent: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(Array(store.filteredPhotos.enumerated()), id: \.element.id) { index, photo in
                    ThumbnailCell(
                        photo: photo,
                        isSelected: store.selectedIDs.contains(photo.id),
                        cellHeight: thumbnailSize,
                        onSingleClick: { store.handleCellClick(photo: photo, index: index) },
                        onDoubleClick: {
                            store.clearSelection()
                            store.navigateToDetail(at: index)
                        }
                    )
                    .contextMenu {
                        contextMenuItems(for: photo, index: index)
                    }
                }
            }
            .padding()
            // Background captures drag-to-select starting from empty areas.
            .background(
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 10, coordinateSpace: .named("grid"))
                            .onChanged { value in
                                dragStart = value.startLocation
                                dragEnd = value.location
                                updateDragSelection()
                            }
                            .onEnded { _ in
                                dragStart = nil
                                dragEnd = nil
                            }
                    )
            )
            // Selection rectangle overlay.
            .overlay {
                if let rect = selectionRect {
                    Rectangle()
                        .fill(Color.accentColor.opacity(0.15))
                        .overlay(
                            Rectangle().strokeBorder(Color.accentColor, lineWidth: 1)
                        )
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)
                        .allowsHitTesting(false)
                }
            }
        }
        .coordinateSpace(name: "grid")
        // Trackpad pinch adjusts the thumbnail tile size. Uses simultaneous so
        // it never blocks two-finger scrolling through the grid.
        .simultaneousGesture(
            MagnifyGesture()
                .onChanged { value in
                    let proposed = baseThumbnailSize * value.magnification
                    thumbnailSize = min(sizeRange.upperBound, max(sizeRange.lowerBound, proposed))
                }
                .onEnded { _ in
                    baseThumbnailSize = thumbnailSize
                }
        )
        .onPreferenceChange(CellFrameKey.self) { frames in
            cellFrames = frames
        }
    }

    /// Select all cells intersecting the current drag rectangle.
    private func updateDragSelection() {
        guard let rect = selectionRect else { return }
        let hit = cellFrames.compactMap { (id, frame) -> String? in
            rect.intersects(frame) ? id : nil
        }
        store.setSelection(Set(hit))
    }

    @ViewBuilder
    private func contextMenuItems(for photo: PhotoItem, index: Int) -> some View {
        let inSelection = store.selectedIDs.contains(photo.id) && store.selectedIDs.count > 1
        let count = inSelection ? store.selectedIDs.count : 1

        Button("Open") {
            if !inSelection { store.clearSelection() }
            store.navigateToDetail(at: index)
        }
        Divider()
        Menu("Rate") {
            ForEach(PhotoRating.allCases) { bucket in
                Button {
                    store.setRating(photo, rating: bucket.rawValue)
                } label: {
                    Label(bucket.label, systemImage: bucket.icon)
                }
            }
            Divider()
            Button("Unrated") { store.setRating(photo, rating: 0) }
        }
        Divider()
        Button("Delete \(count) Photo\(count == 1 ? "" : "s")", role: .destructive) {
            if inSelection {
                store.requestDeleteSelected()
            } else {
                store.requestDelete(url: photo.url)
            }
        }
    }
}
