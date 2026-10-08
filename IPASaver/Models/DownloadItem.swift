import Foundation

enum DownloadState: Equatable {
    case waiting
    case downloading
    case paused
    case finished
    case failed(String)

    var isTerminal: Bool {
        if case .finished = self { return true }
        if case .failed = self { return true }
        return false
    }
}

/// Tracks a single .ipa download (progress, speed, state).
final class DownloadItem: Identifiable, ObservableObject {
    let id = UUID()
    let url: URL
    let fileName: String

    @Published var state: DownloadState = .waiting
    @Published var downloadedBytes: Int64 = 0
    @Published var totalBytes: Int64 = 0
    @Published var speedBytesPerSecond: Double = 0

    var progress: Double {
        guard totalBytes > 0 else { return 0 }
        return min(1.0, Double(downloadedBytes) / Double(totalBytes))
    }

    init(url: URL, fileName: String) {
        self.url = url
        self.fileName = fileName
    }
}
