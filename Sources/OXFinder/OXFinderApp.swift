import SwiftUI
import AppKit

@main
struct OXFinderApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            MainShellView()
                .navigationTitle("")
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

        // Set Dock and app icon to the custom logo
        if let icon = AppLogoHelper.logoImage {
            NSApp.applicationIconImage = icon
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}
