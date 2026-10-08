import SwiftUI
import StoreAPI

struct AppStoreView: View {
    @EnvironmentObject private var fileStore: FileStore
    @ObservedObject private var service = AppStoreService.shared

    @State private var searchText = ""
    @State private var storefrontCode = "US"
    @State private var results: [AppHit] = []
    @State private var statusMessage: String?
    @State private var statusIsError = false
    @State private var downloadingAppID: Int?
    @State private var showLogin = false
    @State private var showStorefrontPicker = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    accountCard
                    searchCard
                    if service.isBusy {
                        progressCard
                    }
                    if let message = statusMessage {
                        statusCard(message)
                    }
                    resultsSection
                    noteCard
                }
                .padding(16)
            }
            .background(Theme.background)
            .navigationTitle("App Store")
            .sheet(isPresented: $showLogin) {
                LoginSheet()
            }
            .sheet(isPresented: $showStorefrontPicker) {
                StorefrontPicker(selection: $storefrontCode)
            }
        }
    }

    // MARK: - Sections

    private var accountCard: some View {
        Group {
            if let account = service.account {
                HStack(spacing: 12) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(Theme.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(account.name.isEmpty ? account.email : account.name)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                        Text(account.email)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    Button("Sign out", role: .destructive) {
                        service.signOut()
                        statusMessage = nil
                    }
                    .font(.footnote.weight(.semibold))
                }
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Sign in required", systemImage: "lock.circle.fill")
                        .font(.headline)
                    Text("Sign in with your Apple ID to download apps from the App Store. Use a secondary Apple ID for safety.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Button {
                        showLogin = true
                    } label: {
                        Label("Sign in with Apple ID", systemImage: "person.crop.circle")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .cardStyle()
    }

    private var searchCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Find an app")
                .font(.headline)
            Text("Search by name, bundle ID, or paste an App Store link.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                TextField("App name, bundle ID, or link", text: $searchText)
                    .textFieldStyle(.plain)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(12)
                    .background(Theme.background)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                Button {
                    findApps()
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.body.weight(.semibold))
                        .frame(width: 44, height: 44)
                }
                .background(Theme.accent)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .disabled(service.isBusy)
            }

            Button {
                showStorefrontPicker = true
            } label: {
                HStack(spacing: 6) {
                    Text("Storefront:")
                        .foregroundStyle(.secondary)
                    Text("\(flagEmoji(for: storefrontCode)) \(storefrontCode.uppercased())")
                        .font(.subheadline.weight(.semibold))
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .font(.footnote)
            }
        }
        .cardStyle()
    }

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                ProgressView()
                Text(service.busyStage.isEmpty ? "Working…" : service.busyStage)
                    .font(.subheadline)
            }
            if downloadingAppID != nil && service.downloadProgress > 0 {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.accent.opacity(0.15))
                        Capsule()
                            .fill(Theme.accent)
                            .frame(width: max(4, geo.size.width * service.downloadProgress))
                    }
                }
                .frame(height: 6)
                Text("\(Int((service.downloadProgress * 100).rounded()))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private func statusCard(_ message: String) -> some View {
        Label(message, systemImage: statusIsError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
            .font(.footnote.weight(.medium))
            .foregroundStyle(statusIsError ? Theme.danger : Theme.success)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle()
    }

    @ViewBuilder
    private var resultsSection: some View {
        if !results.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("\(results.count) result\(results.count == 1 ? "" : "s")")
                    .font(.headline)
                ForEach(results) { hit in
                    AppHitRow(
                        hit: hit,
                        isBusy: service.isBusy,
                        isDownloading: downloadingAppID == hit.id,
                        progress: service.downloadProgress,
                        onDownload: { download(hit) }
                    )
                    if hit.id != results.last?.id {
                        Divider()
                    }
                }
            }
            .cardStyle()
        }
    }

    private var noteCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("How it works", systemImage: "info.circle.fill")
                .font(.headline)
            bullet("The downloaded .ipa is FairPlay-encrypted with your Apple ID — the same result as ipatool and DLiPA.")
            bullet("Free apps get a license automatically. Paid apps cannot be downloaded.")
            bullet("Files are saved in “My Files”. To sideload, decrypt the IPA (e.g. with GBox) first, then sign it with eSign/GBox.")
            bullet("Use a secondary Apple ID — automated App Store access is not endorsed by Apple.")
        }
        .cardStyle()
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(Theme.accent)
                .frame(width: 6, height: 6)
                .padding(.top, 6)
            Text(text)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Actions

    private func findApps() {
        statusMessage = nil
        results = []
        service.findApps(input: searchText, countryCode: storefrontCode.lowercased()) { result in
            switch result {
            case let .success(hits):
                results = hits
            case let .failure(error):
                statusIsError = true
                statusMessage = error.localizedDescription
            }
        }
    }

    private func download(_ hit: AppHit) {
        guard service.account != nil else {
            statusIsError = true
            statusMessage = AppStoreServiceError.notSignedIn.localizedDescription
            showLogin = true
            return
        }
        statusMessage = nil
        downloadingAppID = hit.id
        service.download(app: hit, countryCode: storefrontCode.lowercased()) { result in
            downloadingAppID = nil
            switch result {
            case .success:
                statusIsError = false
                statusMessage = "Saved to My Files ✓"
                fileStore.refresh()
            case let .failure(error):
                statusIsError = true
                statusMessage = error.localizedDescription
            }
        }
    }

    private func flagEmoji(for code: String) -> String {
        let upper = code.uppercased()
        guard upper.count == 2 else { return "🌍" }
        let scalars = upper.unicodeScalars.compactMap { Unicode.Scalar(127397 + Int($0.value)) }
        return String(String.UnicodeScalarView(scalars))
    }
}

// MARK: - Result row

struct AppHitRow: View {
    let hit: AppHit
    var isBusy: Bool
    var isDownloading: Bool
    var progress: Double
    var onDownload: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                appIcon
                VStack(alignment: .leading, spacing: 2) {
                    Text(hit.name)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2)
                    Text("\(hit.artist) • v\(hit.version)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text(hit.bundleId)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                trailingButton
            }

            if isDownloading {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.accent.opacity(0.15))
                        Capsule()
                            .fill(Theme.accent)
                            .frame(width: max(4, geo.size.width * progress))
                    }
                }
                .frame(height: 6)
            }
        }
    }

    private var appIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Theme.accent.opacity(0.12))
                .frame(width: 46, height: 46)
            if let url = hit.artworkURL {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        Image(systemName: "app.fill")
                            .foregroundStyle(Theme.accent)
                    }
                }
                .frame(width: 46, height: 46)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else {
                Image(systemName: "app.fill")
                    .foregroundStyle(Theme.accent)
            }
        }
    }

    @ViewBuilder
    private var trailingButton: some View {
        if hit.isFree {
            Button(action: onDownload) {
                if isDownloading {
                    Text("…")
                        .font(.subheadline.weight(.bold))
                } else {
                    Label("Get", systemImage: "icloud.and.arrow.down")
                        .font(.subheadline.weight(.bold))
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isBusy)
        } else {
            Label("Paid", systemImage: "lock.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Login sheet

struct LoginSheet: View {
    @ObservedObject private var service = AppStoreService.shared
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var password = ""
    @State private var code = ""
    @State private var needsCode = false
    @State private var errorMessage: String?
    @State private var isSigningIn = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Apple ID email", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("Password", text: $password)
                } header: {
                    Text("Apple ID")
                } footer: {
                    Text("Stored only in this device's Keychain. Use a secondary Apple ID — automated access is not endorsed by Apple.")
                }

                if needsCode {
                    Section {
                        TextField("6-digit verification code", text: $code)
                            .keyboardType(.numberPad)
                    } header: {
                        Text("Two-Factor Authentication")
                    } footer: {
                        Text("Check your trusted device for the verification code, then sign in again.")
                    }
                }

                Section {
                    Button {
                        signIn()
                    } label: {
                        if isSigningIn {
                            HStack {
                                ProgressView()
                                Text("Signing in…")
                            }
                        } else {
                            Text("Sign in")
                                .frame(maxWidth: .infinity)
                                .font(.headline)
                        }
                    }
                    .disabled(isSigningIn || email.isEmpty || password.isEmpty || (needsCode && code.isEmpty))
                }

                if let errorMessage = errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(Theme.danger)
                    }
                }
            }
            .navigationTitle("Sign in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func signIn() {
        errorMessage = nil
        isSigningIn = true
        service.signIn(email: email.trimmingCharacters(in: .whitespaces),
                       password: password,
                       code: needsCode ? code : nil) { result in
            isSigningIn = false
            switch result {
            case .success:
                dismiss()
            case let .failure(error):
                if case .codeRequired = error {
                    needsCode = true
                }
                errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Storefront picker

struct StorefrontPicker: View {
    @Binding var selection: String
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var items: [Storefront] {
        let all = Storefront.allCases.sorted { "\($0)" < "\($1)" }
        guard !query.isEmpty else { return all }
        return all.filter { "\($0)".localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        NavigationStack {
            List(items, id: \.self) { storefront in
                let code = "\(storefront)"
                Button {
                    selection = code
                    dismiss()
                } label: {
                    HStack {
                        Text(flagEmoji(for: code))
                        Text(code)
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        if code == selection {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Theme.accent)
                        }
                    }
                }
                .foregroundStyle(.primary)
            }
            .searchable(text: $query, prompt: "Country code")
            .navigationTitle("Storefront")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func flagEmoji(for code: String) -> String {
        let upper = code.uppercased()
        guard upper.count == 2 else { return "🌍" }
        let scalars = upper.unicodeScalars.compactMap { Unicode.Scalar(127397 + Int($0.value)) }
        return String(String.UnicodeScalarView(scalars))
    }
}
