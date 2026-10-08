import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            AppStoreView()
                .tabItem { Label("App Store", systemImage: "bag.fill") }
            DownloadView()
                .tabItem { Label("Direct Link", systemImage: "link.badge.plus") }
            FilesView()
                .tabItem { Label("My Files", systemImage: "folder.fill") }
        }
    }
}
