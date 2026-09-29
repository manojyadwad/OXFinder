import Foundation
import SwiftUI

/// Represents a single tab in the Windows File Explorer shell
public struct TabItem: Identifiable, Codable, Equatable {
    public let id: UUID
    public var currentURL: URL
    public var history: [URL]
    public var historyIndex: Int
    public var viewMode: ViewMode
    public var sortField: SortField
    public var sortDirection: SortDirection
    public var searchQuery: String
    public var isRecursiveSearch: Bool

    public init(
        id: UUID = UUID(),
        currentURL: URL,
        viewMode: ViewMode = .details,
        sortField: SortField = .name,
        sortDirection: SortDirection = .ascending
    ) {
        self.id = id
        self.currentURL = currentURL
        self.history = [currentURL]
        self.historyIndex = 0
        self.viewMode = viewMode
        self.sortField = sortField
        self.sortDirection = sortDirection
        self.searchQuery = ""
        self.isRecursiveSearch = false
    }

    /// Title displayed in the tab header
    public var title: String {
        let name = currentURL.lastPathComponent
        return name.isEmpty ? currentURL.path : name
    }

    /// Whether back navigation is possible
    public var canGoBack: Bool {
        historyIndex > 0
    }

    /// Whether forward navigation is possible
    public var canGoForward: Bool {
        historyIndex < history.count - 1
    }

    /// Whether navigation to parent directory is possible
    public var canGoUp: Bool {
        currentURL.path != "/"
    }

    /// Navigate to a new directory and push to history
    public mutating func navigate(to url: URL) {
        let standardized = url.standardizedFileURL
        guard standardized != currentURL else { return }

        // Truncate forward history if navigating to a new place
        if historyIndex < history.count - 1 {
            history.removeSubrange((historyIndex + 1)...)
        }
        history.append(standardized)
        historyIndex = history.count - 1
        currentURL = standardized
        searchQuery = ""
    }

    /// Navigate backward in history
    public mutating func goBack() {
        guard canGoBack else { return }
        historyIndex -= 1
        currentURL = history[historyIndex]
        searchQuery = ""
    }

    /// Navigate forward in history
    public mutating func goForward() {
        guard canGoForward else { return }
        historyIndex += 1
        currentURL = history[historyIndex]
        searchQuery = ""
    }

    /// Navigate to parent directory
    public mutating func goUp() {
        guard canGoUp else { return }
        let parent = currentURL.deletingLastPathComponent()
        navigate(to: parent)
    }
}
