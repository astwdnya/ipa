import SwiftUI

@main
struct IPASaverApp: App {
    @StateObject private var downloadManager = DownloadManager.shared
    @StateObject private var fileStore = FileStore.shared

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(downloadManager)
                .environmentObject(fileStore)
                .tint(Theme.accent)
        }
    }
}
