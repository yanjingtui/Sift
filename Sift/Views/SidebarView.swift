import SwiftUI
import AppKit

/// Sidebar with three sections: open folder, filter by rating, copy filtered photos.
struct SidebarView: View {
    @Environment(PhotoStore.self) var store

    var body: some View {
        VStack(spacing: 0) {
            // Section 1: Open Folder
            Button {
                openFolderPanel()
            } label: {
                Label("Open Folder", systemImage: "folder")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding()

            Divider()

            // Section 2: Folder info + filters
            if store.currentFolder != nil {
                folderInfoSection
                Divider()
                filterSection
            }

            Spacer()

            // Section 3: Copy (bottom, only when filter active)
            if store.isFilterActive {
                Divider()
                copySection
                    .padding()
            }
        }
        .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 300)
        .frame(maxHeight: .infinity)
    }

    // MARK: - Folder Info

    private var folderInfoSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Current Folder")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(store.currentFolder?.lastPathComponent ?? "")
                .font(.headline)
                .lineLimit(1)
                .truncationMode(.middle)

            Text("\(store.photos.count) photos · \(store.markedCount) marked")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }

    // MARK: - Filter

    private var filterSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Filter")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if store.isFilterActive {
                    Button("Clear") { store.clearRatingFilter() }
                        .buttonStyle(.borderless)
                        .font(.caption)
                }
            }
            .padding(.horizontal)

            FilterChip(title: "All Photos", rating: nil,
                       icon: "square.grid.2x2", color: .accentColor,
                       count: store.photos.count)
            FilterChip(title: "Unrated", rating: 0,
                       icon: "circle.dashed", color: .secondary,
                       count: store.count(forRating: 0))
            FilterChip(title: PhotoRating.maybe.label, rating: PhotoRating.maybe.rawValue,
                       icon: PhotoRating.maybe.icon, color: PhotoRating.maybe.color,
                       count: store.count(forRating: PhotoRating.maybe.rawValue))
            FilterChip(title: PhotoRating.good.label, rating: PhotoRating.good.rawValue,
                       icon: PhotoRating.good.icon, color: PhotoRating.good.color,
                       count: store.count(forRating: PhotoRating.good.rawValue))
            FilterChip(title: PhotoRating.love.label, rating: PhotoRating.love.rawValue,
                       icon: PhotoRating.love.icon, color: PhotoRating.love.color,
                       count: store.count(forRating: PhotoRating.love.rawValue))

            Text("Click to select · ⌘-click to combine")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Copy

    @ViewBuilder
    private var copySection: some View {
        switch store.copyState {
        case .idle:
            Button {
                startCopy()
            } label: {
                Label("Copy \(store.filteredPhotos.count) to…", systemImage: "doc.on.doc")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

        case .copying(let progress):
            VStack(spacing: 6) {
                ProgressView(value: progress)
                Text("Copying… \(Int(progress * 100))%%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

        case .done(let count, let destination):
            VStack(spacing: 8) {
                Label("Copied \(count) photos", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .frame(maxWidth: .infinity)

                Button {
                    NSWorkspace.shared.open(destination)
                } label: {
                    Label("Reveal in Finder", systemImage: "folder")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    store.copyState = .idle
                } label: {
                    Label("Copy Again", systemImage: "doc.on.doc")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }

        case .failed(let message):
            VStack(spacing: 6) {
                Label("Copy failed", systemImage: "xmark.circle.fill")
                    .foregroundStyle(.red)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }

    // MARK: - Panel helpers

    private func openFolderPanel() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Open"
        panel.message = "Choose a folder containing photos"

        if panel.runModal() == .OK, let url = panel.url {
            store.loadFolder(url)
        }
    }

    private func startCopy() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = "Copy"
        panel.message = "Choose destination folder"

        if panel.runModal() == .OK, let dest = panel.url {
            store.copyFiltered(to: dest)
        }
    }
}

// MARK: - Filter Chip

/// A single filter row in the sidebar.
/// - Plain click: single-select this bucket (replaces current filter).
/// - ⌘-click: toggle this bucket on/off, allowing multi-bucket filters.
/// - `rating == nil` represents "All Photos" and always clears the filter.
private struct FilterChip: View {
    @Environment(PhotoStore.self) var store
    let title: String
    let rating: Int?      // nil = All Photos
    var icon: String
    var color: Color
    let count: Int

    private var active: Bool {
        guard let r = rating else { return store.selectedRatings.isEmpty }
        return store.selectedRatings.contains(r)
    }

    var body: some View {
        Button {
            handleTap()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(active ? color : .secondary)
                Text(title)
                    .foregroundStyle(active ? .primary : .secondary)
                Spacer()
                Text("\(count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .background {
                if active {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(color.opacity(0.15))
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func handleTap() {
        let flags = NSEvent.modifierFlags
        guard let r = rating else {
            // "All Photos" always resets to show everything.
            store.clearRatingFilter()
            return
        }
        if flags.contains(.command) {
            store.toggleRatingFilter(r)
        } else {
            store.setRatingFilter([r])
        }
    }
}
