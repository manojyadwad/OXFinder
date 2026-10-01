import Foundation
import SwiftUI
import Combine

/// State representing a pending file conflict resolution modal
public struct ConflictPromptState: Identifiable {
    public let id = UUID()
    public let sourceURL: URL
    public let targetURL: URL
    public let continuation: CheckedContinuation<ConflictResolution, Never>
}

@MainActor
public final class AppState: ObservableObject {
    public static let shared = AppState()

    // MARK: - Tabs State
    @Published public var tabs: [TabItem] = []
    @Published public var activeTabId: UUID = UUID()
    private var closedTabsStack: [TabItem] = []

    // MARK: - Current Directory State
    @Published public var currentItems: [FileItem] = []
    @Published public var selectedURLs: Set<URL> = []
    @Published public var isLoading: Bool = false
    @Published public var showHiddenFiles: Bool = false

    // MARK: - Clipboard (True Cut / Copy / Paste)
    @Published public var clipboard: ClipboardOperation = .none

    // MARK: - Sidebar Quick Access & Volumes
    @Published public var quickAccessURLs: [URL] = []
    @Published public var mountedVolumes: [URL] = []

    // MARK: - Preview Pane & Dedicated Viewer
    @Published public var isPreviewPaneVisible: Bool = true
    @Published public var previewItem: FileItem? = nil
    @Published public var previewMetadata: FileDetailedMetadata? = nil
    @Published public var viewerItem: FileItem? = nil

    // MARK: - Conflict Dialog State
    @Published public var activeConflict: ConflictPromptState? = nil

    // MARK: - Status Bar Info
    @Published public var volumeFreeSpaceFormatted: String = ""

    // MARK: - Services
    private let fileSystem = FileSystemManager.shared
    private let directoryWatcher = DirectoryWatcher()
    private let volumeWatcher = VolumeWatcher()
    private var cancellables = Set<AnyCancellable>()

    public init() {
        setupDefaultLocations()
        setupInitialTab()
        setupDirectoryWatcher()
        setupVolumeWatcher()
        refreshVolumes()
    }

    // MARK: - Active Tab Accessor

    public var activeTab: TabItem {
        get {
            tabs.first(where: { $0.id == activeTabId }) ?? tabs.first ?? TabItem(currentURL: FileManager.default.homeDirectoryForCurrentUser)
        }
        set {
            if let index = tabs.firstIndex(where: { $0.id == newValue.id }) {
                tabs[index] = newValue
            }
        }
    }

    public var activeTabIndex: Int {
        tabs.firstIndex(where: { $0.id == activeTabId }) ?? 0
    }

    // MARK: - Tab Management

    public func addTab(at url: URL? = nil) {
        let targetURL = url ?? activeTab.currentURL
        let newTab = TabItem(currentURL: targetURL, viewMode: activeTab.viewMode, sortField: activeTab.sortField, sortDirection: activeTab.sortDirection)
        tabs.append(newTab)
        activeTabId = newTab.id
        loadCurrentDirectory()
    }

    public func closeTab(id: UUID) {
        guard tabs.count > 1 else { return } // Keep at least one tab open
        if let index = tabs.firstIndex(where: { $0.id == id }) {
            let removed = tabs.remove(at: index)
            closedTabsStack.append(removed)

            if activeTabId == id {
                let nextIndex = max(0, min(index, tabs.count - 1))
                activeTabId = tabs[nextIndex].id
                loadCurrentDirectory()
            }
        }
    }

    public func reopenClosedTab() {
        guard let restored = closedTabsStack.popLast() else { return }
        tabs.append(restored)
        activeTabId = restored.id
        loadCurrentDirectory()
    }

    public func selectTab(id: UUID) {
        guard activeTabId != id else { return }
        activeTabId = id
        selectedURLs.removeAll()
        loadCurrentDirectory()
    }

    public func moveTab(fromIndex: Int, toIndex: Int) {
        tabs.move(fromOffsets: IndexSet(integer: fromIndex), toOffset: toIndex)
    }

    // MARK: - Navigation

    public func navigate(to url: URL) {
        var tab = activeTab
        tab.navigate(to: url)
        activeTab = tab
        selectedURLs.removeAll()
        loadCurrentDirectory()
    }

    public func goBack() {
        var tab = activeTab
        tab.goBack()
        activeTab = tab
        selectedURLs.removeAll()
        loadCurrentDirectory()
    }

    public func goForward() {
        var tab = activeTab
        tab.goForward()
        activeTab = tab
        selectedURLs.removeAll()
        loadCurrentDirectory()
    }

    public func goUp() {
        var tab = activeTab
        tab.goUp()
        activeTab = tab
        selectedURLs.removeAll()
        loadCurrentDirectory()
    }

    // MARK: - Directory Loading & Watching

    public func loadCurrentDirectory() {
        let currentURL = activeTab.currentURL
        let sortField = activeTab.sortField
        let sortDirection = activeTab.sortDirection
        let showHidden = showHiddenFiles
        let query = activeTab.searchQuery
        let isRecursive = activeTab.isRecursiveSearch

        directoryWatcher.start(watching: currentURL)

        Task {
            isLoading = true
            let items: [FileItem]
            if !query.isEmpty {
                items = await fileSystem.search(query: query, in: currentURL, recursive: isRecursive)
            } else {
                items = (try? await fileSystem.contentsOfDirectory(
                    at: currentURL,
                    showHidden: showHidden,
                    sortField: sortField,
                    sortDirection: sortDirection
                )) ?? []
            }

            self.currentItems = items
            self.isLoading = false
            self.updateVolumeInfo()
            self.updatePreviewSelection()
        }
    }

    private func setupDirectoryWatcher() {
        directoryWatcher.onChange = { [weak self] in
            Task { @MainActor [weak self] in
                self?.loadCurrentDirectory()
            }
        }
    }

    // MARK: - True Cut / Copy / Paste

    public func cutSelection() {
        guard !selectedURLs.isEmpty else { return }
        clipboard = .cut(selectedURLs)
    }

    public func copySelection() {
        guard !selectedURLs.isEmpty else { return }
        clipboard = .copy(selectedURLs)
    }

    public func pasteClipboard(into destination: URL? = nil) {
        let targetFolder = destination ?? activeTab.currentURL
        let urlsToProcess = Array(clipboard.urls)
        guard !urlsToProcess.isEmpty else { return }
        let isCut = clipboard.isCut

        Task {
            do {
                _ = try await fileSystem.paste(
                    sourceURLs: urlsToProcess,
                    into: targetFolder,
                    isCut: isCut,
                    conflictResolution: { source, target in
                        await self.promptConflictResolution(source: source, target: target)
                    }
                )

                if isCut {
                    self.clipboard = .none
                }
                self.loadCurrentDirectory()
            } catch {
                print("Error during paste operation: \(error)")
            }
        }
    }

    public func promptConflictResolution(source: URL, target: URL) async -> ConflictResolution {
        return await withCheckedContinuation { continuation in
            self.activeConflict = ConflictPromptState(
                sourceURL: source,
                targetURL: target,
                continuation: continuation
            )
        }
    }

    public func resolveConflict(with decision: ConflictResolution) {
        activeConflict?.continuation.resume(returning: decision)
        activeConflict = nil
    }

    // MARK: - File Operations

    public func createNewFolder() {
        Task {
            do {
                let newFolderURL = try await fileSystem.createNewFolder(in: activeTab.currentURL)
                self.loadCurrentDirectory()
                self.selectedURLs = [newFolderURL]
            } catch {
                print("Failed to create folder: \(error)")
            }
        }
    }

    public func createNewTextFile() {
        Task {
            do {
                let newFileURL = try await fileSystem.createNewTextFile(in: activeTab.currentURL)
                self.loadCurrentDirectory()
                self.selectedURLs = [newFileURL]
            } catch {
                print("Failed to create text file: \(error)")
            }
        }
    }

    public func renameItem(url: URL, newName: String) {
        Task {
            do {
                let newURL = try await fileSystem.renameItem(at: url, to: newName)
                self.loadCurrentDirectory()
                self.selectedURLs = [newURL]
            } catch {
                print("Failed to rename item: \(error)")
            }
        }
    }

    public func deleteSelection() {
        let urls = Array(selectedURLs)
        guard !urls.isEmpty else { return }
        Task {
            do {
                try await fileSystem.moveToTrash(urls: urls)
                self.selectedURLs.removeAll()
                self.loadCurrentDirectory()
            } catch {
                print("Failed to trash items: \(error)")
            }
        }
    }

    public func duplicateSelection() {
        let urls = Array(selectedURLs)
        guard !urls.isEmpty else { return }
        Task {
            do {
                let created = try await fileSystem.duplicate(urls: urls)
                self.loadCurrentDirectory()
                self.selectedURLs = Set(created)
            } catch {
                print("Failed to duplicate: \(error)")
            }
        }
    }

    // MARK: - Selection & Preview

    public func selectItem(_ item: FileItem, extendSelection: Bool = false) {
        if extendSelection {
            if selectedURLs.contains(item.url) {
                selectedURLs.remove(item.url)
            } else {
                selectedURLs.insert(item.url)
            }
        } else {
            selectedURLs = [item.url]
        }
        updatePreviewSelection()
    }

    public func updatePreviewSelection() {
        guard let firstURL = selectedURLs.first,
              let item = currentItems.first(where: { $0.url == firstURL }) else {
            previewItem = nil
            previewMetadata = nil
            return
        }

        // Set previewItem immediately for instant UI feedback
        previewItem = item
        let targetURL = item.url

        // Extract metadata asynchronously in background without blocking MainActor click events
        Task.detached(priority: .userInitiated) {
            let metadata = MetadataExtractor.shared.extractMetadata(for: targetURL)
            await MainActor.run {
                if self.selectedURLs.contains(targetURL) {
                    self.previewMetadata = metadata
                }
            }
        }
    }

    public func openItem(_ item: FileItem) {
        if item.isDirectory && !item.isPackage {
            navigate(to: item.url)
        } else if item.isImage {
            viewerItem = item
        } else {
            NSWorkspace.shared.open(item.url)
        }
    }

    // MARK: - View Mode & Sorting

    public func setViewMode(_ mode: ViewMode) {
        var tab = activeTab
        tab.viewMode = mode
        activeTab = tab
    }

    public func setSorting(field: SortField) {
        var tab = activeTab
        if tab.sortField == field {
            tab.sortDirection.toggle()
        } else {
            tab.sortField = field
            tab.sortDirection = .ascending
        }
        activeTab = tab
        loadCurrentDirectory()
    }

    public func togglePreviewPane() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isPreviewPaneVisible.toggle()
        }
    }

    public func toggleHiddenFiles() {
        showHiddenFiles.toggle()
        loadCurrentDirectory()
    }

    // MARK: - Volume Info & Status

    public func refreshVolumes() {
        Task {
            let vols = await fileSystem.getMountedVolumes()
            self.mountedVolumes = vols
            self.updateVolumeInfo()
        }
    }

    private func setupVolumeWatcher() {
        volumeWatcher.onVolumeChange = { [weak self] in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.refreshVolumes()
                if self.activeTab.currentURL.path == "/Volumes" {
                    self.loadCurrentDirectory()
                }
                var isDir: ObjCBool = false
                if !FileManager.default.fileExists(atPath: self.activeTab.currentURL.path, isDirectory: &isDir) {
                    self.navigate(to: FileManager.default.homeDirectoryForCurrentUser)
                }
            }
        }
    }

    /// Safely unmount and eject an external volume or pen drive
    public func ejectVolume(_ url: URL) {
        Task {
            do {
                try await fileSystem.ejectVolume(at: url)
                await MainActor.run {
                    self.refreshVolumes()
                    if self.activeTab.currentURL.path.hasPrefix(url.path) {
                        self.navigate(to: FileManager.default.homeDirectoryForCurrentUser)
                    }
                }
            } catch {
                print("Failed to eject volume: \(error)")
            }
        }
    }

    private func updateVolumeInfo() {
        Task {
            if let info = await fileSystem.getVolumeStorageInfo(for: activeTab.currentURL) {
                let formatter = ByteCountFormatter()
                formatter.countStyle = .file
                let freeStr = formatter.string(fromByteCount: info.freeBytes)
                let totalStr = formatter.string(fromByteCount: info.totalBytes)
                self.volumeFreeSpaceFormatted = "\(freeStr) free of \(totalStr)"
            } else {
                self.volumeFreeSpaceFormatted = ""
            }
        }
    }

    // MARK: - Setup Helpers

    private func setupInitialTab() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let initialTab = TabItem(currentURL: home, viewMode: .details)
        tabs = [initialTab]
        activeTabId = initialTab.id
        loadCurrentDirectory()
    }

    private func setupDefaultLocations() {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser

        quickAccessURLs = [
            home,
            fm.urls(for: .desktopDirectory, in: .userDomainMask).first ?? home.appendingPathComponent("Desktop"),
            fm.urls(for: .documentDirectory, in: .userDomainMask).first ?? home.appendingPathComponent("Documents"),
            fm.urls(for: .downloadsDirectory, in: .userDomainMask).first ?? home.appendingPathComponent("Downloads"),
            fm.urls(for: .picturesDirectory, in: .userDomainMask).first ?? home.appendingPathComponent("Pictures"),
            fm.urls(for: .moviesDirectory, in: .userDomainMask).first ?? home.appendingPathComponent("Movies"),
            fm.urls(for: .musicDirectory, in: .userDomainMask).first ?? home.appendingPathComponent("Music")
        ]
    }
}
