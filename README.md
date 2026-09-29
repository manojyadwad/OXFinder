# OX Finder for macOS

A standalone, non-sandboxed macOS desktop application delivering full Windows File Explorer parity on macOS 13.0+ (Ventura and later), built with Swift, SwiftUI, and AppKit.

---

## Key Features & Windows Parity

### 1. Navigation & Shell Layout
- **Windows 11 Ribbon / Command Toolbar**: Quick actions for New Folder, Cut, Copy, Paste, Rename, Share, Delete, Sort field & direction, View Mode selection, and Preview toggle.
- **Interactive Address Bar & Breadcrumbs**: Clickable breadcrumb path segments with popover menus showing sibling folders for direct jumping, toggled with a single click into an editable raw path field (`/Users/...` or `~`) with copy/paste support.
- **Navigation Pane (Sidebar)**:
  - **Quick Access**: Pinned folders (Home, Desktop, Documents, Downloads, Pictures, etc.).
  - **This Mac**: Live mounted drives and external storage volumes.
  - **Expandable Directory Tree**: Windows Explorer style tree-view navigation with expandable chevrons.
- **Search Bar**: Real-time filtering within the active folder with a recursion toggle.
- **Status Bar**: Live item count, selected item count, cumulative selected file size, and available free storage space on the volume.

### 2. Tab System
- Multi-tab management: New Tab (`Cmd+T`), Close Tab (`Cmd+W`), Reopen Closed Tab (`Cmd+Shift+T`).
- Drag-and-drop tab reordering.
- **File Drop onto Tabs**: Drag files from the grid directly onto any tab header to copy/move files into that tab's directory.

### 3. Grid & Thumbnail Engine
- **6 View Modes**:
  1. **Details View**: Sortable columns (Name, Date modified, Type, Size).
  2. **List View**: Multi-column compact list.
  3. **Small Icons** (32×32)
  4. **Medium Icons** (64×64)
  5. **Large Icons** (128×128)
  6. **Extra Large Icons** (256×256)
- **High-Performance Two-Tier Thumbnail Cache**:
  - Memory cache (`NSCache`) + Fast Disk Cache (`~/Library/Caches/OXFinder/Thumbnails`) using SHA-256 hashes of path + modification time.
  - Asynchronous background rendering with `QuickLookThumbnailing` (`QLThumbnailGenerator`).

### 4. Built-in Image Viewer & Preview Pane
- **Collapsible Preview Pane (`Option+P` / `Alt+P`)**: Instant high-res preview with camera EXIF details (Camera, Lens, ISO, Aperture, Shutter Speed), pixel dimensions, color profile, and POSIX permissions.
- **Dedicated In-App Image Viewer**:
  - Open with `Enter` or double click on any image.
  - Zoom from 10% to 500%, 1:1 pixel view, Fit to Screen, drag-to-pan when zoomed, plus trackpad/mouse scroll wheel zoom.
  - Next/Previous image cycling with Left/Right arrow keys without leaving the viewer.
  - Lossless 90° clockwise and counter-clockwise rotation (`MetadataExtractor.rotateImage`).
  - Windows-style caption controls (Minimize, Maximize/Restore, Close) and quick Delete file button with confirmation.

### 5. File Operations & Windows-Style UX
- **True Cut / Copy / Paste**:
  - `Cmd+X` marks items for cut with a 50% opacity visual cue.
  - `Cmd+V` moves the file cleanly (no `Option+Cmd+V` required).
- **Conflict Resolution**:
  - When pasting or moving into a folder with duplicate filenames, a prompt offers:
    - **Replace**: Overwrites the target file.
    - **Skip**: Ignores the conflicted file.
    - **Keep Both**: Automatically appends a sequential suffix (e.g., `file (1).ext`).
- **File System Observer**: Debounced `DispatchSourceFileSystemObject` automatically refreshes directory contents upon any background filesystem changes.
- **Context Menus**: Blank canvas right-click menu (New Folder, Paste, Refresh, View Mode, Sort by) and file right-click menu with "Open with" application list, Cut, Copy, Rename, Delete, and Get Info.

---

## Project Architecture

```
OXFinder/
├── Package.swift
├── Resources/
│   ├── AppIcon.icns
│   ├── AppIcon.png
│   ├── Info.plist
│   └── FileExplorer.entitlements
├── scripts/
│   └── build_dmg.sh
└── Sources/
    └── OXFinder/
        ├── OXFinderApp.swift                 # App lifecycle, custom logo icon, hidden titlebar
        ├── Models/
        │   ├── Enums.swift                   # ViewMode, SortField, ClipboardOperation, ConflictResolution
        │   ├── FileItem.swift                # Cached file metadata, sizes, UTType, formatted dates
        │   └── TabItem.swift                 # Tab state, URL history stack, search queries
        ├── Services/
        │   ├── AppLogoHelper.swift           # In-app and Dock logo provider
        │   ├── FileSystemManager.swift       # Actor for async enumeration, sorting, cut/copy/paste, volumes
        │   ├── DirectoryWatcher.swift        # DispatchSource file system observer with debouncer
        │   ├── ThumbnailCacheService.swift   # Actor two-tier NSCache + Disk cache with QLThumbnailGenerator
        │   └── MetadataExtractor.swift       # EXIF extraction, dimensions, POSIX permissions, lossless rotation
        ├── ViewModels/
        │   └── AppState.swift                # Central @MainActor state coordinator
        └── Views/
            ├── Shell/
            │   ├── MainShellView.swift       # Root shell with global keyboard event monitor
            │   ├── AddressBreadcrumbBar.swift# Clickable breadcrumbs + raw editable path + search
            │   ├── CommandToolbar.swift      # Windows 11 Ribbon action bar
            │   ├── NavigationSidebar.swift   # Quick Access, Mounted Volumes, and Directory Tree
            │   └── StatusBarView.swift       # Item counts, selection sizes, free disk space
            ├── Tabs/
            │   └── WindowsTabBarView.swift   # Windows tabs, drag reorder, drop files to tabs
            ├── Grid/
            │   ├── FileBrowserContainerView.swift # View switcher & drop destination
            │   ├── DetailsTableView.swift    # AppKit/SwiftUI sortable columns
            │   ├── IconGridView.swift        # Small, Medium, Large, Extra Large icons & List
            │   └── FileThumbnailView.swift   # Async thumbnail view with symlink badges
            ├── Preview/
            │   ├── PreviewPaneView.swift     # Right collapsible metadata inspector
            │   └── FullImageViewerModal.swift# Full viewer with zoom, pan, arrows, rotate, caption controls
            └── Modals/
                └── ConflictResolutionDialog.swift # Replace / Skip / Keep Both dialog
```

---

## Building & Running

### Run Locally via Swift CLI:
```bash
swift run
```

### Build Standalone App & DMG:
```bash
./scripts/build_dmg.sh
```
This generates:
- `build/OX Finder.app`: Non-sandboxed standalone `.app` bundle with custom icon.
- `build/OX Finder.dmg`: Drag-and-drop installer disk image with `/Applications` link.

### Notarization (Direct Distribution):
```bash
# Submit DMG to Apple Notary Service
xcrun notarytool submit "build/OX Finder.dmg" --keychain-profile "YOUR_KEYCHAIN_PROFILE" --wait

# Staple ticket to DMG
xcrun stapler staple "build/OX Finder.dmg"
```

---

## Ownership & License

- **Owner**: This software is owned by **Manoj B Yadwad** (`manojyadwad@gmail.com`).
- **License**: Distributed under the **GNU General Public License v3.0 (GPL-3.0)**.
- **Terms**: Free to use and distribute under the terms of the General Public License, but you **cannot claim ownership or authorship** of this software. See the [LICENSE](LICENSE) file for the complete terms and conditions.
