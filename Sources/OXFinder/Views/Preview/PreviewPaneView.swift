import SwiftUI
import AppKit
import ImageIO

/// Collapsible Windows Explorer Preview Pane (Right Inspector) with detailed metadata
public struct PreviewPaneView: View {
    @ObservedObject var appState: AppState

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Preview")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                Spacer()
                Button(action: {
                    appState.togglePreviewPane()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(nsColor: .windowBackgroundColor))
            .overlay(Divider(), alignment: .bottom)

            if let item = appState.previewItem {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        // High-res preview media view with dynamic reloading
                        PreviewMediaInspectorView(item: item, appState: appState)
                            .id(item.url)
                            .padding(.horizontal, 12)
                            .padding(.top, 12)

                        // File title & Kind
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.displayName)
                                .font(.system(size: 14, weight: .semibold))
                                .lineLimit(2)

                            Text(item.fileTypeDescription)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 14)

                        Divider()
                            .padding(.horizontal, 14)

                        // Metadata Grid
                        VStack(alignment: .leading, spacing: 8) {
                            metadataRow(title: "Size", value: item.formattedSize.isEmpty ? "—" : item.formattedSize)

                            if item.dateModified != nil {
                                metadataRow(title: "Modified", value: item.formattedDateModified)
                            }

                            if let created = item.dateCreated {
                                metadataRow(title: "Created", value: formatDate(created))
                            }

                            if let meta = appState.previewMetadata {
                                if let dim = meta.dimensions {
                                    metadataRow(title: "Dimensions", value: "\(Int(dim.width)) × \(Int(dim.height)) px")
                                }
                                if let cs = meta.colorSpace {
                                    metadataRow(title: "Color Space", value: cs)
                                }
                                if let cam = meta.cameraModel {
                                    metadataRow(title: "Camera", value: cam)
                                }
                                if let lens = meta.lensModel {
                                    metadataRow(title: "Lens", value: lens)
                                }
                                if let f = meta.fNumber {
                                    metadataRow(title: "Aperture", value: String(format: "f/%.1f", f))
                                }
                                if let exp = meta.exposureTime {
                                    metadataRow(title: "Exposure", value: exp)
                                }
                                if let iso = meta.iso {
                                    metadataRow(title: "ISO", value: "\(iso)")
                                }
                                if let posix = meta.posixPermissions {
                                    metadataRow(title: "Permissions", value: posix)
                                }
                            }
                        }
                        .padding(.horizontal, 14)

                        // If image, open viewer shortcut
                        if item.isImage {
                            Button(action: {
                                appState.viewerItem = item
                            }) {
                                HStack {
                                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                                    Text("Open in Image Viewer")
                                }
                                .font(.system(size: 12))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                            }
                            .buttonStyle(BorderedProminentButtonStyle())
                            .padding(.horizontal, 14)
                            .padding(.top, 6)
                        }
                    }
                    .padding(.bottom, 16)
                }
            } else {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("Select a file to preview.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func metadataRow(title: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)

            Text(value)
                .font(.system(size: 11))
                .foregroundColor(.primary)
                .lineLimit(2)

            Spacer()
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

/// Dynamic, asynchronously reloading inspector preview supporting crisp image decoding and thumbnail fallback
struct PreviewMediaInspectorView: View {
    let item: FileItem
    @ObservedObject var appState: AppState
    @State private var previewImage: NSImage?
    @State private var isLoading: Bool = true

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor))
                .frame(height: 200)

            if let img = previewImage {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 184)
                    .cornerRadius(6)
                    .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
            } else if isLoading {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(nsImage: item.systemIcon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            if item.isImage {
                appState.viewerItem = item
            }
        }
        .task(id: item.url) {
            isLoading = true
            previewImage = nil

            let targetSize: CGFloat = item.isImage ? 600 : 220
            let thumb = await ThumbnailCacheService.shared.thumbnail(for: item, size: targetSize)
            if !Task.isCancelled {
                self.previewImage = thumb
                self.isLoading = false
            }
        }
    }
}
