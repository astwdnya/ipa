import Foundation
import Networking
import StoreAPI
import Persistence

/// A signed-in Apple ID session.
struct AppStoreAccount: Codable {
    let name: String
    let email: String
    let passwordToken: String
    let directoryServicesIdentifier: String
}

/// A single App Store search/lookup result.
struct AppHit: Identifiable {
    let id: Int
    let name: String
    let bundleId: String
    let version: String
    let price: Double
    let artist: String
    let artworkURL: URL?

    var isFree: Bool { price == 0 }
}

/// Friendly, UI-ready errors.
enum AppStoreServiceError: Error, LocalizedError {
    case notSignedIn
    case invalidInput
    case appNotFound
    case codeRequired
    case invalidCredentials
    case lockedAccount
    case accountNotSetup
    case passwordTokenExpired
    case paidApp
    case licenseFailed
    case countryMismatch
    case appleProtocolChanged
    case network(String)
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .notSignedIn:
            return "Please sign in with your Apple ID first."
        case .invalidInput:
            return "Enter an app name, bundle ID, or App Store link."
        case .appNotFound:
            return "Could not find this app in the selected storefront."
        case .codeRequired:
            return "Two-factor authentication is required. Enter the 6-digit verification code shown on your trusted device."
        case .invalidCredentials:
            return "Invalid Apple ID email or password."
        case .lockedAccount:
            return "This Apple ID has been locked for security reasons."
        case .accountNotSetup:
            return "This Apple ID has not been set up to use the App Store."
        case .passwordTokenExpired:
            return "Your session expired. Please sign in again."
        case .paidApp:
            return "Only free apps can be downloaded — this app is paid."
        case .licenseFailed:
            return "Could not obtain a license for this app."
        case .countryMismatch:
            return "The selected storefront does not match the Apple ID region."
        case .appleProtocolChanged:
            return "Apple now requires SAP-signed requests for App Store sign-in (server change, August 2026). Third-party IPA downloaders — including this app and Asspp — are affected. Workaround: run the \"Fetch IPA\" GitHub Actions workflow in this repository, or ipatool v2.6+ on a computer. See README for details."
        case .network(let message):
            return "Network error: \(message)"
        case .unknown(let message):
            return message
        }
    }

    static func map(_ error: Error) -> AppStoreServiceError {
        switch error {
        case let e as StoreResponse.Error:
            switch e {
            case .codeRequired: return .codeRequired
            case .invalidCredentials: return .invalidCredentials
            case .lockedAccount: return .lockedAccount
            case .invalidAccount: return .accountNotSetup
            case .passwordTokenExpired, .passwordChanged: return .passwordTokenExpired
            case .invalidCountry: return .countryMismatch
            case .invalidLicense: return .licenseFailed
            case .priceMismatch: return .paidApp
            default: return .unknown("App Store error \(e.rawValue).")
            }
        case let e as StoreClient.Error:
            switch e {
            case .purchaseFailed, .duplicateLicense: return .licenseFailed
            case .invalidResponse: return .unknown("Received an invalid response from Apple.")
            case .timeout: return .network("The request timed out.")
            }
        case let e as NSError where e.domain == NSURLErrorDomain:
            return .network(e.localizedDescription)
        case is DecodingError:
            // Apple returned something we could not decode — since Aug 2026 this is
            // typically the SAP challenge / an HTML page instead of the legacy plist.
            return .appleProtocolChanged
        case let e as NSError where e.domain == NSCocoaErrorDomain && (e.code == 3840 || e.code == 3851):
            return .appleProtocolChanged
        default:
            if error.localizedDescription.contains("isn't in the correct format") ||
                error.localizedDescription.contains("is not in the correct format") {
                return .appleProtocolChanged
            }
            return .unknown(error.localizedDescription)
        }
    }
}

/// DLiPA-style App Store downloader built on the vendored ipatool core.
final class AppStoreService: ObservableObject {
    static let shared = AppStoreService()

    @Published var account: AppStoreAccount?
    @Published var isBusy = false
    @Published var busyStage = ""
    @Published var downloadProgress: Double = 0

    private let keychain = KeychainStore(service: "com.ipasaver.app")

    private init() {
        let stored: AppStoreAccount? = (try? keychain.value(forKey: "account")) ?? nil
        self.account = stored
    }

    // MARK: - Sign in / out

    func signIn(email: String, password: String, code: String?,
                completion: @escaping (Result<Void, AppStoreServiceError>) -> Void) {
        setBusy(true, stage: "Signing in…")
        DispatchQueue.global(qos: .userInitiated).async {
            let result = self.signInSync(email: email, password: password, code: code)
            DispatchQueue.main.async {
                self.isBusy = false
                completion(result)
            }
        }
    }

    private func signInSync(email: String, password: String, code: String?) -> Result<Void, AppStoreServiceError> {
        let httpClient = HTTPClient(session: URLSession.shared)
        let storeClient = StoreClient(httpClient: httpClient)
        do {
            let account = try storeClient.authenticate(email: email, password: password, code: code)
            let mapped = AppStoreAccount(
                name: "\(account.firstName) \(account.lastName)".trimmingCharacters(in: .whitespaces),
                email: email,
                passwordToken: account.passwordToken,
                directoryServicesIdentifier: account.directoryServicesIdentifier
            )
            try keychain.setValue(mapped, forKey: "account")
            DispatchQueue.main.async { self.account = mapped }
            return .success(())
        } catch {
            return .failure(AppStoreServiceError.map(error))
        }
    }

    func signOut() {
        try? keychain.remove("account")
        account = nil
    }

    // MARK: - Search / lookup

    /// Parses "id123456789" out of raw digits or an App Store URL.
    static func trackIdentifier(from raw: String) -> Int? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, trimmed.allSatisfy({ $0.isNumber }), let id = Int(trimmed) {
            return id
        }
        if let range = trimmed.range(of: "id[0-9]+", options: .regularExpression),
           let id = Int(trimmed[range].dropFirst()) {
            return id
        }
        return nil
    }

    func findApps(input: String, countryCode: String,
                  completion: @escaping (Result<[AppHit], AppStoreServiceError>) -> Void) {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            completion(.failure(.invalidInput))
            return
        }
        setBusy(true, stage: "Searching the App Store…")
        DispatchQueue.global(qos: .userInitiated).async {
            let result = self.findAppsSync(input: trimmed, countryCode: countryCode)
            DispatchQueue.main.async {
                self.isBusy = false
                completion(result)
            }
        }
    }

    private func findAppsSync(input: String, countryCode: String) -> Result<[AppHit], AppStoreServiceError> {
        let request: ITunesSearchRequest
        if let trackID = AppStoreService.trackIdentifier(from: input) {
            request = ITunesSearchRequest(mode: .trackID(trackID), countryCode: countryCode)
        } else if input.contains(".") {
            request = ITunesSearchRequest(mode: .bundleID(input), countryCode: countryCode)
        } else {
            request = ITunesSearchRequest(mode: .term(input, limit: 25), countryCode: countryCode)
        }

        let httpClient = HTTPClient(session: URLSession.shared)
        do {
            let response = try httpClient.send(request)
            let decoded = try response.decode(ITunesSearchResponse.self, as: .json)
            let hits = decoded.results.map { entry in
                AppHit(
                    id: entry.trackId,
                    name: entry.trackName,
                    bundleId: entry.bundleId,
                    version: entry.version ?? "?",
                    price: entry.price ?? 0,
                    artist: entry.artistName ?? "",
                    artworkURL: entry.artworkUrl100.flatMap(URL.init(string:))
                )
            }
            if hits.isEmpty {
                return .failure(.appNotFound)
            }
            return .success(hits)
        } catch {
            return .failure(AppStoreServiceError.map(error))
        }
    }

    // MARK: - Download

    func download(app: AppHit, countryCode: String,
                  completion: @escaping (Result<Void, AppStoreServiceError>) -> Void) {
        guard let account = account else {
            completion(.failure(.notSignedIn))
            return
        }
        setBusy(true, stage: "Preparing…")
        downloadProgress = 0
        DispatchQueue.global(qos: .userInitiated).async {
            let result = self.downloadSync(app: app, account: account, countryCode: countryCode)
            DispatchQueue.main.async {
                self.isBusy = false
                self.busyStage = ""
                completion(result)
            }
        }
    }

    private func downloadSync(app: AppHit, account: AppStoreAccount,
                              countryCode: String) -> Result<Void, AppStoreServiceError> {
        let httpClient = HTTPClient(session: URLSession.shared)
        let storeClient = StoreClient(httpClient: httpClient)

        setStage("Requesting a signed copy…")
        let item: StoreResponse.Item
        do {
            item = try signedItem(storeClient: storeClient, app: app,
                                  account: account, countryCode: countryCode)
        } catch {
            return .failure(AppStoreServiceError.map(error))
        }

        setStage("Downloading package…")
        let temporaryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("IPASaver-\(UUID().uuidString).ipa")
        let downloadClient = HTTPDownloadClient()
        do {
            try downloadClient.download(from: item.url, to: temporaryURL) { fraction in
                DispatchQueue.main.async { self.downloadProgress = Double(fraction) }
            }
        } catch {
            try? FileManager.default.removeItem(at: temporaryURL)
            return .failure(AppStoreServiceError.map(error))
        }

        setStage("Applying FairPlay patches…")
        let signatureClient = SignatureClient(fileManager: .default, filePath: temporaryURL.path)
        do {
            try signatureClient.appendMetadata(item: item, email: account.email)
            try signatureClient.appendSignature(item: item)
        } catch {
            // Old code-signature version: fall back to the legacy mechanism.
            do {
                try signatureClient.appendOldSignature(item: item)
            } catch {
                try? FileManager.default.removeItem(at: temporaryURL)
                return .failure(.unknown("Failed to patch the app package."))
            }
        }

        setStage("Saving…")
        let fileName = "\(app.bundleId)_\(app.id)_v\(app.version).ipa"
        let destination = FileStore.shared.uniqueDestination(for: fileName)
        do {
            try FileManager.default.moveItem(at: temporaryURL, to: destination)
        } catch {
            try? FileManager.default.removeItem(at: temporaryURL)
            return .failure(.unknown("Could not save the file: \(error.localizedDescription)"))
        }
        FileStore.shared.refresh()
        return .success(())
    }

    private func signedItem(storeClient: StoreClient, app: AppHit,
                            account: AppStoreAccount,
                            countryCode: String) throws -> StoreResponse.Item {
        do {
            return try storeClient.item(
                identifier: "\(app.id)",
                directoryServicesIdentifier: account.directoryServicesIdentifier
            )
        } catch {
            // Missing license: obtain one automatically for free apps (like ipatool --purchase).
            guard let storeError = error as? StoreResponse.Error,
                  storeError == .invalidLicense else {
                throw error
            }
            guard app.isFree else {
                throw AppStoreServiceError.paidApp
            }
            setStage("Obtaining a license…")
            do {
                try storeClient.purchase(
                    identifier: "\(app.id)",
                    directoryServicesIdentifier: account.directoryServicesIdentifier,
                    passwordToken: account.passwordToken,
                    countryCode: countryCode.uppercased()
                )
            } catch let purchaseError as StoreClient.Error {
                if case .duplicateLicense = purchaseError {
                    // A license already exists — continue.
                } else {
                    throw purchaseError
                }
            }
            setStage("Requesting a signed copy…")
            return try storeClient.item(
                identifier: "\(app.id)",
                directoryServicesIdentifier: account.directoryServicesIdentifier
            )
        }
    }

    // MARK: - Helpers

    private func setBusy(_ busy: Bool, stage: String) {
        DispatchQueue.main.async {
            self.isBusy = busy
            self.busyStage = stage
        }
    }

    private func setStage(_ stage: String) {
        DispatchQueue.main.async { self.busyStage = stage }
    }
}

// MARK: - Rich iTunes search response (public API)

struct ITunesSearchResponse: Decodable {
    let resultCount: Int
    let results: [ITunesAppEntry]
}

struct ITunesAppEntry: Decodable {
    let trackId: Int
    let trackName: String
    let bundleId: String
    let version: String?
    let price: Double?
    let artistName: String?
    let artworkUrl100: String?
}

// MARK: - iTunes request built on the vendored Networking layer

struct ITunesSearchRequest: HTTPRequest {
    enum Mode {
        case term(String, limit: Int)
        case trackID(Int)
        case bundleID(String)
    }

    let mode: Mode
    let countryCode: String

    var method: HTTPMethod { .get }

    var endpoint: HTTPEndpoint {
        let path: String
        switch mode {
        case .term:
            path = "/search"
        case .trackID, .bundleID:
            path = "/lookup"
        }
        return SimpleEndpoint(url: URL(string: "https://itunes.apple.com" + path)!)
    }

    var payload: HTTPPayload? {
        switch mode {
        case let .term(term, limit):
            return .urlEncoding([
                "media": "software",
                "entity": "software",
                "term": term,
                "limit": "\(limit)",
                "country": countryCode
            ])
        case let .trackID(id):
            return .urlEncoding([
                "id": "\(id)",
                "country": countryCode
            ])
        case let .bundleID(bundle):
            return .urlEncoding([
                "bundleId": bundle,
                "entity": "software",
                "country": countryCode
            ])
        }
    }

    private final class SimpleEndpoint: HTTPEndpoint {
        let url: URL
        init(url: URL) { self.url = url }
    }
}
