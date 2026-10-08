import SwiftUI

struct FileRow: View {
    let file: SavedFile
    var onDelete: () -> Void
    var onExport: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Theme.accent.opacity(0.12))
                    .frame(width: 42, height: 42)
                Image(systemName: "shippingbox.fill")
                    .foregroundStyle(Theme.accent)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(file.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                Text("\(Fmt.bytes(file.size)) • \(Fmt.date(file.date))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            HStack(spacing: 2) {
                ShareLink(item: file.url) {
                    Image(systemName: "square.and.arrow.up")
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Share IPA")

                Menu {
                    Button(action: onExport) {
                        Label("Save to Files…", systemImage: "folder")
                    }
                    Divider()
                    Button(role: .destructive, action: onDelete) {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.borderless)
            }
            .foregroundStyle(Theme.accent)
        }
    }
}
