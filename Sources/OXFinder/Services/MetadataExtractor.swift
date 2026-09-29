import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

/// Structured metadata details for preview and inspection
public struct FileDetailedMetadata: Sendable {
    public let dimensions: CGSize?
    public let colorSpace: String?
    public let cameraMake: String?
    public let cameraModel: String?
    public let lensModel: String?
    public let iso: Int?
    public let fNumber: Double?
    public let exposureTime: String?
    public let focalLength: Double?
    public let dateTaken: String?
    public let posixPermissions: String?
    public let ownerAccount: String?
    public let uti: String?
}

/// Service for extracting rich EXIF, graphic, and file system metadata
public final class MetadataExtractor: Sendable {
    public static let shared = MetadataExtractor()

    public init() {}

    /// Extract detailed metadata for the specified file
    public func extractMetadata(for url: URL) -> FileDetailedMetadata {
        var dimensions: CGSize? = nil
        var colorSpace: String? = nil
        var cameraMake: String? = nil
        var cameraModel: String? = nil
        var lensModel: String? = nil
        var iso: Int? = nil
        var fNumber: Double? = nil
        var exposureTime: String? = nil
        var focalLength: Double? = nil
        var dateTaken: String? = nil

        // 1. Image EXIF & Properties
        if let source = CGImageSourceCreateWithURL(url as CFURL, nil),
           let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] {

            if let width = props[kCGImagePropertyPixelWidth] as? CGFloat,
               let height = props[kCGImagePropertyPixelHeight] as? CGFloat {
                dimensions = CGSize(width: width, height: height)
            }

            colorSpace = props[kCGImagePropertyColorModel] as? String

            if let exif = props[kCGImagePropertyExifDictionary] as? [CFString: Any] {
                if let isoArr = exif[kCGImagePropertyExifISOSpeedRatings] as? [Int], let firstIso = isoArr.first {
                    iso = firstIso
                }
                fNumber = exif[kCGImagePropertyExifFNumber] as? Double
                focalLength = exif[kCGImagePropertyExifFocalLength] as? Double
                lensModel = exif[kCGImagePropertyExifLensModel] as? String
                dateTaken = exif[kCGImagePropertyExifDateTimeOriginal] as? String

                if let exp = exif[kCGImagePropertyExifExposureTime] as? Double {
                    if exp < 1.0 && exp > 0 {
                        let denom = Int(round(1.0 / exp))
                        exposureTime = "1/\(denom) s"
                    } else {
                        exposureTime = String(format: "%.2f s", exp)
                    }
                }
            }

            if let tiff = props[kCGImagePropertyTIFFDictionary] as? [CFString: Any] {
                cameraMake = tiff[kCGImagePropertyTIFFMake] as? String
                cameraModel = tiff[kCGImagePropertyTIFFModel] as? String
            }
        }

        // 2. POSIX Permissions & System attributes
        let path = url.path
        let attrs = (try? FileManager.default.attributesOfItem(atPath: path)) ?? [:]
        let owner = attrs[.ownerAccountName] as? String
        let posixNumber = attrs[.posixPermissions] as? NSNumber
        let posixString = posixNumber != nil ? String(format: "%o", posixNumber!.intValue) : nil

        let uti = (try? url.resourceValues(forKeys: [.contentTypeKey]))?.contentType?.identifier

        return FileDetailedMetadata(
            dimensions: dimensions,
            colorSpace: colorSpace,
            cameraMake: cameraMake,
            cameraModel: cameraModel,
            lensModel: lensModel,
            iso: iso,
            fNumber: fNumber,
            exposureTime: exposureTime,
            focalLength: focalLength,
            dateTaken: dateTaken,
            posixPermissions: posixString,
            ownerAccount: owner,
            uti: uti
        )
    }

    /// Rotate image 90 degrees clockwise or counter-clockwise
    public func rotateImage(at url: URL, clockwise: Bool) throws {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            throw NSError(domain: "MetadataExtractor", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to read image"])
        }

        guard let type = CGImageSourceGetType(source) else {
            throw NSError(domain: "MetadataExtractor", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unknown image type"])
        }

        guard let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw NSError(domain: "MetadataExtractor", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to decode image"])
        }

        let newWidth = image.height
        let newHeight = image.width
        let bitsPerComponent = image.bitsPerComponent
        let bytesPerRow = 0
        let colorSpace = image.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!
        let bitmapInfo = image.bitmapInfo.rawValue

        guard let context = CGContext(
            data: nil,
            width: newWidth,
            height: newHeight,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            throw NSError(domain: "MetadataExtractor", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to create context"])
        }

        if clockwise {
            context.translateBy(x: CGFloat(newWidth), y: 0)
            context.rotate(by: .pi / 2.0)
        } else {
            context.translateBy(x: 0, y: CGFloat(newHeight))
            context.rotate(by: -.pi / 2.0)
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))

        guard let rotatedImage = context.makeImage() else {
            throw NSError(domain: "MetadataExtractor", code: 5, userInfo: [NSLocalizedDescriptionKey: "Failed to make rotated image"])
        }

        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, type, 1, nil) else {
            throw NSError(domain: "MetadataExtractor", code: 6, userInfo: [NSLocalizedDescriptionKey: "Failed to create destination"])
        }

        CGImageDestinationAddImage(destination, rotatedImage, nil)
        if !CGImageDestinationFinalize(destination) {
            throw NSError(domain: "MetadataExtractor", code: 7, userInfo: [NSLocalizedDescriptionKey: "Failed to save rotated image"])
        }
    }
}
