import SwiftUI

/// Root content view. NavigationSplitView with sidebar + detail.
/// The detail column switches between grid, detail, empty, and loading states.
struct ContentView: View {
    @Environment(PhotoStore.self) var store

    var body: some View {
        NavigationSplitView {
            SidebarView()
        } detail: {
            detailContent
        }
    }

    @ViewBuilder
    private var detailContent: some View {
        if store.isLoading {
            ProgressView("Loading photos…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if store.currentFolder == nil {
            EmptyStateView()
        } else if store.viewMode == .detail && store.selectedIndex != nil {
            PhotoDetailView()
        } else {
            PhotoGridView()
        }
    }
}
