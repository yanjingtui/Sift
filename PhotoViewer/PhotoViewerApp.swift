import SwiftUI
import AppKit

@main
struct PhotoViewerApp: App {
    @State private var store = PhotoStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .frame(minWidth: 900, minHeight: 600)
        }
        .commands {
            // Replace the default "New" command with "Open Folder"
            CommandGroup(replacing: .newItem) {
                Button("Open Folder…") { openFolderPanel() }
                    .keyboardShortcut("o", modifiers: .command)
            }
        }
    }

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
}
