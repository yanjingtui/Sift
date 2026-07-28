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
            if store.minRatingFilter > 0 {
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
        VStack(alignment: .leading, spacing: 6) {
            Text("Filter")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            FilterRow(title: "All Photos", stars: "", minRating: 0)
            FilterRow(title: "★ and above", stars: "★", minRating: 1)
            FilterRow(title: "★★ and above", stars: "★★", minRating: 2)
            FilterRow(title: "★★★ and above", stars: "★★★", minRating: 3)
            FilterRow(title: "★★★★ and above", stars: "★★★★", minRating: 4)
            FilterRow(title: "★★★★★", stars: "★★★★★", minRating: 5)
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
                Text("Copying… \(Int(progress * 100))%")
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
        panel.prompt = "Copy"
        panel.message = "Choose destination folder"

        if panel.runModal() == .OK, let dest = panel.url {
            store.copyFiltered(to: dest)
        }
    }
}

// MARK: - Filter Row

private struct FilterRow: View {
    @Environment(PhotoStore.self) var store
    let title: String
    let stars: String
    let minRating: Int

    private var count: Int {
        store.photos.filter { $0.rating >= minRating }.count
    }

    private var isSelected: Bool {
        store.minRatingFilter == minRating
    }

    var body: some View {
        Button {
            store.minRatingFilter = minRating
        } label: {
            HStack {
                Text(title)
                Spacer()
                Text("\(count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.accentColor.opacity(0.15))
                }
            }
        }
        .buttonStyle(.plain)
    }
}
