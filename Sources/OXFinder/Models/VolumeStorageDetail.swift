import Foundation

/// Comprehensive volume storage capacity breakdown (Total, Used, Free, File system format, Label)
public struct VolumeStorageDetail: Sendable, Identifiable {
    public var id: String { volumeName }
    public let freeBytes: Int64
    public let usedBytes: Int64
    public let totalBytes: Int64
    public let formatName: String
    public let volumeName: String
    public let isRemovable: Bool

    public init(
        freeBytes: Int64,
        usedBytes: Int64,
        totalBytes: Int64,
        formatName: String,
        volumeName: String,
        isRemovable: Bool
    ) {
        self.freeBytes = freeBytes
        self.usedBytes = usedBytes
        self.totalBytes = totalBytes
        self.formatName = formatName
        self.volumeName = volumeName
        self.isRemovable = isRemovable
    }

    public var usedPercentage: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(usedBytes) / Double(totalBytes)
    }

    public var freePercentage: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(freeBytes) / Double(totalBytes)
    }

    public var freeFormatted: String {
        let f = ByteCountFormatter()
        f.allowedUnits = [.useAll]
        f.countStyle = .file
        return f.string(fromByteCount: freeBytes)
    }

    public var usedFormatted: String {
        let f = ByteCountFormatter()
        f.allowedUnits = [.useAll]
        f.countStyle = .file
        return f.string(fromByteCount: usedBytes)
    }

    public var totalFormatted: String {
        let f = ByteCountFormatter()
        f.allowedUnits = [.useAll]
        f.countStyle = .file
        return f.string(fromByteCount: totalBytes)
    }

    public var freeExactBytesFormatted: String {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        return nf.string(from: NSNumber(value: freeBytes)) ?? "\(freeBytes)"
    }

    public var usedExactBytesFormatted: String {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        return nf.string(from: NSNumber(value: usedBytes)) ?? "\(usedBytes)"
    }

    public var totalExactBytesFormatted: String {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        return nf.string(from: NSNumber(value: totalBytes)) ?? "\(totalBytes)"
    }
}
