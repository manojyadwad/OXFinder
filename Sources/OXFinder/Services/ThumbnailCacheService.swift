import Foundation
import AppKit
import QuickLookThumbnailing
import CryptoKit

/// Thread-safe actor for two-tiered thumbnail generation and caching (Memory + Disk)
public actor ThumbnailCacheService {
    public static let shared = ThumbnailCacheService()

    private let memoryCache = NSCache<NSString, NSImage>()
    private let diskCacheURL: URL
    private var inFlightKeys: Set<String> = []

    public init() {
        memoryCache.countLimit = 2000
        memoryCache.totalCostLimit = 150 * 1024 * 1024 // 150 MB

        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        self.diskCacheURL = caches.appendingPathComponent("OXFinder/Thumbnails", isDirectory: true)
        try? FileManager.default.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
    }

    /// Fast synchronous memory-cache check
    public func cachedImage(for item: FileItem, size: CGFloat) -> NSImage? {
        let key = cacheKey(for: item, size: size)
        return memoryCache.object(forKey: key as NSString)
    }

    /// Retrieve or generate thumbnail representation for given file item and target pixel size
    public func thumbnail(for item: FileItem, size: CGFloat) async -> NSImage {
        let key = cacheKey(for: item, size: size)

        // 1. Check Memory Cache
        if let cached = memoryCache.object(forKey: key as NSString) {
            return cached
        }

        // 2. Check Disk Cache
        if let diskImg = loadFromDisk(key: key) {
            memoryCache.setObject(diskImg, forKey: key as NSString, cost: Int(size * size * 4))
            return diskImg
        }

        // 3. For images, use ultra-fast native CoreGraphics thumbnail decoding
        if item.isImage {
            let scale = NSScreen.main?.backingScaleFactor ?? 2.0
            let maxPixelSize = max(size * scale, 128)
            if let source = CGImageSourceCreateWithURL(item.url as CFURL, nil) {
                let options: [CFString: Any] = [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceShouldCacheImmediately: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
                ]
                if let cgThumb = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) {
                    let nsImg = NSImage(cgImage: cgThumb, size: NSSize(width: size, height: size))
                    self.memoryCache.setObject(nsImg, forKey: key as NSString, cost: Int(size * size * 4))
                    self.saveToDisk(image: nsImg, key: key)
                    return nsImg
                }
            }
        }

        // 4. Generate using QLThumbnailGenerator with all representation types
        let scale = NSScreen.main?.backingScaleFactor ?? 2.0
        let targetSize = CGSize(width: size, height: size)
        let request = QLThumbnailGenerator.Request(
            fileAt: item.url,
            size: targetSize,
            scale: scale,
            representationTypes: .all
        )

        do {
            let rep = try await QLThumbnailGenerator.shared.generateBestRepresentation(for: request)
            let generatedImg = rep.nsImage

            // Save to memory cache
            self.memoryCache.setObject(generatedImg, forKey: key as NSString, cost: Int(size * size * 4))

            // Save to disk cache
            self.saveToDisk(image: generatedImg, key: key)

            return generatedImg
        } catch {
            return item.systemIcon
        }
    }

    /// Clear memory and disk caches
    public func clearCache() {
        memoryCache.removeAllObjects()
        try? FileManager.default.removeItem(at: diskCacheURL)
        try? FileManager.default.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
    }

    // MARK: - Private Helpers

    private func cacheKey(for item: FileItem, size: CGFloat) -> String {
        let modTime = item.dateModified?.timeIntervalSince1970 ?? 0
        let raw = "\(item.url.path)_\(modTime)_\(Int(size))"
        let hash = SHA256.hash(data: Data(raw.utf8))
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    private func diskFileURL(for key: String) -> URL {
        diskCacheURL.appendingPathComponent("\(key).tiff")
    }

    private func loadFromDisk(key: String) -> NSImage? {
        let fileURL = diskFileURL(for: key)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return NSImage(data: data)
    }

    private func saveToDisk(image: NSImage, key: String) {
        guard let tiffData = image.tiffRepresentation else { return }
        let fileURL = self.diskFileURL(for: key)
        try? tiffData.write(to: fileURL, options: .atomic)
    }
}
