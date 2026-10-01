import SwiftUI
import AppKit

/// Windows File Explorer Navigation Pane (Sidebar)
public struct NavigationSidebar: View {
    @ObservedObject var appState: AppState

    public var body: some View {
        VStack(spacing: 0) {
            // App Identity Header
            HStack(spacing: 9) {
                if let logo = AppLogoHelper.logoImage {
                    Image(nsImage: logo)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
                }
                VStack(alignment: .leading, spacing: 0) {
                    Text("OX Finder")
                        .font(.system(size: 13, weight: .bold))
                    Text("File Explorer")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))

            Divider()

            List {
                // Quick Access / Pinned Folders
                Section("Quick access") {
                    ForEach(appState.quickAccessURLs, id: \.self) { url in
                        sidebarItem(
                            url: url,
                            icon: iconName(for: url),
                            title: FileManager.default.displayName(atPath: url.path),
                            badgeIcon: "pin.fill"
                        )
                    }
                }

                // This PC / Storage Volumes
                Section {
                    sidebarItem(
                        url: URL(fileURLWithPath: "/Volumes"),
                        icon: "desktopcomputer",
                        title: "This Mac",
                        badgeIcon: nil
                    )

                    ForEach(appState.mountedVolumes, id: \.self) { volumeURL in
                        volumeSidebarItem(volumeURL: volumeURL)
                    }
                } header: {
                    HStack {
                        Text("This Mac")
                        Spacer()
                        Button(action: {
                            appState.refreshVolumes()
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help("Refresh connected drives & pen drives")
                    }
                }

                // Expandable Directory Tree
                Section("Directory Tree") {
                    DirectoryTreeNodeView(
                        url: FileManager.default.homeDirectoryForCurrentUser,
                        appState: appState
                    )
                }
            }
            .listStyle(SidebarListStyle())
        }
    }

    private func sidebarItem(url: URL, icon: String, title: String, badgeIcon: String?) -> some View {
        let isSelected = appState.activeTab.currentURL == url

        return HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(isSelected ? .accentColor : .secondary)
                .frame(width: 18)

            Text(title)
                .font(.system(size: 13))
                .foregroundColor(isSelected ? .primary : .primary)
                .lineLimit(1)

            Spacer()

            if let badge = badgeIcon {
                Image(systemName: badge)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary.opacity(0.6))
            }
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor.opacity(0.18) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            appState.navigate(to: url)
        }
    }

    private func volumeSidebarItem(volumeURL: URL) -> some View {
        let isSelected = appState.activeTab.currentURL.standardizedFileURL == volumeURL.standardizedFileURL
        let keys: [URLResourceKey] = [.volumeNameKey, .volumeIsRemovableKey, .volumeIsEjectableKey, .volumeIsInternalKey]
        let vals = try? volumeURL.resourceValues(forKeys: Set(keys))
        let isRemovable = (vals?.volumeIsRemovable == true) || (vals?.volumeIsEjectable == true)
        let rawName = vals?.volumeName ?? volumeURL.lastPathComponent
        let displayName: String
        if volumeURL.path == "/" {
            displayName = "Macintosh HD"
        } else if rawName.isEmpty {
            displayName = volumeURL.lastPathComponent
        } else {
            displayName = rawName
        }

        let icon = isRemovable ? "externaldrive.connected.to.line.below.fill" : "internaldrive.fill"

        return HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(isSelected ? .accentColor : (isRemovable ? .orange : .secondary))
                .frame(width: 18)

            Text(displayName)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .foregroundColor(.primary)
                .lineLimit(1)

            if isRemovable {
                Text("USB")
                    .font(.system(size: 9, weight: .bold))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color.orange.opacity(0.18))
                    .foregroundColor(.orange)
                    .clipShape(Capsule())
            }

            Spacer()

            if isRemovable {
                Button(action: {
                    appState.ejectVolume(volumeURL)
                }) {
                    Image(systemName: "eject.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .padding(3)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                .help("Eject \(displayName)")
            }
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor.opacity(0.18) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            appState.navigate(to: volumeURL)
        }
        .contextMenu {
            Button("Open") {
                appState.navigate(to: volumeURL)
            }
            Button("Open in New Tab") {
                appState.addTab(at: volumeURL)
            }
            if isRemovable {
                Divider()
                Button("Eject \(displayName)") {
                    appState.ejectVolume(volumeURL)
                }
            }
            Divider()
            Button("Copy Path") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(volumeURL.path, forType: .string)
            }
        }
    }

    private func iconName(for url: URL) -> String {
        let name = url.lastPathComponent.lowercased()
        switch name {
        case "desktop": return "menubar.dock.rectangle"
        case "documents": return "doc.text.fill"
        case "downloads": return "arrow.down.circle.fill"
        case "pictures": return "photo.fill"
        case "movies": return "film.fill"
        case "music": return "music.note"
        default: return "folder.fill"
        }
    }
}

/// Recursive Tree Node for directory tree expansion
public struct DirectoryTreeNodeView: View {
    let url: URL
    @ObservedObject var appState: AppState
    @State private var isExpanded: Bool = false
    @State private var subdirectories: [URL] = []

    public var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Button(action: {
                    toggleExpand()
                }) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)
                        .frame(width: 14, height: 14)
                }
                .buttonStyle(PlainButtonStyle())

                Image(systemName: "folder.fill")
                    .foregroundColor(appState.activeTab.currentURL == url ? .accentColor : .secondary)
                    .font(.system(size: 11))

                Text(url.lastPathComponent)
                    .font(.system(size: 12))
                    .lineLimit(1)

                Spacer()
            }
            .contentShape(Rectangle())
            .onTapGesture {
                appState.navigate(to: url)
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(subdirectories, id: \.self) { subURL in
                        DirectoryTreeNodeView(url: subURL, appState: appState)
                            .padding(.leading, 12)
                    }
                }
            }
        }
    }

    private func toggleExpand() {
        isExpanded.toggle()
        if isExpanded && subdirectories.isEmpty {
            loadSubdirectories()
        }
    }

    private func loadSubdirectories() {
        let keys: [URLResourceKey] = [.isDirectoryKey, .isPackageKey]
        if let contents = try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        ) {
            self.subdirectories = contents.filter { u in
                let vals = try? u.resourceValues(forKeys: Set(keys))
                return (vals?.isDirectory ?? false) && !(vals?.isPackage ?? false)
            }.sorted { $0.lastPathComponent < $1.lastPathComponent }
        }
    }
}
