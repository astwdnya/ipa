import Foundation

/// Reads/writes .ipa files inside the app's Documents folder.
/// The folder is exposed to the Files app via UIFileSharingEnabled.
final class FileStore: ObservableObject {
    static let shared = FileStore()

    @Published var files: [SavedFile] = []

    var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    init() {
        refresh()
    }

    func refresh() {
        let fm = FileManager.default
        let docs = documentsURL
        if !fm.fileExists(atPath: docs.path) {
            try? fm.createDirectory(at: docs, withIntermediateDirectories: true)
        }
        let contents = (try? fm.contentsOfDirectory(
            at: docs,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey],
            options: .skipsHiddenFiles)) ?? []

        let saved: [SavedFile] = contents.compactMap { url in
            guard url.pathExtension.lowercased() == "ipa" else { return nil }
            let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
            let size = Int64(values?.fileSize ?? 0)
            let date = values?.contentModificationDate ?? Date()
            return SavedFile(url: url, size: size, date: date)
        }
        .sorted { $0.date > $1.date }

        DispatchQueue.main.async {
            self.files = saved
        }
    }

    func uniqueDestination(for fileName: String) -> URL {
        let fm = FileManager.default
        var candidate = documentsURL.appendingPathComponent(fileName)
        var counter = 1
        let base = (fileName as NSString).deletingPathExtension
        let ext = (fileName as NSString).pathExtension
        while fm.fileExists(atPath: candidate.path) {
            candidate = documentsURL.appendingPathComponent("\(base) (\(counter)).\(ext)")
            counter += 1
        }
        return candidate
    }

    /// Copies a picked file (from the Files app) into Documents. Returns true on success.
    @discardableResult
    func importFile(at sourceURL: URL) -> Bool {
        let scoped = sourceURL.startAccessingSecurityScopedResource()
        defer { if scoped { sourceURL.stopAccessingSecurityScopedResource() } }

        let destination = uniqueDestination(for: sourceURL.lastPathComponent)
        do {
            try FileManager.default.copyItem(at: sourceURL, to: destination)
            refresh()
            return true
        } catch {
            return false
        }
    }

    func delete(_ file: SavedFile) {
        try? FileManager.default.removeItem(at: file.url)
        refresh()
    }

    func totalUsedBytes() -> Int64 {
        files.reduce(0) { $0 + $1.size }
    }
}
