import Foundation

/// High-performance file transfer engine supporting real-time chunked streaming progress, speed metering, cancellation, and cross-volume handling
public actor FileTransferEngine {
    public static let shared = FileTransferEngine()

    private let bufferSize: Int = 1024 * 1024 * 2 // 2 MB chunks

    public init() {}

    /// Calculate total item count and recursive total byte size for a list of URLs
    public func calculateTransferMetrics(urls: [URL]) -> (totalItems: Int, totalBytes: Int64) {
        let fm = FileManager.default
        var count = 0
        var bytes: Int64 = 0

        for url in urls {
            count += 1
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: url.path, isDirectory: &isDir) {
                if isDir.boolValue && !url.pathExtension.elementsEqual("app") {
                    let enumerator = fm.enumerator(
                        at: url,
                        includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
                        options: [.skipsHiddenFiles]
                    )
                    while let fileURL = enumerator?.nextObject() as? URL {
                        count += 1
                        let vals = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey])
                        if vals?.isDirectory != true {
                            bytes += Int64(vals?.fileSize ?? 0)
                        }
                    }
                } else {
                    let vals = try? url.resourceValues(forKeys: [.fileSizeKey])
                    bytes += Int64(vals?.fileSize ?? 0)
                }
            }
        }

        return (max(count, urls.count), bytes)
    }

    /// Execute transfer with real-time chunked progress reporting
    public func transfer(
        sourceURLs: [URL],
        into destinationFolder: URL,
        isCut: Bool,
        progress: TransferProgressState,
        conflictResolution: @Sendable (URL, URL) async -> ConflictResolution
    ) async throws -> [URL] {
        let activity = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiated, .idleSystemSleepDisabled],
            reason: "OX Finder File Transfer"
        )
        defer {
            ProcessInfo.processInfo.endActivity(activity)
        }

        let fm = FileManager.default
        var processedResults: [URL] = []
        var completedBytesTotal: Int64 = 0
        var processedItemsCount = 0

        let startTime = CFAbsoluteTimeGetCurrent()
        var recentBytes: [(time: CFAbsoluteTime, bytes: Int64)] = [(startTime, 0)]

        for source in sourceURLs {
            if progress.isCancelled { break }

            let target = destinationFolder.appendingPathComponent(source.lastPathComponent)
            var finalDestination = target

            // Conflict Check
            if fm.fileExists(atPath: target.path) {
                let resolution = await conflictResolution(source, target)
                switch resolution {
                case .skip:
                    continue
                case .replace:
                    try? fm.removeItem(at: target)
                    finalDestination = target
                case .keepBoth:
                    finalDestination = generateUniqueURL(for: target, in: destinationFolder)
                }
            }

            let sourceValues = try? source.resourceValues(forKeys: [.volumeIdentifierKey, .isDirectoryKey])
            let destValues = try? destinationFolder.resourceValues(forKeys: [.volumeIdentifierKey])
            let isSameVolume = (sourceValues?.volumeIdentifier != nil &&
                                destValues?.volumeIdentifier != nil &&
                                sourceValues?.volumeIdentifier?.isEqual(destValues?.volumeIdentifier) == true)
            let isDir = (sourceValues?.isDirectory == true) && !source.pathExtension.elementsEqual("app")

            // If Cut on the SAME volume, moveItem/rename is instant (<10ms)
            if isCut && isSameVolume {
                await MainActor.run {
                    progress.currentItemName = source.lastPathComponent
                }
                try fm.moveItem(at: source, to: finalDestination)
                processedResults.append(finalDestination)
                processedItemsCount += 1
                let fileSize = Int64((try? finalDestination.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0)
                completedBytesTotal += fileSize
                let countSnapshot = processedItemsCount
                let bytesSnapshot = completedBytesTotal
                await MainActor.run {
                    progress.processedItems = countSnapshot
                    progress.completedBytes = min(progress.totalBytes, bytesSnapshot)
                }
                continue
            }

            // Copy file or directory with streaming progress
            if isDir {
                try await copyDirectory(
                    from: source,
                    to: finalDestination,
                    progress: progress,
                    completedBytesTotal: &completedBytesTotal,
                    processedItemsCount: &processedItemsCount,
                    recentBytes: &recentBytes
                )
            } else {
                try await copySingleFile(
                    from: source,
                    to: finalDestination,
                    progress: progress,
                    completedBytesTotal: &completedBytesTotal,
                    processedItemsCount: &processedItemsCount,
                    recentBytes: &recentBytes
                )
            }

            // If Cut across volumes, remove source after successful copy
            if isCut {
                try? fm.removeItem(at: source)
            }

            processedResults.append(finalDestination)
        }

        await MainActor.run {
            progress.completedBytes = progress.totalBytes
            progress.processedItems = progress.totalItems
            progress.isCompleted = true
        }

        return processedResults
    }

    private func copySingleFile(
        from source: URL,
        to destination: URL,
        progress: TransferProgressState,
        completedBytesTotal: inout Int64,
        processedItemsCount: inout Int,
        recentBytes: inout [(time: CFAbsoluteTime, bytes: Int64)]
    ) async throws {
        let fm = FileManager.default
        let fileName = source.lastPathComponent

        await MainActor.run {
            progress.currentItemName = fileName
        }

        let sourceValues = try? source.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        let fileSize = Int64(sourceValues?.fileSize ?? 0)

        // For very small files (less than 1MB), use standard copyItem
        if fileSize < 1024 * 1024 {
            if fm.fileExists(atPath: destination.path) {
                try? fm.removeItem(at: destination)
            }
            try fm.copyItem(at: source, to: destination)
            completedBytesTotal += fileSize
            processedItemsCount += 1

            let bytesSnapshot = completedBytesTotal
            let itemsSnapshot = processedItemsCount
            await MainActor.run {
                progress.completedBytes = min(progress.totalBytes, bytesSnapshot)
                progress.processedItems = itemsSnapshot
            }
            return
        }

        // Chunked file stream
        guard let readHandle = try? FileHandle(forReadingFrom: source) else {
            try fm.copyItem(at: source, to: destination)
            completedBytesTotal += fileSize
            processedItemsCount += 1
            let bytesSnapshot = completedBytesTotal
            let itemsSnapshot = processedItemsCount
            await MainActor.run {
                progress.completedBytes = min(progress.totalBytes, bytesSnapshot)
                progress.processedItems = itemsSnapshot
            }
            return
        }
        defer { try? readHandle.close() }

        if fm.fileExists(atPath: destination.path) {
            try? fm.removeItem(at: destination)
        }
        fm.createFile(atPath: destination.path, contents: nil, attributes: nil)

        guard let writeHandle = try? FileHandle(forWritingTo: destination) else {
            try? readHandle.close()
            try fm.copyItem(at: source, to: destination)
            completedBytesTotal += fileSize
            processedItemsCount += 1
            let bytesSnapshot = completedBytesTotal
            let itemsSnapshot = processedItemsCount
            await MainActor.run {
                progress.completedBytes = min(progress.totalBytes, bytesSnapshot)
                progress.processedItems = itemsSnapshot
            }
            return
        }

        var isAborted = false

        while true {
            if progress.isCancelled {
                isAborted = true
                break
            }

            let data = readHandle.readData(ofLength: bufferSize)
            if data.isEmpty {
                break
            }

            writeHandle.write(data)
            completedBytesTotal += Int64(data.count)

            let now = CFAbsoluteTimeGetCurrent()
            recentBytes.append((now, completedBytesTotal))
            recentBytes.removeAll(where: { now - $0.time > 2.0 })

            var speed: Double = 0
            if recentBytes.count >= 2, let first = recentBytes.first {
                let dt = now - first.time
                let db = completedBytesTotal - first.bytes
                if dt > 0.1 {
                    speed = Double(db) / dt
                }
            }

            let remainingBytes = max(0, progress.totalBytes - completedBytesTotal)
            let eta = speed > 0 ? (Double(remainingBytes) / speed) : 0
            let bytesSnapshot = completedBytesTotal
            let speedSnapshot = speed
            let etaSnapshot = eta

            await MainActor.run {
                progress.completedBytes = min(progress.totalBytes, bytesSnapshot)
                if speedSnapshot > 0 {
                    progress.bytesPerSecond = speedSnapshot
                    progress.estimatedSecondsRemaining = etaSnapshot
                }
            }
        }

        try? writeHandle.close()

        if isAborted {
            try? fm.removeItem(at: destination)
            throw CancellationError()
        }

        // Preserve modification date
        if let modDate = sourceValues?.contentModificationDate {
            try? fm.setAttributes([.modificationDate: modDate], ofItemAtPath: destination.path)
        }

        processedItemsCount += 1
        let finalItemsSnapshot = processedItemsCount
        await MainActor.run {
            progress.processedItems = finalItemsSnapshot
        }
    }

    private func copyDirectory(
        from source: URL,
        to destination: URL,
        progress: TransferProgressState,
        completedBytesTotal: inout Int64,
        processedItemsCount: inout Int,
        recentBytes: inout [(time: CFAbsoluteTime, bytes: Int64)]
    ) async throws {
        let fm = FileManager.default

        if !fm.fileExists(atPath: destination.path) {
            try fm.createDirectory(at: destination, withIntermediateDirectories: true, attributes: nil)
        }

        processedItemsCount += 1
        let dirItemsSnapshot = processedItemsCount
        let dirNameSnapshot = source.lastPathComponent
        await MainActor.run {
            progress.processedItems = dirItemsSnapshot
            progress.currentItemName = dirNameSnapshot
        }

        let contents = (try? fm.contentsOfDirectory(at: source, includingPropertiesForKeys: [.isDirectoryKey], options: [])) ?? []

        for item in contents {
            if progress.isCancelled { throw CancellationError() }

            let targetItem = destination.appendingPathComponent(item.lastPathComponent)
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: item.path, isDirectory: &isDir) {
                if isDir.boolValue && !item.pathExtension.elementsEqual("app") {
                    try await copyDirectory(
                        from: item,
                        to: targetItem,
                        progress: progress,
                        completedBytesTotal: &completedBytesTotal,
                        processedItemsCount: &processedItemsCount,
                        recentBytes: &recentBytes
                    )
                } else {
                    try await copySingleFile(
                        from: item,
                        to: targetItem,
                        progress: progress,
                        completedBytesTotal: &completedBytesTotal,
                        processedItemsCount: &processedItemsCount,
                        recentBytes: &recentBytes
                    )
                }
            }
        }
    }

    private func generateUniqueURL(for target: URL, in folder: URL) -> URL {
        let fm = FileManager.default
        let baseName = target.deletingPathExtension().lastPathComponent
        let ext = target.pathExtension
        var counter = 1
        var candidate = target

        while fm.fileExists(atPath: candidate.path) {
            let newName = ext.isEmpty ? "\(baseName) (\(counter))" : "\(baseName) (\(counter)).\(ext)"
            candidate = folder.appendingPathComponent(newName)
            counter += 1
        }
        return candidate
    }
}
