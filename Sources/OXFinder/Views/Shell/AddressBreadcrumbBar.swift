import SwiftUI
import AppKit

/// Windows File Explorer Address Bar combining interactive breadcrumbs and direct path editing
public struct AddressBreadcrumbBar: View {
    @ObservedObject var appState: AppState
    @State private var isEditingPath: Bool = false
    @State private var pathEditText: String = ""
    @FocusState private var isTextFieldFocused: Bool

    public var body: some View {
        HStack(spacing: 6) {
            // Navigation Controls
            HStack(spacing: 2) {
                Button(action: { appState.goBack() }) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 13, weight: .semibold))
                }
                .disabled(!appState.activeTab.canGoBack)
                .buttonStyle(BorderedButtonStyle())
                .help("Back (Cmd+[)")

                Button(action: { appState.goForward() }) {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 13, weight: .semibold))
                }
                .disabled(!appState.activeTab.canGoForward)
                .buttonStyle(BorderedButtonStyle())
                .help("Forward (Cmd+])")

                Button(action: { appState.goUp() }) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 13, weight: .semibold))
                }
                .disabled(!appState.activeTab.canGoUp)
                .buttonStyle(BorderedButtonStyle())
                .help("Up (Cmd+Up)")

                Button(action: { appState.loadCurrentDirectory() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13))
                }
                .buttonStyle(BorderedButtonStyle())
                .help("Refresh (F5)")
            }

            // Interactive Breadcrumb / Path Input
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(nsColor: .textBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(isEditingPath ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: 1)
                    )

                if isEditingPath {
                    TextField("Enter path...", text: $pathEditText, onCommit: {
                        commitPathEdit()
                    })
                    .textFieldStyle(PlainTextFieldStyle())
                    .focused($isTextFieldFocused)
                    .padding(.horizontal, 10)
                    .font(.system(size: 12, design: .monospaced))
                    .onExitCommand {
                        cancelPathEdit()
                    }
                } else {
                    HStack(spacing: 2) {
                        Image(systemName: "folder.fill")
                            .foregroundColor(.accentColor)
                            .font(.system(size: 12))
                            .padding(.leading, 8)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 2) {
                                ForEach(breadcrumbSegments, id: \.url) { segment in
                                    breadcrumbItem(segment: segment)
                                }
                            }
                        }

                        Spacer()

                        // Button to switch to text edit mode
                        Button(action: {
                            startEditingPath()
                        }) {
                            Image(systemName: "square.and.pencil")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.trailing, 8)
                        .help("Edit path")
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        startEditingPath()
                    }
                }
            }
            .frame(height: 30)

            // Search Bar
            HStack(spacing: 4) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 12))

                TextField("Search \(appState.activeTab.title)", text: Binding(
                    get: { appState.activeTab.searchQuery },
                    set: { val in
                        var tab = appState.activeTab
                        tab.searchQuery = val
                        appState.activeTab = tab
                        appState.loadCurrentDirectory()
                    }
                ))
                .textFieldStyle(PlainTextFieldStyle())
                .font(.system(size: 12))

                if !appState.activeTab.searchQuery.isEmpty {
                    Button(action: {
                        var tab = appState.activeTab
                        tab.searchQuery = ""
                        appState.activeTab = tab
                        appState.loadCurrentDirectory()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 12))
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                // Recursive toggle
                Button(action: {
                    var tab = appState.activeTab
                    tab.isRecursiveSearch.toggle()
                    appState.activeTab = tab
                    if !tab.searchQuery.isEmpty {
                        appState.loadCurrentDirectory()
                    }
                }) {
                    Image(systemName: appState.activeTab.isRecursiveSearch ? "arrow.triangle.branch" : "line.3.horizontal")
                        .font(.system(size: 11))
                        .foregroundColor(appState.activeTab.isRecursiveSearch ? .accentColor : .secondary)
                }
                .buttonStyle(PlainButtonStyle())
                .help(appState.activeTab.isRecursiveSearch ? "Recursive search active" : "Search current folder only")
            }
            .padding(.horizontal, 8)
            .frame(width: 220, height: 30)
            .background(Color(nsColor: .textBackgroundColor))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
            )
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    // MARK: - Breadcrumb Segment Model & Views

    private struct BreadcrumbSegment {
        let name: String
        let url: URL
    }

    private var breadcrumbSegments: [BreadcrumbSegment] {
        var segments: [BreadcrumbSegment] = []
        var current = appState.activeTab.currentURL.standardizedFileURL

        while current.path != "/" && !current.path.isEmpty {
            segments.insert(BreadcrumbSegment(name: current.lastPathComponent, url: current), at: 0)
            current = current.deletingLastPathComponent()
        }
        segments.insert(BreadcrumbSegment(name: "Macintosh HD", url: URL(fileURLWithPath: "/")), at: 0)
        return segments
    }

    private func breadcrumbItem(segment: BreadcrumbSegment) -> some View {
        HStack(spacing: 2) {
            Button(action: {
                appState.navigate(to: segment.url)
            }) {
                Text(segment.name)
                    .font(.system(size: 12))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())

            Menu {
                // Dropdown of sibling/child folders for quick jump
                if let children = try? FileManager.default.contentsOfDirectory(
                    at: segment.url,
                    includingPropertiesForKeys: [.isDirectoryKey],
                    options: [.skipsHiddenFiles]
                ) {
                    let dirs = children.filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false }
                    ForEach(dirs, id: \.self) { child in
                        Button(child.lastPathComponent) {
                            appState.navigate(to: child)
                        }
                    }
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary)
                    .frame(width: 12, height: 16)
            }
            .menuStyle(BorderlessButtonMenuStyle())
        }
    }

    private func startEditingPath() {
        pathEditText = appState.activeTab.currentURL.path
        isEditingPath = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.isTextFieldFocused = true
        }
    }

    private func commitPathEdit() {
        isEditingPath = false
        var trimmed = pathEditText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("~") {
            let home = FileManager.default.homeDirectoryForCurrentUser.path
            trimmed = trimmed.replacingOccurrences(of: "~", with: home, options: .anchored)
        }
        let url = URL(fileURLWithPath: trimmed)
        if FileManager.default.fileExists(atPath: url.path) {
            appState.navigate(to: url)
        }
    }

    private func cancelPathEdit() {
        isEditingPath = false
    }
}
