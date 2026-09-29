import SwiftUI
import AppKit

/// Windows File Explorer Details Table View with instant first-click selection, rapid second-click open,
/// rich right-click file menu with "Open with" app resolution, and blank canvas right-click context menu.
public struct DetailsTableView: View {
    @ObservedObject var appState: AppState
    @State private var sortOrder: [KeyPathComparator<FileItem>] = [
        .init(\.name, order: .forward)
    ]
    @State private var lastClickTime: Date = .distantPast
    @State private var lastClickedURL: URL? = nil

    public var body: some View {
        ZStack {
            // Background canvas accepting right-clicks on blank whitespace
            Color(nsColor: .controlBackgroundColor)
                .contentShape(Rectangle())
                .contextMenu {
                    EmptyCanvasContextMenuView(appState: appState)
                }

            Table(appState.currentItems, selection: Binding(
                get: { appState.selectedURLs },
                set: { newSelection in
                    appState.selectedURLs = newSelection
                    appState.updatePreviewSelection()
                }
            ), sortOrder: $sortOrder) {
                TableColumn("Name", value: \.name) { item in
                    let isCut = appState.clipboard.isCut && appState.clipboard.urls.contains(item.url)

                    HStack(spacing: 8) {
                        Image(nsImage: item.systemIcon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 18, height: 18)
                            .opacity(isCut ? 0.45 : 1.0)

                        Text(item.displayName)
                            .font(.system(size: 12))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        handleRowClick(for: item)
                    }
                }
                .width(min: 180, ideal: 260)

                TableColumn("Date modified", value: \.dateModifiedComparable) { item in
                    Text(item.formattedDateModified)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            handleRowClick(for: item)
                        }
                }
                .width(min: 120, ideal: 150)

                TableColumn("Type", value: \.fileTypeDescription) { item in
                    Text(item.fileTypeDescription)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            handleRowClick(for: item)
                        }
                }
                .width(min: 100, ideal: 140)

                TableColumn("Size", value: \.sizeComparable) { item in
                    Text(item.formattedSize)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.trailing)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            handleRowClick(for: item)
                        }
                }
                .width(min: 70, ideal: 90)
            }
            .onChange(of: sortOrder) { newOrder in
                handleSortChange(newOrder)
            }
            .contextMenu(forSelectionType: URL.self) { selectedURLs in
                if let firstURL = selectedURLs.first,
                   let item = appState.currentItems.first(where: { $0.url == firstURL }) {
                    FileContextMenuView(item: item, appState: appState)
                } else {
                    EmptyCanvasContextMenuView(appState: appState)
                }
            }
        }
    }

    private func handleRowClick(for item: FileItem) {
        let isSystemDoubleClick = (NSApp.currentEvent?.clickCount ?? 1) >= 2
        let now = Date()
        let isTimeDoubleClick = (lastClickedURL == item.url) && (now.timeIntervalSince(lastClickTime) < 0.45)
        lastClickTime = now
        lastClickedURL = item.url

        let shiftOrCmd = NSEvent.modifierFlags.contains(.shift) || NSEvent.modifierFlags.contains(.command)
        appState.selectItem(item, extendSelection: shiftOrCmd)

        if isSystemDoubleClick || isTimeDoubleClick {
            lastClickTime = .distantPast
            lastClickedURL = nil
            appState.openItem(item)
        }
    }

    private func handleSortChange(_ newOrder: [KeyPathComparator<FileItem>]) {
        guard let primary = newOrder.first else { return }
        let isAscending = primary.order == .forward

        if primary.keyPath == \FileItem.name {
            appState.setSorting(field: .name)
        } else if primary.keyPath == \FileItem.dateModifiedComparable {
            appState.setSorting(field: .dateModified)
        } else if primary.keyPath == \FileItem.fileTypeDescription {
            appState.setSorting(field: .type)
        } else if primary.keyPath == \FileItem.sizeComparable {
            appState.setSorting(field: .size)
        }
        var tab = appState.activeTab
        tab.sortDirection = isAscending ? .ascending : .descending
        appState.activeTab = tab
    }
}

// MARK: - Sortable Extensions for FileItem

extension FileItem {
    public var dateModifiedComparable: Date {
        dateModified ?? Date.distantPast
    }

    public var sizeComparable: Int64 {
        size
    }
}
