import SwiftUI
import AppKit
import UniformTypeIdentifiers
import CommonCrypto

/// Windows 11 / File Explorer Style Properties Dialog
public struct FilePropertiesModal: View {
    let item: FileItem
    @ObservedObject var appState: AppState
    let onDismiss: () -> Void

    @State private var selectedTab: PropertiesTab = .general
    @State private var fileName: String = ""
    @State private var isReadOnly: Bool = false
    @State private var isHiddenAttribute: Bool = false
    
    // Asynchronous folder calculation
    @State private var folderFileCount: Int = 0
    @State private var folderDirCount: Int = 0
    @State private var folderTotalBytes: Int64 = 0
    @State private var isCalculatingFolder: Bool = false

    // Default application
    @State private var defaultAppName: String = ""
    @State private var defaultAppIcon: NSImage? = nil

    // Detailed metadata
    @State private var metadata: FileDetailedMetadata? = nil

    // Security Permissions
    @State private var ownerRead: Bool = true
    @State private var ownerWrite: Bool = true
    @State private var ownerExecute: Bool = false
    @State private var groupRead: Bool = true
    @State private var groupWrite: Bool = false
    @State private var groupExecute: Bool = false
    @State private var othersRead: Bool = true
    @State private var othersWrite: Bool = false
    @State private var othersExecute: Bool = false
    @State private var posixString: String = "0644"

    // Checksum
    @State private var sha256Checksum: String = ""
    @State private var isCalculatingChecksum: Bool = false

    public enum PropertiesTab: String, CaseIterable, Identifiable {
        case general = "General"
        case security = "Security"
        case details = "Details"

        public var id: String { rawValue }
    }

    public var body: some View {
        ZStack {
            // Semi-transparent backdrop
            Color.black.opacity(0.3)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    onDismiss()
                }

            // Windows Properties Window Card
            VStack(spacing: 0) {
                // Window Title Bar
                HStack {
                    Image(nsImage: item.systemIcon)
                        .resizable()
                        .frame(width: 16, height: 16)
                    Text("\(item.name) Properties")
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                            .frame(width: 20, height: 20)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(nsColor: .windowBackgroundColor))

                Divider()

                // Windows Style Tab Picker
                HStack(spacing: 2) {
                    ForEach(PropertiesTab.allCases) { tab in
                        Button(action: {
                            selectedTab = tab
                        }) {
                            Text(tab.rawValue)
                                .font(.system(size: 12, weight: selectedTab == tab ? .semibold : .regular))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    selectedTab == tab ?
                                        Color(nsColor: .controlBackgroundColor) :
                                        Color.clear
                                )
                                .foregroundColor(selectedTab == tab ? .primary : .secondary)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.top, 6)
                .padding(.bottom, 2)
                .background(Color(nsColor: .windowBackgroundColor).opacity(0.6))

                Divider()

                // Tab Content Area
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        switch selectedTab {
                        case .general:
                            generalTabView
                        case .security:
                            securityTabView
                        case .details:
                            detailsTabView
                        }
                    }
                    .padding(16)
                }
                .frame(height: 380)

                Divider()

                // Bottom Action Buttons (OK, Cancel, Apply)
                HStack(spacing: 8) {
                    Spacer()

                    Button("OK") {
                        applyChanges()
                        onDismiss()
                    }
                    .buttonStyle(BorderedProminentButtonStyle())
                    .keyboardShortcut(.defaultAction)

                    Button("Cancel") {
                        onDismiss()
                    }
                    .buttonStyle(BorderedButtonStyle())
                    .keyboardShortcut(.cancelAction)

                    Button("Apply") {
                        applyChanges()
                    }
                    .buttonStyle(BorderedButtonStyle())
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(nsColor: .windowBackgroundColor))
            }
            .frame(width: 440)
            .background(Color(nsColor: .windowBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.28), radius: 20, y: 8)
        }
        .onAppear {
            initializeData()
        }
    }

    // MARK: - General Tab

    private var generalTabView: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header: Icon + Name TextField
            HStack(spacing: 12) {
                Image(nsImage: item.systemIcon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 36, height: 36)

                TextField("File name", text: $fileName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(.system(size: 13, weight: .medium))
            }

            Divider()

            // Type of File & Opens With
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                GridRow {
                    Text("Type of file:")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .gridColumnAlignment(.trailing)
                    Text("\(item.fileTypeDescription) (\(item.url.pathExtension.isEmpty ? "Folder" : ".\(item.url.pathExtension)"))")
                        .font(.system(size: 11))
                }

                if !item.isDirectory || item.isPackage {
                    GridRow {
                        Text("Opens with:")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        HStack(spacing: 6) {
                            if let icon = defaultAppIcon {
                                Image(nsImage: icon)
                                    .resizable()
                                    .frame(width: 14, height: 14)
                            }
                            Text(defaultAppName)
                                .font(.system(size: 11))
                            Spacer()
                            Button("Change...") {
                                chooseDefaultApp()
                            }
                            .font(.system(size: 10))
                            .buttonStyle(BorderedButtonStyle())
                        }
                    }
                }

                GridRow {
                    Text("Location:")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    HStack {
                        Text(item.url.deletingLastPathComponent().path)
                            .font(.system(size: 11))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        Button(action: {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(item.url.deletingLastPathComponent().path, forType: .string)
                        }) {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 10))
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help("Copy Location")
                    }
                }

                GridRow {
                    Text("Size:")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    if item.isDirectory && !item.isPackage {
                        if isCalculatingFolder {
                            ProgressView()
                                .scaleEffect(0.5)
                        } else {
                            Text("\(formattedByteSize(folderTotalBytes)) (\(formattedExactBytes(folderTotalBytes)) bytes)")
                                .font(.system(size: 11))
                        }
                    } else {
                        Text("\(item.formattedSize) (\(formattedExactBytes(item.size)) bytes)")
                            .font(.system(size: 11))
                    }
                }

                if item.isDirectory && !item.isPackage {
                    GridRow {
                        Text("Contains:")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        if isCalculatingFolder {
                            Text("Calculating...")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        } else {
                            Text("\(folderFileCount) Files, \(folderDirCount) Folders")
                                .font(.system(size: 11))
                        }
                    }
                }
            }

            Divider()

            // Timestamps
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                GridRow {
                    Text("Created:")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .gridColumnAlignment(.trailing)
                    Text(formattedFullDate(item.dateCreated))
                        .font(.system(size: 11))
                }

                GridRow {
                    Text("Modified:")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Text(formattedFullDate(item.dateModified))
                        .font(.system(size: 11))
                }
            }

            Divider()

            // Attributes (Read-only, Hidden)
            HStack(spacing: 20) {
                Text("Attributes:")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                Toggle("Read-only", isOn: $isReadOnly)
                    .toggleStyle(CheckboxToggleStyle())
                    .font(.system(size: 11))

                Toggle("Hidden", isOn: $isHiddenAttribute)
                    .toggleStyle(CheckboxToggleStyle())
                    .font(.system(size: 11))
            }
        }
    }

    // MARK: - Security Tab

    private var securityTabView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Object name:")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Text(item.url.path)
                    .font(.system(size: 11, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Divider()

            Text("Group or user names:")
                .font(.system(size: 11, weight: .semibold))

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "person.fill")
                        .foregroundColor(.accentColor)
                    Text("Owner: \(metadata?.ownerAccount ?? NSUserName())")
                        .font(.system(size: 11))
                }
                HStack {
                    Image(systemName: "person.2.fill")
                        .foregroundColor(.secondary)
                    Text("Staff / Group")
                        .font(.system(size: 11))
                }
                HStack {
                    Image(systemName: "globe")
                        .foregroundColor(.secondary)
                    Text("Everyone / Others")
                        .font(.system(size: 11))
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))

            Divider()

            Text("Permissions (POSIX Mode: \(posixString)):")
                .font(.system(size: 11, weight: .semibold))

            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 6) {
                GridRow {
                    Text("Category")
                        .font(.system(size: 11, weight: .bold))
                    Text("Read")
                        .font(.system(size: 11, weight: .bold))
                    Text("Write")
                        .font(.system(size: 11, weight: .bold))
                    Text("Execute")
                        .font(.system(size: 11, weight: .bold))
                }

                GridRow {
                    Text("Owner")
                        .font(.system(size: 11))
                    Toggle("", isOn: $ownerRead).toggleStyle(CheckboxToggleStyle())
                    Toggle("", isOn: $ownerWrite).toggleStyle(CheckboxToggleStyle())
                    Toggle("", isOn: $ownerExecute).toggleStyle(CheckboxToggleStyle())
                }

                GridRow {
                    Text("Group")
                        .font(.system(size: 11))
                    Toggle("", isOn: $groupRead).toggleStyle(CheckboxToggleStyle())
                    Toggle("", isOn: $groupWrite).toggleStyle(CheckboxToggleStyle())
                    Toggle("", isOn: $groupExecute).toggleStyle(CheckboxToggleStyle())
                }

                GridRow {
                    Text("Others")
                        .font(.system(size: 11))
                    Toggle("", isOn: $othersRead).toggleStyle(CheckboxToggleStyle())
                    Toggle("", isOn: $othersWrite).toggleStyle(CheckboxToggleStyle())
                    Toggle("", isOn: $othersExecute).toggleStyle(CheckboxToggleStyle())
                }
            }
            .padding(8)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }

    // MARK: - Details Tab

    private var detailsTabView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("File & Metadata Properties")
                .font(.system(size: 11, weight: .semibold))

            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 6) {
                GridRow {
                    Text("Property")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                    Text("Value")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                }

                GridRow {
                    Text("Name").font(.system(size: 11))
                    Text(item.name).font(.system(size: 11))
                }

                GridRow {
                    Text("Item type").font(.system(size: 11))
                    Text(item.fileTypeDescription).font(.system(size: 11))
                }

                if let uti = metadata?.uti {
                    GridRow {
                        Text("Content Type").font(.system(size: 11))
                        Text(uti).font(.system(size: 11, design: .monospaced))
                    }
                }

                if let dims = metadata?.dimensions {
                    GridRow {
                        Text("Dimensions").font(.system(size: 11))
                        Text("\(Int(dims.width)) x \(Int(dims.height)) px").font(.system(size: 11))
                    }
                }

                if let cs = metadata?.colorSpace {
                    GridRow {
                        Text("Color space").font(.system(size: 11))
                        Text(cs).font(.system(size: 11))
                    }
                }

                if let cam = metadata?.cameraModel ?? metadata?.cameraMake {
                    GridRow {
                        Text("Camera").font(.system(size: 11))
                        Text(cam).font(.system(size: 11))
                    }
                }

                if let iso = metadata?.iso {
                    GridRow {
                        Text("ISO Speed").font(.system(size: 11))
                        Text("ISO-\(iso)").font(.system(size: 11))
                    }
                }

                if let f = metadata?.fNumber {
                    GridRow {
                        Text("F-Stop").font(.system(size: 11))
                        Text(String(format: "f/%.1f", f)).font(.system(size: 11))
                    }
                }

                if let exp = metadata?.exposureTime {
                    GridRow {
                        Text("Exposure").font(.system(size: 11))
                        Text(exp).font(.system(size: 11))
                    }
                }

                GridRow {
                    Text("File size").font(.system(size: 11))
                    Text(formattedExactBytes(item.size) + " bytes").font(.system(size: 11))
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))

            Divider()

            // Checksum Generator
            HStack {
                Text("SHA-256:")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                if isCalculatingChecksum {
                    ProgressView().scaleEffect(0.5)
                } else if !sha256Checksum.isEmpty {
                    Text(sha256Checksum)
                        .font(.system(size: 10, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Button(action: {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(sha256Checksum, forType: .string)
                    }) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 10))
                    }
                    .buttonStyle(PlainButtonStyle())
                } else {
                    Button("Compute SHA-256") {
                        calculateChecksum()
                    }
                    .font(.system(size: 10))
                    .buttonStyle(BorderedButtonStyle())
                }
            }
        }
    }

    // MARK: - Helpers

    private func initializeData() {
        self.fileName = item.name
        self.metadata = MetadataExtractor.shared.extractMetadata(for: item.url)

        // Read attributes
        let fm = FileManager.default
        let path = item.url.path
        let attrs = (try? fm.attributesOfItem(atPath: path)) ?? [:]

        if let posix = attrs[.posixPermissions] as? NSNumber {
            let mode = posix.intValue
            self.posixString = String(format: "%o", mode)
            self.ownerRead = (mode & 0o400) != 0
            self.ownerWrite = (mode & 0o200) != 0
            self.ownerExecute = (mode & 0o100) != 0
            self.groupRead = (mode & 0o040) != 0
            self.groupWrite = (mode & 0o020) != 0
            self.groupExecute = (mode & 0o010) != 0
            self.othersRead = (mode & 0o004) != 0
            self.othersWrite = (mode & 0o002) != 0
            self.othersExecute = (mode & 0o001) != 0

            self.isReadOnly = !ownerWrite
        }

        let vals = try? item.url.resourceValues(forKeys: [.isHiddenKey])
        self.isHiddenAttribute = (vals?.isHidden == true) || item.name.hasPrefix(".")

        // Default app
        if let defaultAppURL = NSWorkspace.shared.urlForApplication(toOpen: item.url) {
            self.defaultAppName = fm.displayName(atPath: defaultAppURL.path)
            self.defaultAppIcon = NSWorkspace.shared.icon(forFile: defaultAppURL.path)
        } else {
            self.defaultAppName = "Unknown Application"
        }

        // Recursive directory calculation
        if item.isDirectory && !item.isPackage {
            calculateFolderMetrics()
        }
    }

    private func calculateFolderMetrics() {
        isCalculatingFolder = true
        let targetURL = item.url
        Task.detached(priority: .utility) {
            let fm = FileManager.default
            var files = 0
            var dirs = 0
            var totalBytes: Int64 = 0

            let enumerator = fm.enumerator(
                at: targetURL,
                includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey, .isPackageKey],
                options: [.skipsHiddenFiles]
            )

            while let fileURL = enumerator?.nextObject() as? URL {
                let vals = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey, .isPackageKey])
                if vals?.isDirectory == true && !(vals?.isPackage ?? false) {
                    dirs += 1
                } else {
                    files += 1
                    totalBytes += Int64(vals?.fileSize ?? 0)
                }
            }

            let filesSnapshot = files
            let dirsSnapshot = dirs
            let bytesSnapshot = totalBytes
            await MainActor.run {
                self.folderFileCount = filesSnapshot
                self.folderDirCount = dirsSnapshot
                self.folderTotalBytes = bytesSnapshot
                self.isCalculatingFolder = false
            }
        }
    }

    private func calculateChecksum() {
        guard !item.isDirectory else { return }
        isCalculatingChecksum = true
        let fileURL = item.url
        Task.detached(priority: .userInitiated) {
            if let data = try? Data(contentsOf: fileURL, options: .mappedIfSafe) {
                var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
                data.withUnsafeBytes {
                    _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
                }
                let hexString = hash.map { String(format: "%02x", $0) }.joined()
                await MainActor.run {
                    self.sha256Checksum = hexString
                    self.isCalculatingChecksum = false
                }
            } else {
                await MainActor.run {
                    self.isCalculatingChecksum = false
                }
            }
        }
    }

    private func chooseDefaultApp() {
        let panel = NSOpenPanel()
        panel.title = "Choose Default Application"
        panel.prompt = "Set Default"
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let appURL = panel.url {
            self.defaultAppName = FileManager.default.displayName(atPath: appURL.path)
            self.defaultAppIcon = NSWorkspace.shared.icon(forFile: appURL.path)
        }
    }

    private func applyChanges() {
        let fm = FileManager.default
        let currentURL = item.url

        // 1. Rename if name changed
        if !fileName.isEmpty && fileName != item.name {
            let newURL = currentURL.deletingLastPathComponent().appendingPathComponent(fileName)
            try? fm.moveItem(at: currentURL, to: newURL)
            appState.loadCurrentDirectory()
        }

        // 2. Apply permissions
        var newMode: mode_t = 0
        if ownerRead { newMode |= 0o400 }
        if !isReadOnly && ownerWrite { newMode |= 0o200 }
        if ownerExecute { newMode |= 0o100 }
        if groupRead { newMode |= 0o040 }
        if groupWrite { newMode |= 0o020 }
        if groupExecute { newMode |= 0o010 }
        if othersRead { newMode |= 0o004 }
        if othersWrite { newMode |= 0o002 }
        if othersExecute { newMode |= 0o001 }

        chmod(currentURL.path, newMode)

        // 3. Apply Hidden Flag
        if isHiddenAttribute {
            chflags(currentURL.path, UInt32(UF_HIDDEN))
        } else {
            chflags(currentURL.path, 0)
        }

        appState.loadCurrentDirectory()
    }

    private func formattedByteSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    private func formattedExactBytes(_ bytes: Int64) -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        return nf.string(from: NSNumber(value: bytes)) ?? "\(bytes)"
    }

    private func formattedFullDate(_ date: Date?) -> String {
        guard let d = date else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .medium
        return formatter.string(from: d)
    }
}
