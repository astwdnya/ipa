import SwiftUI

struct ActiveDownloadRow: View {
    @ObservedObject var item: DownloadItem
    var onPauseResume: () -> Void
    var onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                thumbnail
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.fileName)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    statusText
                }
                Spacer(minLength: 4)
                controls
            }

            if !item.state.isTerminal && item.totalBytes > 0 {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Theme.accent.opacity(0.15))
                        Capsule()
                            .fill(Theme.accent)
                            .frame(width: max(4, geo.size.width * item.progress))
                    }
                }
                .frame(height: 6)
            }
        }
    }

    private var thumbnail: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Theme.accent.opacity(0.12))
                .frame(width: 40, height: 40)
            Image(systemName: "shippingbox.fill")
                .foregroundStyle(Theme.accent)
        }
    }

    @ViewBuilder
    private var statusText: some View {
        switch item.state {
        case .waiting:
            Text("Waiting…")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .downloading:
            Text("\(Fmt.bytes(item.downloadedBytes)) of \(Fmt.bytes(item.totalBytes)) • \(Fmt.speed(item.speedBytesPerSecond))")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .paused:
            Text("Paused at \(Fmt.bytes(item.downloadedBytes))")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .finished:
            Text("Saved to My Files ✓")
                .font(.caption.weight(.medium))
                .foregroundStyle(Theme.success)
        case .failed(let message):
            Text(message)
                .font(.caption)
                .foregroundStyle(Theme.danger)
                .lineLimit(2)
        }
    }

    @ViewBuilder
    private var controls: some View {
        if !item.state.isTerminal {
            Button(action: onPauseResume) {
                Image(systemName: item.state == .paused ? "play.fill" : "pause.fill")
                    .font(.body)
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.borderless)

            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.borderless)
        } else {
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.borderless)
        }
    }
}
