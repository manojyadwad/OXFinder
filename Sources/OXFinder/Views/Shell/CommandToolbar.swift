import SwiftUI
import AppKit

/// Windows 11 style Ribbon / Command Bar with quick actions, sort & view mode controls
public struct CommandToolbar: View {
    @ObservedObject var appState: AppState

    public var body: some View {
        HStack(spacing: 8) {
            // New Folder
            toolbarButton(title: "New folder", icon: "folder.badge.plus") {
                appState.createNewFolder()
            }

            Divider()
                .frame(height: 18)

            // Cut / Copy / Paste / Rename / Share / Delete
            toolbarButton(title: "Cut", icon: "scissors", disabled: appState.selectedURLs.isEmpty) {
                appState.cutSelection()
            }
            .help("Cut (Cmd+X)")

            toolbarButton(title: "Copy", icon: "doc.on.doc", disabled: appState.selectedURLs.isEmpty) {
                appState.copySelection()
            }
            .help("Copy (Cmd+C)")

            toolbarButton(title: "Paste", icon: "doc.on.clipboard", disabled: appState.clipboard.urls.isEmpty) {
                appState.pasteClipboard()
            }
            .help("Paste (Cmd+V)")

            toolbarButton(title: "Rename", icon: "pencil", disabled: appState.selectedURLs.count != 1) {
                // Focus rename or alert
            }
            .help("Rename (F2)")

            toolbarButton(title: "Share", icon: "square.and.arrow.up", disabled: appState.selectedURLs.isEmpty) {
                shareSelection()
            }

            toolbarButton(title: "Delete", icon: "trash", disabled: appState.selectedURLs.isEmpty) {
                appState.deleteSelection()
            }
            .help("Move to Trash (Cmd+Backspace)")

            Divider()
                .frame(height: 18)

            // Sort Menu
            Menu {
                ForEach(SortField.allCases) { field in
                    Button(action: {
                        appState.setSorting(field: field)
                    }) {
                        HStack {
                            Text(field.rawValue)
                            if appState.activeTab.sortField == field {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
                Divider()
                Button(action: {
                    var tab = appState.activeTab
                    tab.sortDirection = .ascending
                    appState.activeTab = tab
                    appState.loadCurrentDirectory()
                }) {
                    HStack {
                        Text("Ascending")
                        if appState.activeTab.sortDirection == .ascending {
                            Image(systemName: "checkmark")
                        }
                    }
                }
                Button(action: {
                    var tab = appState.activeTab
                    tab.sortDirection = .descending
                    appState.activeTab = tab
                    appState.loadCurrentDirectory()
                }) {
                    HStack {
                        Text("Descending")
                        if appState.activeTab.sortDirection == .descending {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            } label: {
                Label("Sort", systemImage: "arrow.up.arrow.down")
                    .font(.system(size: 12))
            }
            .menuStyle(BorderlessButtonMenuStyle())

            // View Menu
            Menu {
                ForEach(ViewMode.allCases) { mode in
                    Button(action: {
                        appState.setViewMode(mode)
                    }) {
                        HStack {
                            Image(systemName: mode.systemIconName)
                            Text(mode.rawValue)
                            if appState.activeTab.viewMode == mode {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
                Divider()
                Button(action: {
                    appState.toggleHiddenFiles()
                }) {
                    HStack {
                        Text("Show hidden files")
                        if appState.showHiddenFiles {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            } label: {
                Label("View", systemImage: appState.activeTab.viewMode.systemIconName)
                    .font(.system(size: 12))
            }
            .menuStyle(BorderlessButtonMenuStyle())

            Spacer()

            // Preview Pane Toggle (Option+P / Alt+P)
            Button(action: {
                appState.togglePreviewPane()
            }) {
                Image(systemName: appState.isPreviewPaneVisible ? "sidebar.right" : "sidebar.right")
                    .font(.system(size: 13))
                    .foregroundColor(appState.isPreviewPaneVisible ? .accentColor : .secondary)
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(appState.isPreviewPaneVisible ? Color.accentColor.opacity(0.15) : Color.clear)
            )
            .help("Preview Pane (Option+P)")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(
            Divider(), alignment: .bottom
        )
    }

    private func toolbarButton(title: String, icon: String, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(title)
                    .font(.system(size: 12))
            }
            .foregroundColor(disabled ? .secondary.opacity(0.5) : .primary)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(disabled)
    }

    private func shareSelection() {
        guard let window = NSApp.keyWindow else { return }
        let items = appState.selectedURLs.map { $0 as NSURL }
        let picker = NSSharingServicePicker(items: items)
        picker.show(relativeTo: .zero, of: window.contentView!, preferredEdge: .minY)
    }
}
