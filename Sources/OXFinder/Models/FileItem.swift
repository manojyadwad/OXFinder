import Foundation
import AppKit
import UniformTypeIdentifiers

/// Represents a single file or directory item with cached metadata and presentation helpers
public struct FileItem: Identifiable, Hashable, Sendable {
    public let id: URL
    public let url: URL
    public let name: String
    public let displayName: String
    public let isDirectory: Bool
    public let isPackage: Bool
    public let isHidden: Bool
    public let isSymlink: Bool
    public let size: Int64
    public let dateModified: Date?
    public let dateCreated: Date?
    public let contentType: UTType?
    public let fileTypeDescription: String

    public init(url: URL) {
        self.url = url
        self.id = url
        self.name = url.lastPathComponent
        
        let path = url.path
        let fileManager = FileManager.default
        self.displayName = fileManager.displayName(atPath: path)

        var isDir: ObjCBool = false
        fileManager.fileExists(atPath: path, isDirectory: &isDir)
        self.isDirectory = isDir.boolValue

        let values = try? url.resourceValues(forKeys: [
            .isPackageKey,
            .isHiddenKey,
            .isSymbolicLinkKey,
            .fileSizeKey,
            .contentModificationDateKey,
            .creationDateKey,
            .contentTypeKey
        ])

        self.isPackage = values?.isPackage ?? false
        self.isHidden = values?.isHidden ?? (url.lastPathComponent.hasPrefix("."))
        self.isSymlink = values?.isSymbolicLink ?? false
        self.size = Int64(values?.fileSize ?? 0)
        self.dateModified = values?.contentModificationDate
        self.dateCreated = values?.creationDate
        self.contentType = values?.contentType

        if isDir.boolValue && !(values?.isPackage ?? false) {
            self.fileTypeDescription = "File folder"
        } else if let ct = values?.contentType {
            self.fileTypeDescription = ct.localizedDescription ?? ct.preferredFilenameExtension?.uppercased() ?? "File"
        } else {
            let ext = url.pathExtension.uppercased()
            self.fileTypeDescription = ext.isEmpty ? "File" : "\(ext) File"
        }
    }

    public init(
        url: URL,
        name: String,
        displayName: String,
        isDirectory: Bool,
        isPackage: Bool,
        isHidden: Bool,
        isSymlink: Bool,
        size: Int64,
        dateModified: Date?,
        dateCreated: Date?,
        contentType: UTType?,
        fileTypeDescription: String
    ) {
        self.id = url
        self.url = url
        self.name = name
        self.displayName = displayName
        self.isDirectory = isDirectory
        self.isPackage = isPackage
        self.isHidden = isHidden
        self.isSymlink = isSymlink
        self.size = size
        self.dateModified = dateModified
        self.dateCreated = dateCreated
        self.contentType = contentType
        self.fileTypeDescription = fileTypeDescription
    }

    /// Formatted human-readable file size matching Windows Explorer (KB, MB, GB)
    public var formattedSize: String {
        if isDirectory && !isPackage {
            return "" // Windows File Explorer leaves directory size blank in list
        }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }

    /// Formatted modification date
    public var formattedDateModified: String {
        guard let date = dateModified else { return "" }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    /// Check if item is an image file
    public var isImage: Bool {
        if let ct = contentType {
            return ct.conforms(to: .image)
        }
        let ext = url.pathExtension.lowercased()
        return ["jpg", "jpeg", "png", "gif", "heic", "tiff", "tif", "bmp", "webp", "svg", "raw", "cr2", "nef"].contains(ext)
    }

    /// System icon image using NSWorkspace
    public var systemIcon: NSImage {
        NSWorkspace.shared.icon(forFile: url.path)
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(url)
    }

    public static func == (lhs: FileItem, rhs: FileItem) -> Bool {
        lhs.url == rhs.url
    }
}
