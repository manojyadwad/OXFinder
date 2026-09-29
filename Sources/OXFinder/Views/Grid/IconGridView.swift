import SwiftUI
import AppKit

/// Multi-size icon and list view grid matching Windows File Explorer with blank canvas and file context menus
public struct IconGridView: View {
    @ObservedObject var appState: AppState
    let viewMode: ViewMode
    @State private var renamingURL: URL? = nil
    @State private var renameText: String = ""
    @State private var lastClickTime: Date = .distantPast
    @State private var lastClickedURL: URL? = nil

    public var body: some View {
        ScrollView {
            if viewMode == .list {
                listViewContent
            } else {
                gridViewContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            Color(nsColor: .controlBackgroundColor)
                .contentShape(Rectangle())
                .onTapGesture {
                    // Clicking empty canvas deselects
                    appState.selectedURLs.removeAll()
                    appState.updatePreviewSelection()
                }
        )
        // Right-click context menu on blank canvas area
        .contextMenu {
            EmptyCanvasContextMenuView(appState: appState)
        }
    }

    // MARK: - Grid View (Small, Medium, Large, Extra Large)

    private var gridViewContent: some View {
        let columns = [
            GridItem(.adaptive(minimum: viewMode.gridCellWidth, maximum: viewMode.gridCellWidth * 1.5), spacing: 12)
        ]

        return LazyVGrid(columns: columns, spacing: 14) {
            ForEach(appState.currentItems) { item in
                iconCell(for: item)
            }
        }
        .padding(14)
    }

    private func iconCell(for item: FileItem) -> some View {
        let isSelected = appState.selectedURLs.contains(item.url)
        let isCut = appState.clipboard.isCut && appState.clipboard.urls.contains(item.url)
        let isRenaming = renamingURL == item.url

        return VStack(spacing: 6) {
            FileThumbnailView(item: item, size: viewMode.iconSize)
                .frame(width: viewMode.iconSize, height: viewMode.iconSize)
                .opacity(isCut ? 0.45 : 1.0)

            if isRenaming {
                TextField("Name", text: $renameText, onCommit: {
                    commitRename(for: item)
                })
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .font(.system(size: 11))
                .multilineTextAlignment(.center)
                .frame(maxWidth: viewMode.gridCellWidth - 10)
            } else {
                Text(item.displayName)
                    .font(.system(size: 12))
                    .foregroundColor(isSelected ? .white : .primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(
                        isSelected ?
                        RoundedRectangle(cornerRadius: 4).fill(Color.accentColor) :
                        RoundedRectangle(cornerRadius: 4).fill(Color.clear)
                    )
            }
        }
        .frame(width: viewMode.gridCellWidth, height: viewMode.gridCellHeight)
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1)
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            let shiftPressed = NSEvent.modifierFlags.contains(.shift)
            let cmdPressed = NSEvent.modifierFlags.contains(.command)
            handleItemClick(item, extendSelection: shiftPressed || cmdPressed)
        }
        // Right-click context menu with "Open with"
        .contextMenu {
            FileContextMenuView(item: item, appState: appState)
        }
        .onDrag {
            NSItemProvider(object: item.url as NSURL)
        }
    }

    // MARK: - List View

    private var listViewContent: some View {
        let columns = [
            GridItem(.adaptive(minimum: 220, maximum: 300), spacing: 8)
        ]

        return LazyVGrid(columns: columns, spacing: 4) {
            ForEach(appState.currentItems) { item in
                let isSelected = appState.selectedURLs.contains(item.url)
                let isCut = appState.clipboard.isCut && appState.clipboard.urls.contains(item.url)

                HStack(spacing: 8) {
                    FileThumbnailView(item: item, size: 20)
                        .opacity(isCut ? 0.45 : 1.0)

                    Text(item.displayName)
                        .font(.system(size: 12))
                        .lineLimit(1)
                        .foregroundColor(isSelected ? .white : .primary)

                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isSelected ? Color.accentColor : Color.clear)
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    let cmdOrShift = NSEvent.modifierFlags.contains(.shift) || NSEvent.modifierFlags.contains(.command)
                    handleItemClick(item, extendSelection: cmdOrShift)
                }
                // Right-click context menu with "Open with"
                .contextMenu {
                    FileContextMenuView(item: item, appState: appState)
                }
            }
        }
        .padding(10)
    }

    private func handleItemClick(_ item: FileItem, extendSelection: Bool) {
        let isSystemDoubleClick = (NSApp.currentEvent?.clickCount ?? 1) >= 2
        let now = Date()
        let isTimeDoubleClick = (lastClickedURL == item.url) && (now.timeIntervalSince(lastClickTime) < 0.45)
        lastClickTime = now
        lastClickedURL = item.url

        appState.selectItem(item, extendSelection: extendSelection)

        if isSystemDoubleClick || isTimeDoubleClick {
            lastClickTime = .distantPast
            lastClickedURL = nil
            appState.openItem(item)
        }
    }

    private func commitRename(for item: FileItem) {
        guard let url = renamingURL, !renameText.isEmpty, renameText != item.name else {
            renamingURL = nil
            return
        }
        appState.renameItem(url: url, newName: renameText)
        renamingURL = nil
    }
}
