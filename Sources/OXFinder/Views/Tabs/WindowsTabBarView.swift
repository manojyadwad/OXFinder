import SwiftUI
import AppKit

/// Windows 11 style Tab Bar supporting drag-reordering, drop-files-to-tab, add/close
public struct WindowsTabBarView: View {
    @ObservedObject var appState: AppState
    @State private var draggedTab: TabItem?

    public var body: some View {
        HStack(spacing: 2) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(Array(appState.tabs.enumerated()), id: \.element.id) { index, tab in
                        tabHeader(tab: tab, index: index)
                    }
                }
                .padding(.horizontal, 4)
            }

            // New Tab Button (+)
            Button(action: {
                appState.addTab()
            }) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)
                    .frame(width: 26, height: 26)
                    .background(Color.secondary.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.trailing, 8)
            .help("New tab (Cmd+T)")

            Spacer()
        }
        .frame(height: 36)
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(
            Divider(), alignment: .bottom
        )
    }

    private func tabHeader(tab: TabItem, index: Int) -> some View {
        let isActive = appState.activeTabId == tab.id

        return HStack(spacing: 6) {
            Image(systemName: "folder.fill")
                .foregroundColor(isActive ? .accentColor : .secondary)
                .font(.system(size: 12))

            Text(tab.title)
                .font(.system(size: 12, weight: isActive ? .medium : .regular))
                .foregroundColor(isActive ? .primary : .secondary)
                .lineLimit(1)
                .frame(maxWidth: 160)

            // Close Tab Button (x)
            if appState.tabs.count > 1 {
                Button(action: {
                    appState.closeTab(id: tab.id)
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(isActive ? .secondary : .secondary.opacity(0.6))
                        .frame(width: 16, height: 16)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
                .help("Close tab (Cmd+W)")
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isActive ? Color(nsColor: .controlBackgroundColor) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isActive ? Color.secondary.opacity(0.2) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            appState.selectTab(id: tab.id)
        }
        // Tab drag-to-reorder
        .onDrag {
            self.draggedTab = tab
            return NSItemProvider(object: tab.id.uuidString as NSString)
        }
        // Drop files onto tab header to copy/move into tab's directory
        .onDrop(of: [.fileURL, .text], isTargeted: nil) { providers in
            return handleDropOnTab(providers: providers, targetTab: tab, targetIndex: index)
        }
    }

    private func handleDropOnTab(providers: [NSItemProvider], targetTab: TabItem, targetIndex: Int) -> Bool {
        // If reordering tabs
        if let dragged = draggedTab, let sourceIndex = appState.tabs.firstIndex(where: { $0.id == dragged.id }) {
            appState.moveTab(fromIndex: sourceIndex, toIndex: targetIndex)
            self.draggedTab = nil
            return true
        }

        // If dropping files to copy into target tab
        var droppedURLs: [URL] = []
        let group = DispatchGroup()

        for provider in providers {
            group.enter()
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let u = url {
                    droppedURLs.append(u)
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            guard !droppedURLs.isEmpty else { return }
            Task {
                do {
                    _ = try await FileSystemManager.shared.paste(
                        sourceURLs: droppedURLs,
                        into: targetTab.currentURL,
                        isCut: false,
                        conflictResolution: { source, target in
                            await self.appState.promptConflictResolution(source: source, target: target)
                        }
                    )
                    if self.appState.activeTabId == targetTab.id {
                        self.appState.loadCurrentDirectory()
                    }
                } catch {
                    print("Error dropping file onto tab: \(error)")
                }
            }
        }
        return true
    }
}
