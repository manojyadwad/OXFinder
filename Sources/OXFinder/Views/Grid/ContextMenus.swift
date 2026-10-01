import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Structured app open option for the "Open with" submenu
public struct AppOpenOption: Identifiable, Hashable {
    public let id: URL
    public let url: URL
    public let displayName: String
    public let isDefault: Bool
}

/// Helper service for resolving installed applications capable of opening a file
public enum AppOpenService {
    /// Retrieve installed applications that declare support for the given file URL
    public static func applications(for url: URL) -> [AppOpenOption] {
        let appURLs = NSWorkspace.shared.urlsForApplications(toOpen: url)
        let defaultAppURL = NSWorkspace.shared.urlForApplication(toOpen: url)

        var options: [AppOpenOption] = []
        for appURL in appURLs {
            let baseName = FileManager.default.displayName(atPath: appURL.path)
            let isDefault = (appURL.standardizedFileURL == defaultAppURL?.standardizedFileURL)
            let title = isDefault ? "\(baseName) (Default)" : baseName
            options.append(AppOpenOption(id: appURL, url: appURL, displayName: title, isDefault: isDefault))
        }

        // Put default app first, followed by others alphabetically
        return options.sorted { a, b in
            if a.isDefault != b.isDefault {
                return a.isDefault && !b.isDefault
            }
            return a.displayName.localizedStandardCompare(b.displayName) == .orderedAscending
        }
    }

    /// Open file using a specific application
    public static func open(file: URL, withApplication appURL: URL) {
        NSWorkspace.shared.open([file], withApplicationAt: appURL, configuration: NSWorkspace.OpenConfiguration(), completionHandler: nil)
    }

    /// Prompt user to choose any application from disk
    public static func chooseAppToOpen(file: URL) {
        let panel = NSOpenPanel()
        panel.title = "Choose Application"
        panel.prompt = "Open"
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        if panel.runModal() == .OK, let chosenApp = panel.url {
            open(file: file, withApplication: chosenApp)
        }
    }

    /// Open current folder in macOS Terminal
    public static func openInTerminal(folderURL: URL) {
        let terminalAppURL = URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app")
        NSWorkspace.shared.open([folderURL], withApplicationAt: terminalAppURL, configuration: NSWorkspace.OpenConfiguration(), completionHandler: nil)
    }
}

/// Context Menu shown when right-clicking on any file or folder
public struct FileContextMenuView: View {
    let item: FileItem
    @ObservedObject var appState: AppState

    public var body: some View {
        Button("Open") {
            appState.openItem(item)
        }

        if item.isImage {
            Button("View in Image Viewer") {
                appState.viewerItem = item
            }
        }

        // "Open with" Submenu (for files)
        if !item.isDirectory || item.isPackage {
            openWithMenu
        }

        Divider()

        Button("Cut") {
            appState.selectedURLs = [item.url]
            appState.cutSelection()
        }

        Button("Copy") {
            appState.selectedURLs = [item.url]
            appState.copySelection()
        }

        if !appState.clipboard.urls.isEmpty {
            Button("Paste into Folder") {
                if item.isDirectory {
                    appState.pasteClipboard(into: item.url)
                } else {
                    appState.pasteClipboard()
                }
            }
        }

        Button("Duplicate") {
            appState.selectedURLs = [item.url]
            appState.duplicateSelection()
        }

        Divider()

        Button("Move to Trash") {
            appState.selectedURLs = [item.url]
            appState.deleteSelection()
        }

        Divider()

        Button("Copy Path") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(item.url.path, forType: .string)
        }

        Button("Show in Finder") {
            NSWorkspace.shared.activateFileViewerSelecting([item.url])
        }

        if item.url.path.hasPrefix("/Volumes/") && item.isDirectory {
            Divider()
            Button("Eject \(item.displayName)") {
                appState.ejectVolume(item.url)
            }
        }
    }

    private var openWithMenu: some View {
        Menu("Open with") {
            let apps = AppOpenService.applications(for: item.url)
            if apps.isEmpty {
                Button("Default Application") {
                    NSWorkspace.shared.open(item.url)
                }
            } else {
                ForEach(apps) { appOption in
                    Button(appOption.displayName) {
                        AppOpenService.open(file: item.url, withApplication: appOption.url)
                    }
                }
            }

            Divider()

            Button("Choose another app...") {
                AppOpenService.chooseAppToOpen(file: item.url)
            }
        }
    }
}

/// Windows Explorer Context Menu shown when right-clicking on white/blank canvas area
public struct EmptyCanvasContextMenuView: View {
    @ObservedObject var appState: AppState

    public var body: some View {
        // View Modes Submenu
        Menu("View") {
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
        }

        // Sort By Submenu
        Menu("Sort by") {
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
        }

        Button("Refresh") {
            appState.loadCurrentDirectory()
        }

        Divider()

        Button("Paste") {
            appState.pasteClipboard()
        }
        .disabled(appState.clipboard.urls.isEmpty)

        Divider()

        Menu("New") {
            Button("New folder") {
                appState.createNewFolder()
            }
            Button("Text Document") {
                appState.createNewTextFile()
            }
        }

        Divider()

        Button("Open in Terminal") {
            AppOpenService.openInTerminal(folderURL: appState.activeTab.currentURL)
        }
    }
}
