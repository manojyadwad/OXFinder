import SwiftUI

/// Root Shell View uniting TabBar, Ribbon Toolbar, Address Bar, Navigation Sidebar, File Grid, Preview Pane, and Status Bar
public struct MainShellView: View {
    @StateObject private var appState = AppState.shared

    @AppStorage("oxfinder_sidebarWidth") private var storedSidebarWidth: Double = 220.0
    @AppStorage("oxfinder_previewWidth") private var storedPreviewWidth: Double = 260.0
    @State private var sidebarWidth: CGFloat = 220.0
    @State private var previewWidth: CGFloat = 260.0

    public init() {}

    public var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Windows 11 Tabs
                WindowsTabBarView(appState: appState)

                // Address & Breadcrumb Bar
                AddressBreadcrumbBar(appState: appState)

                // Command Ribbon
                CommandToolbar(appState: appState)

                // Main Content Area with Sidebar & Preview Pane
                HStack(spacing: 0) {
                    // Left Navigation Pane
                    NavigationSidebar(appState: appState)
                        .frame(width: sidebarWidth)
                        .frame(maxHeight: .infinity)

                    // Resizable Divider for Sidebar
                    SplitDividerView(
                        width: $sidebarWidth,
                        minWidth: 160,
                        maxWidth: 380,
                        defaultWidth: 220,
                        invertDelta: false
                    )

                    // Center File Browser Grid / Details
                    FileBrowserContainerView(appState: appState)
                        .frame(minWidth: 350, maxWidth: .infinity, maxHeight: .infinity)

                    // Right Preview Pane (collapsible)
                    if appState.isPreviewPaneVisible {
                        SplitDividerView(
                            width: $previewWidth,
                            minWidth: 200,
                            maxWidth: 420,
                            defaultWidth: 260,
                            invertDelta: true
                        )

                        PreviewPaneView(appState: appState)
                            .frame(width: previewWidth)
                            .frame(maxHeight: .infinity)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Bottom Status Bar
                StatusBarView(appState: appState)
            }

            // In-App Windows Full Image Viewer Modal/Window
            if let item = appState.viewerItem {
                FullImageViewerModal(appState: appState, item: item)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    .zIndex(100)
            }
        }
        .onAppear {
            sidebarWidth = CGFloat(storedSidebarWidth)
            previewWidth = CGFloat(storedPreviewWidth)
        }
        .onChange(of: sidebarWidth) { newWidth in
            storedSidebarWidth = Double(newWidth)
        }
        .onChange(of: previewWidth) { newWidth in
            storedPreviewWidth = Double(newWidth)
        }
        .frame(minWidth: 900, minHeight: 600)
        // Global Keyboard Shortcuts
        .keyboardShortcut("t", modifiers: .command) // Add tab
        .background(
            HiddenGlobalKeyHandler(appState: appState)
        )
        // Conflict Resolution Sheet
        .sheet(item: $appState.activeConflict) { conflict in
            ConflictResolutionDialog(
                sourceURL: conflict.sourceURL,
                targetURL: conflict.targetURL,
                onDecision: { decision in
                    appState.resolveConflict(with: decision)
                }
            )
        }
    }
}

// MARK: - Global Key Handler for Cut/Copy/Paste/Tabs

struct HiddenGlobalKeyHandler: NSViewRepresentable {
    @ObservedObject var appState: AppState

    func makeNSView(context: Context) -> KeyView {
        let view = KeyView()
        view.appState = appState
        return view
    }

    func updateNSView(_ nsView: KeyView, context: Context) {
        nsView.appState = appState
    }

    class KeyView: NSView {
        var appState: AppState?

        override var acceptsFirstResponder: Bool { false }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self = self, let appState = self.appState else { return event }

                let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

                // Cmd + T: New Tab
                if flags == .command && event.charactersIgnoringModifiers == "t" {
                    appState.addTab()
                    return nil
                }

                // Cmd + W: Close Tab
                if flags == .command && event.charactersIgnoringModifiers == "w" {
                    appState.closeTab(id: appState.activeTabId)
                    return nil
                }

                // Cmd + Shift + T: Reopen Closed Tab
                if flags == [.command, .shift] && event.charactersIgnoringModifiers?.lowercased() == "t" {
                    appState.reopenClosedTab()
                    return nil
                }

                // Cmd + X: True Cut
                if flags == .command && event.charactersIgnoringModifiers == "x" {
                    appState.cutSelection()
                    return nil
                }

                // Cmd + C: Copy
                if flags == .command && event.charactersIgnoringModifiers == "c" {
                    appState.copySelection()
                    return nil
                }

                // Cmd + V: True Paste
                if flags == .command && event.charactersIgnoringModifiers == "v" {
                    appState.pasteClipboard()
                    return nil
                }

                // Cmd + Backspace / Delete: Move to Trash
                if (flags == .command && event.keyCode == 51) || (flags == [] && event.keyCode == 117) {
                    appState.deleteSelection()
                    return nil
                }

                // Option + P: Toggle Preview Pane
                if flags == .option && event.charactersIgnoringModifiers?.lowercased() == "p" {
                    appState.togglePreviewPane()
                    return nil
                }

                // Cmd + Shift + .: Toggle Hidden Files
                if flags == [.command, .shift] && event.charactersIgnoringModifiers == "." {
                    appState.toggleHiddenFiles()
                    return nil
                }

                // Cmd + A: Select All
                if flags == .command && event.charactersIgnoringModifiers == "a" {
                    appState.selectedURLs = Set(appState.currentItems.map { $0.url })
                    appState.updatePreviewSelection()
                    return nil
                }

                // Enter / Return: Open selected item or launch viewer
                if flags == [] && (event.keyCode == 36 || event.keyCode == 76) {
                    if let firstURL = appState.selectedURLs.first,
                       let item = appState.currentItems.first(where: { $0.url == firstURL }) {
                        appState.openItem(item)
                        return nil
                    }
                }

                return event
            }
        }
    }
}
