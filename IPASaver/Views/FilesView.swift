import SwiftUI
import UniformTypeIdentifiers

struct FilesView: View {
    @EnvironmentObject private var fileStore: FileStore
    @State private var showImporter = false
    @State private var exportTarget: SavedFile?

    var body: some View {
        NavigationStack {
            Group {
                if fileStore.files.isEmpty {
                    emptyState
                } else {
                    fileList
                }
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("My Files")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showImporter = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Import IPA from Files app")
                }
            }
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [UTType.data],
                allowsMultipleSelection: true
            ) { result in
                if case .success(let urls) = result {
                    for url in urls {
                        _ = fileStore.importFile(at: url)
                    }
                }
            }
            .sheet(item: $exportTarget) { file in
                DocumentExporter(urls: [file.url])
                    .ignoresSafeArea()
            }
        }
    }

    private var fileList: some View {
        List {
            Section {
                ForEach(fileStore.files) { file in
                    FileRow(
                        file: file,
                        onDelete: { fileStore.delete(file) },
                        onExport: { exportTarget = file }
                    )
                    .listRowBackground(Theme.cardBackground)
                }
                .onDelete { indexSet in
                    for index in indexSet where index < fileStore.files.count {
                        fileStore.delete(fileStore.files[index])
                    }
                }
            } header: {
                Text("\(fileStore.files.count) file\(fileStore.files.count == 1 ? "" : "s") • \(Fmt.bytes(fileStore.totalUsedBytes())) total")
            } footer: {
                Text("Tip: tap the share icon to send an IPA straight to eSign, GBox, or any other signing tool.")
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("No IPA files yet")
                .font(.headline)
            Text("Download with a direct link from the Download tab, or import from the Files app with the + button.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
