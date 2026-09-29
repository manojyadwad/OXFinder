import SwiftUI

/// Windows File Explorer Status Bar showing item counts, selection metrics, volume free space, and quick view toggles
public struct StatusBarView: View {
    @ObservedObject var appState: AppState

    public var body: some View {
        HStack(spacing: 16) {
            // Total Items Count
            Text("\(appState.currentItems.count) items")
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            // Selection Info
            if !appState.selectedURLs.isEmpty {
                Divider()
                    .frame(height: 12)

                Text(selectionString)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            // Storage Free Space Indicator
            if !appState.volumeFreeSpaceFormatted.isEmpty {
                Divider()
                    .frame(height: 12)

                HStack(spacing: 4) {
                    Image(systemName: "internaldrive")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Text(appState.volumeFreeSpaceFormatted)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // View Mode Quick Toggles
            HStack(spacing: 2) {
                Button(action: { appState.setViewMode(.details) }) {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.system(size: 11))
                        .foregroundColor(appState.activeTab.viewMode == .details ? .accentColor : .secondary)
                        .frame(width: 22, height: 18)
                        .background(appState.activeTab.viewMode == .details ? Color.accentColor.opacity(0.15) : Color.clear)
                        .cornerRadius(3)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Details view")

                Button(action: { appState.setViewMode(.largeIcons) }) {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 11))
                        .foregroundColor(appState.activeTab.viewMode == .largeIcons ? .accentColor : .secondary)
                        .frame(width: 22, height: 18)
                        .background(appState.activeTab.viewMode == .largeIcons ? Color.accentColor.opacity(0.15) : Color.clear)
                        .cornerRadius(3)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Large icons view")
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 24)
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(
            Divider(), alignment: .top
        )
    }

    private var selectionString: String {
        let count = appState.selectedURLs.count
        let selectedItems = appState.currentItems.filter { appState.selectedURLs.contains($0.url) }
        let totalBytes = selectedItems.reduce(Int64(0)) { $0 + $1.size }

        let byteFormatter = ByteCountFormatter()
        byteFormatter.countStyle = .file
        let sizeStr = byteFormatter.string(fromByteCount: totalBytes)

        if count == 1 {
            return "1 item selected  \(sizeStr)"
        } else {
            return "\(count) items selected  \(sizeStr)"
        }
    }
}
