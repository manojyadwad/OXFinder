import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// Represents a view presentation mode matching Windows File Explorer
public enum ViewMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case details = "Details"
    case list = "List"
    case smallIcons = "Small Icons"
    case mediumIcons = "Medium Icons"
    case largeIcons = "Large Icons"
    case extraLargeIcons = "Extra Large Icons"

    public var id: String { rawValue }

    public var iconSize: CGFloat {
        switch self {
        case .details: return 18
        case .list: return 20
        case .smallIcons: return 32
        case .mediumIcons: return 64
        case .largeIcons: return 128
        case .extraLargeIcons: return 256
        }
    }

    public var gridCellWidth: CGFloat {
        switch self {
        case .details: return 0 // Table layout
        case .list: return 220
        case .smallIcons: return 90
        case .mediumIcons: return 110
        case .largeIcons: return 160
        case .extraLargeIcons: return 280
        }
    }

    public var gridCellHeight: CGFloat {
        switch self {
        case .details: return 26
        case .list: return 28
        case .smallIcons: return 70
        case .mediumIcons: return 100
        case .largeIcons: return 160
        case .extraLargeIcons: return 300
        }
    }

    public var systemIconName: String {
        switch self {
        case .details: return "list.bullet.rectangle"
        case .list: return "list.bullet"
        case .smallIcons: return "square.grid.3x3"
        case .mediumIcons: return "square.grid.2x2"
        case .largeIcons: return "square.grid.2x2.fill"
        case .extraLargeIcons: return "rectangle.grid.1x2"
        }
    }
}

/// Field by which directory items can be sorted
public enum SortField: String, CaseIterable, Identifiable, Codable, Sendable {
    case name = "Name"
    case dateModified = "Date modified"
    case type = "Type"
    case size = "Size"

    public var id: String { rawValue }

    public var systemIconName: String {
        switch self {
        case .name: return "character"
        case .dateModified: return "calendar"
        case .type: return "doc"
        case .size: return "externaldrive"
        }
    }
}

/// Sort direction
public enum SortDirection: String, Codable, Sendable {
    case ascending
    case descending

    public mutating func toggle() {
        self = (self == .ascending) ? .descending : .ascending
    }
}

/// Represents the active clipboard operation (Cut vs Copy)
public enum ClipboardOperation: Equatable, Sendable {
    case none
    case cut(Set<URL>)
    case copy(Set<URL>)

    public var urls: Set<URL> {
        switch self {
        case .none: return []
        case .cut(let urls), .copy(let urls): return urls
        }
    }

    public var isCut: Bool {
        if case .cut = self { return true }
        return false
    }

    public var isCopy: Bool {
        if case .copy = self { return true }
        return false
    }
}

/// User decision for resolving existing file conflicts
public enum ConflictResolution: Sendable {
    case replace
    case skip
    case keepBoth
}
