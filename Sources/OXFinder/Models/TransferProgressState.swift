import Foundation
import SwiftUI

/// Observable state tracking active file transfer operations (Copy / Cut / Move / Drag-Drop)
public final class TransferProgressState: ObservableObject, Identifiable {
    public let id = UUID()
    public let isCut: Bool
    public let sourceFolderName: String
    public let destinationFolderName: String

    @Published public var title: String
    @Published public var currentItemName: String = ""
    @Published public var processedItems: Int = 0
    @Published public var totalItems: Int = 0
    @Published public var completedBytes: Int64 = 0
    @Published public var totalBytes: Int64 = 0
    @Published public var bytesPerSecond: Double = 0
    @Published public var estimatedSecondsRemaining: Double = 0
    @Published public var isCancelled: Bool = false
    @Published public var isCompleted: Bool = false

    public var fractionCompleted: Double {
        guard totalBytes > 0 else {
            if totalItems > 0 {
                return min(1.0, Double(processedItems) / Double(totalItems))
            }
            return 0.0
        }
        return min(1.0, max(0.0, Double(completedBytes) / Double(totalBytes)))
    }

    public var percentageString: String {
        "\(Int(fractionCompleted * 100))%"
    }

    public var speedFormatted: String {
        guard bytesPerSecond > 0 else { return "Calculating..." }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return "\(formatter.string(fromByteCount: Int64(bytesPerSecond)))/s"
    }

    public var progressBytesFormatted: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        let completed = formatter.string(fromByteCount: completedBytes)
        let total = formatter.string(fromByteCount: totalBytes)
        return "\(completed) of \(total)"
    }

    public var timeRemainingFormatted: String {
        if completedBytes == totalBytes && totalBytes > 0 {
            return "Completing transfer..."
        }
        guard estimatedSecondsRemaining > 0 && bytesPerSecond > 0 else {
            return "Estimating time remaining..."
        }
        if estimatedSecondsRemaining < 5 {
            return "A few seconds remaining"
        } else if estimatedSecondsRemaining < 60 {
            return "About \(Int(ceil(estimatedSecondsRemaining))) seconds remaining"
        } else if estimatedSecondsRemaining < 3600 {
            let mins = Int(ceil(estimatedSecondsRemaining / 60))
            return "About \(mins) minute\(mins == 1 ? "" : "s") remaining"
        } else {
            let hours = Int(estimatedSecondsRemaining / 3600)
            let mins = Int((estimatedSecondsRemaining.truncatingRemainder(dividingBy: 3600)) / 60)
            return "About \(hours) hour\(hours == 1 ? "" : "s") and \(mins) minute\(mins == 1 ? "" : "s") remaining"
        }
    }

    public init(
        isCut: Bool,
        totalItems: Int,
        totalBytes: Int64,
        sourceFolderName: String,
        destinationFolderName: String
    ) {
        self.isCut = isCut
        self.totalItems = totalItems
        self.totalBytes = totalBytes
        self.sourceFolderName = sourceFolderName
        self.destinationFolderName = destinationFolderName
        let count = max(1, totalItems)
        self.title = isCut
            ? "Moving \(count) item\(count == 1 ? "" : "s") to \(destinationFolderName)"
            : "Copying \(count) item\(count == 1 ? "" : "s") to \(destinationFolderName)"
    }
}
