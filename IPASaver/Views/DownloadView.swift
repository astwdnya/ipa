import SwiftUI
import UIKit

struct DownloadView: View {
    @EnvironmentObject private var manager: DownloadManager
    @State private var urlString = ""
    @State private var showInvalidAlert = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    urlCard
                    downloadsCard
                    noteCard
                }
                .padding(16)
            }
            .background(Theme.background)
            .navigationTitle("IPA Saver")
            .alert("Invalid link", isPresented: $showInvalidAlert) {
            } message: {
                Text("Please enter a valid download link (http/https).")
            }
        }
    }

    // MARK: - Sections

    private var urlCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add an IPA link")
                .font(.headline)
            Text("Paste a direct link to an .ipa file. The file is only downloaded — it is never installed.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                TextField("https://example.com/app.ipa", text: $urlString)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(Theme.background)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                Button {
                    if let text = UIPasteboard.general.string {
                        urlString = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                } label: {
                    Image(systemName: "doc.on.doc")
                        .frame(width: 44, height: 44)
                }
                .background(Theme.background)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityLabel("Paste from clipboard")
            }

            Button {
                guard DownloadManager.normalize(urlString: urlString) != nil else {
                    showInvalidAlert = true
                    return
                }
                manager.start(urlString: urlString)
                urlString = ""
            } label: {
                Label("Start download", systemImage: "arrow.down.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
        }
        .cardStyle()
    }

    @ViewBuilder
    private var downloadsCard: some View {
        if manager.items.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: "tray.and.arrow.down.fill")
                    .font(.system(size: 38))
                    .foregroundStyle(.tertiary)
                Text("No active downloads")
                    .font(.subheadline.weight(.medium))
                Text("Paste an IPA link above to get started.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 26)
            .cardStyle()
        } else {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Downloads")
                        .font(.headline)
                    Spacer()
                    if manager.items.contains(where: { $0.state.isTerminal }) {
                        Button("Clear finished") { manager.clearTerminalItems() }
                            .font(.footnote)
                    }
                }
                ForEach(manager.items) { item in
                    ActiveDownloadRow(
                        item: item,
                        onPauseResume: { manager.togglePause(item) },
                        onDismiss: { manager.cancel(item) }
                    )
                }
            }
            .cardStyle()
        }
    }

    private var noteCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Good to know", systemImage: "info.circle.fill")
                .font(.headline)
            bullet("Files are saved in this app's folder — visible in the Files app under “On My iPhone → IPA Saver”.")
            bullet("Use the Share button in “My Files” to send an IPA straight to eSign, GBox, or any signing tool.")
            bullet("App Store apps cannot be downloaded as .ipa files (Apple encrypts them). This app works with direct .ipa links.")
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
}
