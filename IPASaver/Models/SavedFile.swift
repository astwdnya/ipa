import Foundation

/// A finished .ipa file stored inside the app's Documents folder.
struct SavedFile: Identifiable {
    let id = UUID()
    let url: URL
    let size: Int64
    let date: Date

    var name: String { url.lastPathComponent }
}
