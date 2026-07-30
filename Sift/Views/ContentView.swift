import SwiftUI

/// Root content view. NavigationSplitView with sidebar + detail.
/// The detail column switches between grid, detail, empty, and loading states.
struct ContentView: View {
    @Environment(PhotoStore.self) var store

    var body: some View {
        @Bindable var store = store
        NavigationSplitView {
            SidebarView()
        } detail: {
            detailContent
        }
        .alert(
            "Delete \(store.pendingDeleteCount) photo\(store.pendingDeleteCount == 1 ? "" : "s")?",
            isPresented: $store.showDeleteConfirmation
        ) {
            Button("Delete", role: .destructive) {
                store.confirmDelete(alwaysSkip: false)
            }
            Button("Always Delete", role: .destructive) {
                store.confirmDelete(alwaysSkip: true)
            }
            Button("Cancel", role: .cancel) {
                store.cancelDelete()
            }
        } message: {
            Text("The selected photos will be moved to Trash.")
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
