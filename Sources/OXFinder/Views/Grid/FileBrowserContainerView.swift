import SwiftUI
import AppKit

/// Container view routing between Details Table and Multi-size Grid, managing shortcuts and drops
public struct FileBrowserContainerView: View {
    @ObservedObject var appState: AppState

    public var body: some View {
        ZStack {
            if appState.isLoading && appState.currentItems.isEmpty {
                ProgressView("Loading directory...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if appState.currentItems.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "folder")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("This folder is empty.")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .contextMenu {
                    EmptyCanvasContextMenuView(appState: appState)
                }
            } else {
                switch appState.activeTab.viewMode {
                case .details:
                    DetailsTableView(appState: appState)
                case .list, .smallIcons, .mediumIcons, .largeIcons, .extraLargeIcons:
                    IconGridView(appState: appState, viewMode: appState.activeTab.viewMode)
                }
            }
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleDrop(providers: providers)
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
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
                        into: self.appState.activeTab.currentURL,
                        isCut: false,
                        conflictResolution: { source, target in
                            await self.appState.promptConflictResolution(source: source, target: target)
                        }
                    )
                    self.appState.loadCurrentDirectory()
                } catch {
                    print("Error dropping files: \(error)")
                }
            }
        }
        return true
    }
}
