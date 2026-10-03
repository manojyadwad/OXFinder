import SwiftUI
import AppKit

@main
struct OXFinderApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            MainShellView()
                .navigationTitle("")
                .onOpenURL { url in
                    AppDelegate.handleOpenURL(url)
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact)
        .commands {
            SidebarCommands()

            CommandGroup(replacing: .newItem) {
                Button("New Tab") {
                    AppState.shared.addTab()
                }
                .keyboardShortcut("t", modifiers: .command)

                Button("New Folder") {
                    AppState.shared.createNewFolder()
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            }

            CommandGroup(replacing: .pasteboard) {
                Button("Cut") {
                    AppState.shared.cutSelection()
                }
                .keyboardShortcut("x", modifiers: .command)

                Button("Copy") {
                    AppState.shared.copySelection()
                }
                .keyboardShortcut("c", modifiers: .command)

                Button("Paste") {
                    AppState.shared.pasteClipboard()
                }
                .keyboardShortcut("v", modifiers: .command)

                Button("Select All") {
                    AppState.shared.selectedURLs = Set(AppState.shared.currentItems.map { $0.url })
                    AppState.shared.updatePreviewSelection()
                }
                .keyboardShortcut("a", modifiers: .command)
            }

            CommandMenu("View") {
                Button("Toggle Preview Pane") {
                    AppState.shared.togglePreviewPane()
                }
                .keyboardShortcut("p", modifiers: .option)

                Button("Toggle Hidden Files") {
                    AppState.shared.toggleHiddenFiles()
                }
                .keyboardShortcut(".", modifiers: [.command, .shift])

                Divider()

                ForEach(ViewMode.allCases) { mode in
                    Button(mode.rawValue) {
                        AppState.shared.setViewMode(mode)
                    }
                }
            }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.servicesProvider = self

        // Set Dock and app icon to the custom logo
        if let icon = AppLogoHelper.logoImage {
            NSApp.applicationIconImage = icon
        }

        // Install "Open in OX Finder" Quick Action into ~/Library/Services
        QuickActionInstaller.installQuickActionIfNeeded()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            AppDelegate.handleOpenURL(url)
        }
    }

    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        let url = URL(fileURLWithPath: filename)
        AppDelegate.handleOpenURL(url)
        return true
    }

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        for filename in filenames {
            let url = URL(fileURLWithPath: filename)
            AppDelegate.handleOpenURL(url)
        }
    }

    @objc func openInOXFinderService(_ pboard: NSPasteboard, userData: String, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        guard let items = pboard.pasteboardItems else { return }
        for item in items {
            if let urlString = item.string(forType: .fileURL), let url = URL(string: urlString) {
                AppDelegate.handleOpenURL(url)
            }
        }
    }

    /// Central handler to navigate to or reveal any file, folder, application, or shortcut
    public static func handleOpenURL(_ rawURL: URL) {
        let url = rawURL.standardizedFileURL

        Task { @MainActor in
            NSApp.activate(ignoringOtherApps: true)

            var isDir: ObjCBool = false
            let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
            guard exists else { return }

            if isDir.boolValue && !url.pathExtension.elementsEqual("app") {
                // Folder / Directory: navigate directly inside
                AppState.shared.navigate(to: url)
            } else {
                // File, .app bundle, or shortcut: navigate to parent directory and select the item
                let parentDir = url.deletingLastPathComponent()
                AppState.shared.navigate(to: parentDir)
                AppState.shared.selectedURLs = [url]
                AppState.shared.updatePreviewSelection()
            }
        }
    }
}
