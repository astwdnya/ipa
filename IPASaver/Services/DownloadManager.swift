import Foundation

/// Manages in-app .ipa downloads with progress, pause/resume and cancel.
/// Files are ONLY downloaded — the app never installs anything.
final class DownloadManager: NSObject, ObservableObject {
    static let shared = DownloadManager()

    @Published var items: [DownloadItem] = []

    private let lock = NSLock()
    private var tasks: [Int: URLSessionDownloadTask] = [:]
    private var itemsByTask: [Int: DownloadItem] = [:]
    private var samples: [Int: (bytes: Int64, time: TimeInterval)] = [:]

    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 120
        config.timeoutIntervalForResource = 60 * 60
        config.allowsCellularAccess = true
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()

    // MARK: - Public API

    func start(urlString: String) {
        guard let url = DownloadManager.normalize(urlString: urlString) else { return }
        let fileName = DownloadManager.fileName(from: url)
        let item = DownloadItem(url: url, fileName: fileName)

        lock.lock()
        defer { lock.unlock() }
        let task = session.downloadTask(with: url)
        tasks[task.taskIdentifier] = task
        itemsByTask[task.taskIdentifier] = item
        samples[task.taskIdentifier] = (0, Date().timeIntervalSince1970)

        DispatchQueue.main.async {
            item.state = .downloading
            self.items.insert(item, at: 0)
            task.resume()
        }
    }

    static func normalize(urlString: String) -> URL? {
        var s = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }
        let lower = s.lowercased()
        if !lower.hasPrefix("http://") && !lower.hasPrefix("https://") {
            s = "https://" + s
        }
        guard let url = URL(string: s), let host = url.host, !host.isEmpty else { return nil }
        return url
    }

    static func fileName(from url: URL) -> String {
        var name = url.lastPathComponent
        if name.isEmpty || name == "/" {
            name = "app-\(Int(Date().timeIntervalSince1970)).ipa"
        }
        if url.pathExtension.lowercased() != "ipa" {
            name += ".ipa"
        }
        return name
    }

    func togglePause(_ item: DownloadItem) {
        lock.lock()
        defer { lock.unlock() }
        guard let task = taskFor(item) else { return }
        switch item.state {
        case .downloading:
            task.suspend()
            item.state = .paused
        case .paused:
            task.resume()
            item.state = .downloading
        default:
            break
        }
    }

    /// Cancels a running download, or dismisses a finished/failed row.
    func cancel(_ item: DownloadItem) {
        lock.lock()
        defer { lock.unlock() }
        if let task = taskFor(item) {
            task.cancel()
        }
        removeItem(item)
    }

    func clearTerminalItems() {
        lock.lock()
        defer { lock.unlock() }
        let terminal = items.filter { $0.state.isTerminal }
        items.removeAll { $0.state.isTerminal }
        for item in terminal {
            forgetMappings(item)
        }
    }

    // MARK: - Internals (call with lock held)

    private func taskFor(_ item: DownloadItem) -> URLSessionDownloadTask? {
        itemsByTask.first { $0.value === item }?.value
    }

    private func removeItem(_ item: DownloadItem) {
        DispatchQueue.main.async {
            self.items.removeAll { $0 === item }
        }
        forgetMappings(item)
    }

    private func forgetMappings(_ item: DownloadItem) {
        let keys = itemsByTask.filter { $0.value === item }.map { $0.key }
        for key in keys {
            tasks.removeValue(forKey: key)
            itemsByTask.removeValue(forKey: key)
            samples.removeValue(forKey: key)
        }
    }
}

// MARK: - URLSessionDownloadDelegate

extension DownloadManager: URLSessionDownloadDelegate {

    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {
        lock.lock()
        let item = itemsByTask[downloadTask.taskIdentifier]
        lock.unlock()
        guard let item = item else { return }

        let destination = FileStore.shared.uniqueDestination(for: item.fileName)
        do {
            try FileManager.default.createDirectory(
                at: destination.deletingLastPathComponent(),
                withIntermediateDirectories: true)
            try FileManager.default.moveItem(at: location, to: destination)
            DispatchQueue.main.async {
                item.state = .finished
                item.speedBytesPerSecond = 0
                item.downloadedBytes = max(item.totalBytes, item.downloadedBytes)
                FileStore.shared.refresh()
            }
        } catch {
            DispatchQueue.main.async {
                item.state = .failed("Could not save file: \(error.localizedDescription)")
            }
        }

        lock.lock()
        tasks.removeValue(forKey: downloadTask.taskIdentifier)
        itemsByTask.removeValue(forKey: downloadTask.taskIdentifier)
        samples.removeValue(forKey: downloadTask.taskIdentifier)
        lock.unlock()
    }

    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        lock.lock()
        let item = itemsByTask[downloadTask.taskIdentifier]
        lock.unlock()
        guard let item = item else { return }

        let now = Date().timeIntervalSince1970
        lock.lock()
        let sample = samples[downloadTask.taskIdentifier]
        lock.unlock()

        DispatchQueue.main.async {
            item.downloadedBytes = totalBytesWritten
            if totalBytesExpectedToWrite > 0 {
                item.totalBytes = totalBytesExpectedToWrite
            }
            if let sample = sample {
                let dt = now - sample.time
                if dt >= 1.0 {
                    item.speedBytesPerSecond = Double(totalBytesWritten - sample.bytes) / dt
                    self.lock.lock()
                    self.samples[downloadTask.taskIdentifier] = (totalBytesWritten, now)
                    self.lock.unlock()
                }
            }
        }
    }

    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    didCompleteWithError error: Error?) {
        lock.lock()
        let item = itemsByTask[task.taskIdentifier]
        lock.unlock()
        guard let item = item else { return }

        if let nsError = error as NSError? {
            if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                return // canceled by the user; row already removed
            }
            DispatchQueue.main.async {
                item.state = .failed(nsError.localizedDescription)
                item.speedBytesPerSecond = 0
            }
        }

        lock.lock()
        tasks.removeValue(forKey: task.taskIdentifier)
        itemsByTask.removeValue(forKey: task.taskIdentifier)
        samples.removeValue(forKey: task.taskIdentifier)
        lock.unlock()
    }
}
