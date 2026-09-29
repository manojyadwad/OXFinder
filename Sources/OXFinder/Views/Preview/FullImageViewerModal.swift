import SwiftUI
import AppKit

/// Dedicated full-featured in-app image viewer with pan, zoom (including scroll wheel & pinch), arrow-cycling,
/// lossless rotation, Delete functionality, and authentic Windows Minimize, Maximize/Restore, and Close caption controls.
public struct FullImageViewerModal: View {
    @ObservedObject var appState: AppState
    let item: FileItem

    @State private var isMaximized: Bool = false
    @State private var zoomScale: CGFloat = 1.0
    @State private var dragOffset: CGSize = .zero
    @State private var accumulatedOffset: CGSize = .zero
    @State private var displayedImage: NSImage?
    @State private var currentItem: FileItem
    @State private var showDeleteConfirmation: Bool = false

    public init(appState: AppState, item: FileItem) {
        self.appState = appState
        self.item = item
        self._currentItem = State(initialValue: item)
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Semi-transparent dark background backdrop
                Color.black.opacity(isMaximized ? 1.0 : 0.7)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        if !isMaximized {
                            appState.viewerItem = nil
                        }
                    }

                // Viewer Window Container
                VStack(spacing: 0) {
                    // Windows Title Bar with Controls
                    windowsTitleBar

                    // Main Image Canvas
                    imageCanvas
                }
                .background(Color(red: 24/255, green: 24/255, blue: 27/255))
                .clipShape(RoundedRectangle(cornerRadius: isMaximized ? 0 : 10))
                .overlay(
                    RoundedRectangle(cornerRadius: isMaximized ? 0 : 10)
                        .stroke(Color.white.opacity(0.15), lineWidth: isMaximized ? 0 : 1)
                )
                .shadow(color: isMaximized ? .clear : Color.black.opacity(0.6), radius: 25, x: 0, y: 12)
                .frame(
                    width: isMaximized ? geometry.size.width : min(max(750, geometry.size.width - 80), 1100),
                    height: isMaximized ? geometry.size.height : min(max(550, geometry.size.height - 60), 800)
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            loadImage(for: currentItem)
        }
        // Keyboard shortcuts, mouse scroll wheel zoom, and trackpad pinch
        .background(
            ViewerInteractionHandlerView(
                onLeftArrow: { previousImage() },
                onRightArrow: { nextImage() },
                onEscape: { appState.viewerItem = nil },
                onDelete: { showDeleteConfirmation = true },
                onScrollWheel: { delta, isPrecise in
                    handleScrollZoom(delta: delta, isPrecise: isPrecise)
                },
                onMagnify: { magnification in
                    handlePinchZoom(magnification: magnification)
                }
            )
        )
        // Confirmation alert for Delete
        .alert("Delete Image", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Move to Trash", role: .destructive) {
                deleteCurrentImage()
            }
        } message: {
            Text("Are you sure you want to move \"\(currentItem.name)\" to Trash?")
        }
    }

    // MARK: - Windows Title Bar & Controls

    private var windowsTitleBar: some View {
        HStack(spacing: 0) {
            // Left: Icon + File Name + Counter
            HStack(spacing: 8) {
                Image(systemName: "photo.fill")
                    .foregroundColor(.accentColor)
                    .font(.system(size: 13))

                Text(currentItem.displayName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .frame(maxWidth: 240, alignment: .leading)

                if !imageCounterText.isEmpty {
                    Text(imageCounterText)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(4)
                }
            }
            .padding(.leading, 12)

            Spacer()

            // Center Toolbar: Zoom, Rotate, Delete
            HStack(spacing: 6) {
                // Zoom Controls
                Button(action: { zoomOut() }) {
                    Image(systemName: "minus.magnifyingglass")
                }
                .buttonStyle(ViewerToolbarButtonStyle())
                .help("Zoom out (- / Scroll down)")

                Text("\(Int(zoomScale * 100))%")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.white)
                    .frame(width: 44)

                Button(action: { zoomIn() }) {
                    Image(systemName: "plus.magnifyingglass")
                }
                .buttonStyle(ViewerToolbarButtonStyle())
                .help("Zoom in (+ / Scroll up)")

                Button("1:1") {
                    withAnimation {
                        zoomScale = 1.0
                        accumulatedOffset = .zero
                        dragOffset = .zero
                    }
                }
                .buttonStyle(ViewerToolbarButtonStyle())
                .help("Actual size (1:1)")

                Button("Fit") {
                    withAnimation {
                        zoomScale = 1.0
                        accumulatedOffset = .zero
                        dragOffset = .zero
                    }
                }
                .buttonStyle(ViewerToolbarButtonStyle())
                .help("Fit to window")

                Divider()
                    .frame(height: 16)
                    .background(Color.white.opacity(0.25))

                // Rotation Controls
                Button(action: { rotate(clockwise: false) }) {
                    Image(systemName: "rotate.left")
                }
                .buttonStyle(ViewerToolbarButtonStyle())
                .help("Rotate 90° CCW")

                Button(action: { rotate(clockwise: true) }) {
                    Image(systemName: "rotate.right")
                }
                .buttonStyle(ViewerToolbarButtonStyle())
                .help("Rotate 90° CW")

                Divider()
                    .frame(height: 16)
                    .background(Color.white.opacity(0.25))

                // Delete Button
                Button(action: {
                    showDeleteConfirmation = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                        Text("Delete")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(Color(red: 255/255, green: 100/255, blue: 100/255))
                }
                .buttonStyle(ViewerToolbarButtonStyle())
                .help("Move image to Trash (Delete)")
            }

            Spacer()

            // Right: Authentic Windows Caption Buttons (Minimize, Maximize/Restore, Close)
            HStack(spacing: 0) {
                // Minimize Button
                WindowsCaptionButton(
                    type: .minimize,
                    action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            appState.viewerItem = nil
                        }
                    }
                )

                // Maximize / Restore Button
                WindowsCaptionButton(
                    type: isMaximized ? .restore : .maximize,
                    action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                            isMaximized.toggle()
                        }
                    }
                )

                // Close Button
                WindowsCaptionButton(
                    type: .close,
                    action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            appState.viewerItem = nil
                        }
                    }
                )
            }
        }
        .frame(height: 38)
        .background(Color(red: 32/255, green: 32/255, blue: 36/255))
        .overlay(
            Divider().background(Color.white.opacity(0.1)),
            alignment: .bottom
        )
    }

    // MARK: - Main Image Canvas

    private var imageCanvas: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)

            if let img = displayedImage {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(zoomScale)
                    .offset(
                        x: accumulatedOffset.width + dragOffset.width,
                        y: accumulatedOffset.height + dragOffset.height
                    )
                    .gesture(
                        DragGesture()
                            .onChanged { val in
                                if zoomScale > 1.0 {
                                    dragOffset = val.translation
                                }
                            }
                            .onEnded { val in
                                if zoomScale > 1.0 {
                                    accumulatedOffset.width += val.translation.width
                                    accumulatedOffset.height += val.translation.height
                                    dragOffset = .zero
                                }
                            }
                    )
                    .onTapGesture(count: 2) {
                        withAnimation {
                            if zoomScale > 1.0 {
                                zoomScale = 1.0
                                accumulatedOffset = .zero
                                dragOffset = .zero
                            } else {
                                zoomScale = 2.0
                            }
                        }
                    }
            } else {
                ProgressView()
                    .colorScheme(.dark)
            }

            // Navigation Arrows Overlay
            HStack {
                Button(action: { previousImage() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white.opacity(hasPrevious ? 0.85 : 0.2))
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Color.black.opacity(0.5)))
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(!hasPrevious)
                .padding(.leading, 16)
                .help("Previous image (Left Arrow)")

                Spacer()

                Button(action: { nextImage() }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white.opacity(hasNext ? 0.85 : 0.2))
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Color.black.opacity(0.5)))
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(!hasNext)
                .padding(.trailing, 16)
                .help("Next image (Right Arrow)")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Scroll Wheel & Pinch Zoom Logic

    private func handleScrollZoom(delta: CGFloat, isPrecise: Bool) {
        guard displayedImage != nil else { return }
        guard abs(delta) > 0.001 else { return }

        // Scale proportionally based on device (notched wheel vs trackpad)
        let rate: CGFloat = isPrecise ? 0.004 : 0.09
        let multiplier = 1.0 + (delta * rate)
        let newScale = min(max(zoomScale * multiplier, 0.2), 8.0)

        withAnimation(.easeOut(duration: 0.08)) {
            zoomScale = newScale
            // If zooming back to 1.0 or below, smoothly reset pan offsets
            if newScale <= 1.05 && delta < 0 {
                accumulatedOffset = .zero
                dragOffset = .zero
            }
        }
    }

    private func handlePinchZoom(magnification: CGFloat) {
        guard displayedImage != nil else { return }
        let newScale = min(max(zoomScale * (1.0 + magnification), 0.2), 8.0)
        zoomScale = newScale
        if newScale <= 1.0 {
            accumulatedOffset = .zero
            dragOffset = .zero
        }
    }

    // MARK: - Navigation Between Images

    private var allImagesInDirectory: [FileItem] {
        appState.currentItems.filter { $0.isImage }
    }

    private var currentIndex: Int {
        allImagesInDirectory.firstIndex(where: { $0.url == currentItem.url }) ?? 0
    }

    private var hasPrevious: Bool {
        currentIndex > 0
    }

    private var hasNext: Bool {
        currentIndex < allImagesInDirectory.count - 1
    }

    private var imageCounterText: String {
        let total = allImagesInDirectory.count
        guard total > 0 else { return "" }
        return "\(currentIndex + 1) of \(total)"
    }

    private func nextImage() {
        guard hasNext else { return }
        let next = allImagesInDirectory[currentIndex + 1]
        switchImage(to: next)
    }

    private func previousImage() {
        guard hasPrevious else { return }
        let prev = allImagesInDirectory[currentIndex - 1]
        switchImage(to: prev)
    }

    private func switchImage(to newItem: FileItem) {
        withAnimation {
            currentItem = newItem
            zoomScale = 1.0
            accumulatedOffset = .zero
            dragOffset = .zero
        }
        loadImage(for: newItem)
    }

    private func loadImage(for fileItem: FileItem) {
        DispatchQueue.global(qos: .userInitiated).async {
            let img = NSImage(contentsOf: fileItem.url)
            DispatchQueue.main.async {
                self.displayedImage = img
            }
        }
    }

    // MARK: - Delete Current Image

    private func deleteCurrentImage() {
        let targetURL = currentItem.url
        let images = allImagesInDirectory
        let remaining = images.filter { $0.url != targetURL }

        // Find candidate to show next after delete
        let nextCandidate: FileItem?
        if let idx = images.firstIndex(where: { $0.url == targetURL }) {
            if idx + 1 < images.count {
                nextCandidate = images[idx + 1]
            } else if idx - 1 >= 0 {
                nextCandidate = images[idx - 1]
            } else {
                nextCandidate = nil
            }
        } else {
            nextCandidate = remaining.first
        }

        Task {
            do {
                try await FileSystemManager.shared.moveToTrash(urls: [targetURL])
                await MainActor.run {
                    appState.loadCurrentDirectory()
                    if let next = nextCandidate {
                        switchImage(to: next)
                    } else {
                        // No more images in directory, close viewer cleanly
                        appState.viewerItem = nil
                    }
                }
            } catch {
                print("Failed to delete image: \(error)")
            }
        }
    }

    // MARK: - Zooming & Rotation

    private func zoomIn() {
        withAnimation {
            zoomScale = min(8.0, zoomScale + 0.25)
        }
    }

    private func zoomOut() {
        withAnimation {
            zoomScale = max(0.2, zoomScale - 0.25)
            if zoomScale <= 1.0 {
                accumulatedOffset = .zero
                dragOffset = .zero
            }
        }
    }

    private func rotate(clockwise: Bool) {
        do {
            try MetadataExtractor.shared.rotateImage(at: currentItem.url, clockwise: clockwise)
            loadImage(for: currentItem)
            appState.loadCurrentDirectory()
        } catch {
            print("Failed to rotate image: \(error)")
        }
    }
}

// MARK: - Windows Caption Buttons (Minimize, Maximize, Restore, Close)

public enum WindowsCaptionButtonType {
    case minimize
    case maximize
    case restore
    case close
}

struct WindowsCaptionButton: View {
    let type: WindowsCaptionButtonType
    let action: () -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        Button(action: action) {
            ZStack {
                // Background on hover
                if isHovered {
                    if type == .close {
                        Color(red: 232/255, green: 17/255, blue: 35/255) // Signature Windows Red
                    } else {
                        Color.white.opacity(0.12)
                    }
                } else {
                    Color.clear
                }

                // Icon
                switch type {
                case .minimize:
                    Rectangle()
                        .fill(Color.white.opacity(isHovered ? 1.0 : 0.8))
                        .frame(width: 10, height: 1.2)
                case .maximize:
                    RoundedRectangle(cornerRadius: 1)
                        .stroke(Color.white.opacity(isHovered ? 1.0 : 0.8), lineWidth: 1.2)
                        .frame(width: 10, height: 10)
                case .restore:
                    ZStack(alignment: .topTrailing) {
                        // Background square
                        RoundedRectangle(cornerRadius: 1)
                            .stroke(Color.white.opacity(isHovered ? 1.0 : 0.8), lineWidth: 1.2)
                            .frame(width: 8, height: 8)
                            .offset(x: 2, y: -2)

                        // Foreground square
                        RoundedRectangle(cornerRadius: 1)
                            .stroke(Color.white.opacity(isHovered ? 1.0 : 0.8), lineWidth: 1.2)
                            .background(Color(red: 32/255, green: 32/255, blue: 36/255))
                            .frame(width: 8, height: 8)
                    }
                    .frame(width: 12, height: 12)
                case .close:
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(isHovered ? .white : .white.opacity(0.8))
                }
            }
            .frame(width: 46, height: 38)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            isHovered = hovering
        }
        .help(tooltipText)
    }

    private var tooltipText: String {
        switch type {
        case .minimize: return "Minimize"
        case .maximize: return "Maximize"
        case .restore: return "Restore down"
        case .close: return "Close (Esc)"
        }
    }
}

// MARK: - Viewer Toolbar Button Style

struct ViewerToolbarButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.white.opacity(configuration.isPressed ? 0.3 : 0.12))
            .cornerRadius(4)
    }
}

// MARK: - Viewer Interaction (Keyboard, Scroll Wheel, Pinch)

struct ViewerInteractionHandlerView: NSViewRepresentable {
    let onLeftArrow: () -> Void
    let onRightArrow: () -> Void
    let onEscape: () -> Void
    let onDelete: () -> Void
    let onScrollWheel: (CGFloat, Bool) -> Void
    let onMagnify: (CGFloat) -> Void

    func makeNSView(context: Context) -> InteractionView {
        let view = InteractionView()
        view.onLeftArrow = onLeftArrow
        view.onRightArrow = onRightArrow
        view.onEscape = onEscape
        view.onDelete = onDelete
        view.onScrollWheel = onScrollWheel
        view.onMagnify = onMagnify
        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }
        return view
    }

    func updateNSView(_ nsView: InteractionView, context: Context) {
        nsView.onLeftArrow = onLeftArrow
        nsView.onRightArrow = onRightArrow
        nsView.onEscape = onEscape
        nsView.onDelete = onDelete
        nsView.onScrollWheel = onScrollWheel
        nsView.onMagnify = onMagnify
    }

    class InteractionView: NSView {
        var onLeftArrow: (() -> Void)?
        var onRightArrow: (() -> Void)?
        var onEscape: (() -> Void)?
        var onDelete: (() -> Void)?
        var onScrollWheel: ((CGFloat, Bool) -> Void)?
        var onMagnify: ((CGFloat) -> Void)?

        private var scrollMonitor: Any?
        private var magnifyMonitor: Any?

        override var acceptsFirstResponder: Bool { true }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()

            // Remove existing monitors if any
            if let sm = scrollMonitor {
                NSEvent.removeMonitor(sm)
                scrollMonitor = nil
            }
            if let mm = magnifyMonitor {
                NSEvent.removeMonitor(mm)
                magnifyMonitor = nil
            }

            guard let window = self.window else { return }
            window.makeFirstResponder(self)

            // Local event monitor for mouse scroll wheel zooming
            scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                guard let self = self, self.window != nil else { return event }

                let delta = event.hasPreciseScrollingDeltas ? event.scrollingDeltaY : event.deltaY
                if abs(delta) > 0.001 {
                    self.onScrollWheel?(delta, event.hasPreciseScrollingDeltas)
                    return nil // Consume event to prevent outer window bouncing
                }
                return event
            }

            // Local event monitor for trackpad pinch magnification
            magnifyMonitor = NSEvent.addLocalMonitorForEvents(matching: .magnify) { [weak self] event in
                guard let self = self, self.window != nil else { return event }
                self.onMagnify?(event.magnification)
                return nil
            }
        }

        deinit {
            if let sm = scrollMonitor {
                NSEvent.removeMonitor(sm)
            }
            if let mm = magnifyMonitor {
                NSEvent.removeMonitor(mm)
            }
        }

        override func keyDown(with event: NSEvent) {
            switch event.keyCode {
            case 123: // Left Arrow
                onLeftArrow?()
            case 124: // Right Arrow
                onRightArrow?()
            case 53: // Escape
                onEscape?()
            case 51, 117: // Backspace / Delete
                onDelete?()
            default:
                super.keyDown(with: event)
            }
        }
    }
}
