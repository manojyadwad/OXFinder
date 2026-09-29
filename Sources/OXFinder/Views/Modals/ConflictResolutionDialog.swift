import SwiftUI

/// Windows File Explorer style file conflict resolution dialog
public struct ConflictResolutionDialog: View {
    let sourceURL: URL
    let targetURL: URL
    let onDecision: (ConflictResolution) -> Void

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.yellow)

                VStack(alignment: .leading, spacing: 4) {
                    Text("The destination already has a file named \"\(targetURL.lastPathComponent)\"")
                        .font(.headline)
                    Text("Which file do you want to keep?")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            // Comparison Rows
            VStack(spacing: 8) {
                fileInfoCard(title: "Existing destination file", url: targetURL)
                fileInfoCard(title: "Source file to copy/move", url: sourceURL)
            }

            Divider()

            // Action Buttons
            HStack(spacing: 10) {
                Button("Skip") {
                    onDecision(.skip)
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Keep Both (Auto-rename)") {
                    onDecision(.keepBoth)
                }

                Button("Replace") {
                    onDecision(.replace)
                }
                .buttonStyle(BorderedProminentButtonStyle())
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 480)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func fileInfoCard(title: String, url: URL) -> some View {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        let size = Int64(values?.fileSize ?? 0)
        let date = values?.contentModificationDate

        let byteFormatter = ByteCountFormatter()
        byteFormatter.countStyle = .file
        let sizeStr = byteFormatter.string(fromByteCount: size)

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        let dateStr = date != nil ? dateFormatter.string(from: date!) : "Unknown date"

        return HStack(spacing: 10) {
            Image(systemName: "doc.fill")
                .font(.system(size: 20))
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)

                Text(url.lastPathComponent)
                    .font(.system(size: 12, weight: .medium))

                Text("\(sizeStr) • Modified \(dateStr)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }
}
