import Foundation
import SwiftUI
import AppKit

/// Asynchronously loaded file thumbnail with caching and fallback
public struct FileThumbnailView: View {
    public let item: FileItem
    public let size: CGFloat
    @State private var image: NSImage?

    public init(item: FileItem, size: CGFloat) {
        self.item = item
        self.size = size
    }

    public var body: some View {
        ZStack(alignment: .bottomLeading) {
            Image(nsImage: image ?? item.systemIcon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)

            if item.isSymlink {
                Image(systemName: "arrow.up.right.square.fill")
                    .font(.system(size: max(10, size * 0.2)))
                    .foregroundColor(.accentColor)
                    .background(Color.white.clipShape(Circle()))
            }
        }
        .task(id: item.url) {
            // Check memory cache synchronously first
            if let cached = await ThumbnailCacheService.shared.cachedImage(for: item, size: size) {
                self.image = cached
                return
            }
            self.image = nil
            let thumb = await ThumbnailCacheService.shared.thumbnail(for: item, size: size)
            if !Task.isCancelled {
                self.image = thumb
            }
        }
    }
}
