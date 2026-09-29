import SwiftUI
import AppKit

/// Interactive resizable split divider with hover cursor, drag gesture, and double-click reset
public struct SplitDividerView: View {
    @Binding var width: CGFloat
    let minWidth: CGFloat
    let maxWidth: CGFloat
    let defaultWidth: CGFloat
    let invertDelta: Bool

    @State private var isHovered: Bool = false
    @State private var isDragging: Bool = false
    @State private var dragStartWidth: CGFloat = 0

    public init(
        width: Binding<CGFloat>,
        minWidth: CGFloat = 160,
        maxWidth: CGFloat = 400,
        defaultWidth: CGFloat = 220,
        invertDelta: Bool = false
    ) {
        self._width = width
        self.minWidth = minWidth
        self.maxWidth = maxWidth
        self.defaultWidth = defaultWidth
        self.invertDelta = invertDelta
    }

    public var body: some View {
        ZStack {
            Rectangle()
                .fill(isHovered || isDragging ? Color.accentColor.opacity(0.3) : Color.clear)
                .frame(width: 6)

            Rectangle()
                .fill(Color(nsColor: .separatorColor))
                .frame(width: 1)
        }
        .frame(width: 6)
        .frame(maxHeight: .infinity)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
            if hovering {
                NSCursor.resizeLeftRight.push()
            } else {
                NSCursor.pop()
            }
        }
        .gesture(
            DragGesture(minimumDistance: 1)
                .onChanged { gesture in
                    if !isDragging {
                        isDragging = true
                        dragStartWidth = width
                    }
                    let delta = invertDelta ? -gesture.translation.width : gesture.translation.width
                    let target = dragStartWidth + delta
                    width = min(max(target, minWidth), maxWidth)
                }
                .onEnded { _ in
                    isDragging = false
                }
        )
        .onTapGesture(count: 2) {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                width = defaultWidth
            }
        }
    }
}
