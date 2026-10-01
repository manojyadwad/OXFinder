import Foundation
import AppKit
import UniformTypeIdentifiers

/// Actor responsible for high-performance, non-blocking file system I/O, enumeration, and manipulation
public actor FileSystemManager {
    public static let shared = FileSystemManager()

    private let fileManager = FileManager.default

    public init() {}

    // MARK: - Directory Enumeration

    /// Enumerate items in a directory with high-performance bulk resource prefetching
    public func contentsOfDirectory(
        at url: URL,
        showHidden: Bool = false,
        sortField: SortField = .name,
        sortDirection: SortDirection = .ascending
    ) throws -> [FileItem] {
        let keys: [URLResourceKey] = [
            .nameKey,
            .localizedNameKey,
            .isDirectoryKey,
            .isPackageKey,
            .isHiddenKey,
            .isSymbolicLinkKey,
            .fileSizeKey,
            .contentModificationDateKey,
            .creationDateKey,
            .contentTypeKey
        ]

        let options: FileManager.DirectoryEnumerationOptions = showHidden ? [] : [.skipsHiddenFiles]

        guard let contents = try? fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: keys,
            options: options
        ) else {
            return []
        }

        var items: [FileItem] = []
        items.reserveCapacity(contents.count)

        for fileURL in contents {
            // Check if hidden manually if skipsHiddenFiles option is not used or item begins with .
            let lastComponent = fileURL.lastPathComponent
            if !showHidden && lastComponent.hasPrefix(".") {
                continue
            }

            let values = try? fileURL.resourceValues(forKeys: Set(keys))
            let isDir = values?.isDirectory ?? false
            let isPkg = values?.isPackage ?? false
            let isHidden = values?.isHidden ?? lastComponent.hasPrefix(".")
            let isSymlink = values?.isSymbolicLink ?? false
            let size = Int64(values?.fileSize ?? 0)
            let dateMod = values?.contentModificationDate
            let dateCreated = values?.creationDate
            let contentType = values?.contentType
            let displayName = values?.localizedName ?? fileManager.displayName(atPath: fileURL.path)

            let typeDesc: String
            if isDir && !isPkg {
                typeDesc = "File folder"
            } else if let ct = contentType {
                typeDesc = ct.localizedDescription ?? ct.preferredFilenameExtension?.uppercased() ?? "File"
            } else {
                let ext = fileURL.pathExtension.uppercased()
                typeDesc = ext.isEmpty ? "File" : "\(ext) File"
            }

            let item = FileItem(
                url: fileURL,
                name: lastComponent,
                displayName: displayName,
                isDirectory: isDir,
                isPackage: isPkg,
                isHidden: isHidden,
                isSymlink: isSymlink,
                size: size,
                dateModified: dateMod,
                dateCreated: dateCreated,
                contentType: contentType,
                fileTypeDescription: typeDesc
            )
            items.append(item)
        }

        return sort(items: items, by: sortField, direction: sortDirection)
    }

    /// Sort items matching Windows Explorer behavior (Directories first, followed by files)
    public func sort(items: [FileItem], by field: SortField, direction: SortDirection) -> [FileItem] {
        return items.sorted { a, b in
            // Windows File Explorer sorts folders first in default order
            if a.isDirectory != b.isDirectory {
                return a.isDirectory && !b.isDirectory
            }

            let comparison: ComparisonResult
            switch field {
            case .name:
                comparison = a.displayName.localizedStandardCompare(b.displayName)
            case .dateModified:
                let d1 = a.dateModified ?? Date.distantPast
                let d2 = b.dateModified ?? Date.distantPast
                comparison = d1.compare(d2)
            case .type:
                comparison = a.fileTypeDescription.localizedStandardCompare(b.fileTypeDescription)
            case .size:
                if a.size == b.size {
                    comparison = a.displayName.localizedStandardCompare(b.displayName)
                } else {
                    comparison = a.size < b.size ? .orderedAscending : .orderedDescending
                }
            }

            return direction == .ascending ? (comparison == .orderedAscending) : (comparison == .orderedDescending)
        }
    }

    // MARK: - File Operations (Cut / Copy / Paste / Conflict)

    /// Execute paste operation for given source URLs into a target folder
    public func paste(
        sourceURLs: [URL],
        into destinationFolder: URL,
        isCut: Bool,
        conflictResolution: @Sendable (URL, URL) async -> ConflictResolution
    ) async throws -> [URL] {
        var processedURLs: [URL] = []

        for source in sourceURLs {
            let target = destinationFolder.appendingPathComponent(source.lastPathComponent)
            var finalDestination = target

            if fileManager.fileExists(atPath: target.path) {
                let resolution = await conflictResolution(source, target)
                switch resolution {
                case .skip:
                    continue
                case .replace:
                    try fileManager.removeItem(at: target)
                    finalDestination = target
                case .keepBoth:
                    finalDestination = generateUniqueURL(for: target, in: destinationFolder)
                }
            }

            if isCut {
                try fileManager.moveItem(at: source, to: finalDestination)
            } else {
                try fileManager.copyItem(at: source, to: finalDestination)
            }
            processedURLs.append(finalDestination)
        }

        return processedURLs
    }

    /// Creates a new directory with Windows Explorer style default numbering ("New folder", "New folder (2)")
    public func createNewFolder(in parentURL: URL) throws -> URL {
        var candidateName = "New folder"
        var candidateURL = parentURL.appendingPathComponent(candidateName)
        var index = 2

        while fileManager.fileExists(atPath: candidateURL.path) {
            candidateName = "New folder (\(index))"
            candidateURL = parentURL.appendingPathComponent(candidateName)
            index += 1
        }

        try fileManager.createDirectory(at: candidateURL, withIntermediateDirectories: false)
        return candidateURL
    }

    /// Creates a new text document matching Windows Explorer ("New Text Document.txt", "New Text Document (2).txt")
    public func createNewTextFile(in parentURL: URL) throws -> URL {
        var candidateName = "New Text Document.txt"
        var candidateURL = parentURL.appendingPathComponent(candidateName)
        var index = 2

        while fileManager.fileExists(atPath: candidateURL.path) {
            candidateName = "New Text Document (\(index)).txt"
            candidateURL = parentURL.appendingPathComponent(candidateName)
            index += 1
        }

        try "".write(to: candidateURL, atomically: true, encoding: .utf8)
        return candidateURL
    }

    /// Rename an item at a given URL
    public func renameItem(at url: URL, to newName: String) throws -> URL {
        let destination = url.deletingLastPathComponent().appendingPathComponent(newName)
        if destination == url { return url }
        try fileManager.moveItem(at: url, to: destination)
        return destination
    }

    /// Move items to Trash
    public func moveToTrash(urls: [URL]) async throws {
        for url in urls {
            var resultingURL: NSURL?
            try fileManager.trashItem(at: url, resultingItemURL: &resultingURL)
        }
    }

    /// Duplicate file/folder Windows-style ("Copy of filename.ext" or "filename - Copy.ext")
    public func duplicate(urls: [URL]) throws -> [URL] {
        var results: [URL] = []
        for url in urls {
            let parent = url.deletingLastPathComponent()
            let baseName = url.deletingPathExtension().lastPathComponent
            let ext = url.pathExtension

            var copyName = ext.isEmpty ? "\(baseName) - Copy" : "\(baseName) - Copy.\(ext)"
            var destination = parent.appendingPathComponent(copyName)
            var index = 2

            while fileManager.fileExists(atPath: destination.path) {
                copyName = ext.isEmpty ? "\(baseName) - Copy (\(index))" : "\(baseName) - Copy (\(index)).\(ext)"
                destination = parent.appendingPathComponent(copyName)
                index += 1
            }

            try fileManager.copyItem(at: url, to: destination)
            results.append(destination)
        }
        return results
    }

    /// Generate unique URL by appending " (1)", " (2)" before the file extension
    private func generateUniqueURL(for target: URL, in folder: URL) -> URL {
        let baseName = target.deletingPathExtension().lastPathComponent
        let ext = target.pathExtension
        var counter = 1
        var candidate = target

        while fileManager.fileExists(atPath: candidate.path) {
            let newName = ext.isEmpty ? "\(baseName) (\(counter))" : "\(baseName) (\(counter)).\(ext)"
            candidate = folder.appendingPathComponent(newName)
            counter += 1
        }
        return candidate
    }

    // MARK: - Volumes & Storage Information

    /// Get all mounted storage volumes on macOS (Internal drives, external SSDs, USB pen drives)
    public func getMountedVolumes() -> [URL] {
        let keys: [URLResourceKey] = [.volumeNameKey, .volumeIsRemovableKey, .volumeIsInternalKey, .volumeIsEjectableKey]
        var volumes = fileManager.mountedVolumeURLs(includingResourceValuesForKeys: keys, options: [.skipHiddenVolumes]) ?? []

        // Also inspect /Volumes directly to ensure no pen drive or disk image is missed
        let volDir = URL(fileURLWithPath: "/Volumes")
        if let volContents = try? fileManager.contentsOfDirectory(at: volDir, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]) {
            for volURL in volContents {
                // If it is a symlink to "/" (like /Volumes/Macintosh HD -> /), skip
                let isRootSymlink = ((try? volURL.resourceValues(forKeys: [.isSymbolicLinkKey]))?.isSymbolicLink == true) &&
                    ((try? fileManager.destinationOfSymbolicLink(atPath: volURL.path)) == "/" || volURL.resolvingSymlinksInPath().path == "/")
                if isRootSymlink { continue }

                let matchesExisting = volumes.contains { v in
                    v.path == volURL.path || v.standardizedFileURL.path == volURL.standardizedFileURL.path
                }
                if !matchesExisting {
                    volumes.append(volURL)
                }
            }
        }

        // Ensure root "/" is included
        let rootURL = URL(fileURLWithPath: "/")
        if !volumes.contains(where: { $0.path == "/" }) {
            volumes.insert(rootURL, at: 0)
        }

        // Sort: root drive ("/") first, followed by removable pen drives / external disks, then other volumes
        return volumes.sorted { v1, v2 in
            if v1.path == "/" { return true }
            if v2.path == "/" { return false }

            let vals1 = try? v1.resourceValues(forKeys: Set(keys))
            let vals2 = try? v2.resourceValues(forKeys: Set(keys))
            let rem1 = (vals1?.volumeIsRemovable == true) || (vals1?.volumeIsEjectable == true)
            let rem2 = (vals2?.volumeIsRemovable == true) || (vals2?.volumeIsEjectable == true)

            if rem1 != rem2 {
                return rem1 // Prioritize removable pen drives right after main disk
            }
            let n1 = vals1?.volumeName ?? v1.lastPathComponent
            let n2 = vals2?.volumeName ?? v2.lastPathComponent
            return n1.localizedStandardCompare(n2) == .orderedAscending
        }
    }

    /// Eject a removable volume or pen drive
    public func ejectVolume(at url: URL) throws {
        try NSWorkspace.shared.unmountAndEjectDevice(at: url)
    }

    /// Calculate free and total capacity for a volume or folder URL
    public func getVolumeStorageInfo(for url: URL) -> (freeBytes: Int64, totalBytes: Int64)? {
        guard let values = try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey, .volumeTotalCapacityKey]) else {
            return nil
        }
        let free = values.volumeAvailableCapacityForImportantUsage ?? 0
        let total = Int64(values.volumeTotalCapacity ?? 0)
        return (free, total)
    }

    /// Recursive search within directory
    public func search(query: String, in directory: URL, recursive: Bool) -> [FileItem] {
        let lowerQuery = query.lowercased()
        if !recursive {
            guard let contents = try? contentsOfDirectory(at: directory, showHidden: false) else { return [] }
            return contents.filter { $0.displayName.lowercased().contains(lowerQuery) }
        }

        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.localizedNameKey, .isDirectoryKey, .fileSizeKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }

        var results: [FileItem] = []
        for case let fileURL as URL in enumerator {
            if fileURL.lastPathComponent.lowercased().contains(lowerQuery) {
                results.append(FileItem(url: fileURL))
                if results.count >= 500 { break } // Limit max search results for speed
            }
        }
        return results
    }
}
