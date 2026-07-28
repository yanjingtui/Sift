import SwiftUI

/// Shown when no folder is open.
struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("Open a Folder to Start")
                .font(.title2)
                .foregroundStyle(.secondary)

            Text("Browse your photos, rate them,\nand copy your favorites.")
                .font(.callout)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

/// Shown when the active filter returns no photos.
struct NoResultsView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "star.slash")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text("No photos match this filter")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
