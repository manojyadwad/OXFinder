================================================================================
OX FINDER FOR MACOS
================================================================================
A standalone, non-sandboxed macOS desktop application delivering full Windows 
File Explorer parity on macOS 13.0+ (Ventura and later), built with Swift, 
SwiftUI, and AppKit.

OWNERSHIP & COPYRIGHT
--------------------------------------------------------------------------------
This software is owned by Manoj B Yadwad.
Copyright (C) 2026 Manoj B Yadwad <manojyadwad@gmail.com>. All rights reserved.

DISTRIBUTION & LICENSE
--------------------------------------------------------------------------------
Distributed under the GNU General Public License v3.0 (GPL-3.0).
Free to use and distribute under the terms of the General Public License,
but you CANNOT claim ownership, copyright, or authorship of this software.

See the accompanying LICENSE file for the complete terms and conditions.

KEY FEATURES
--------------------------------------------------------------------------------
1. Navigation & Shell Layout:
   - Windows 11 Ribbon / Command Toolbar (Cut, Copy, Paste, Rename, Share, Delete,
     Sort, View Mode, Preview toggle).
   - Interactive Address Bar & Breadcrumbs with sibling folder jump menus and raw 
     editable path mode.
   - Navigation Sidebar: Quick Access pinned folders, live mounted volumes, and 
     expandable folder tree view.
   - Real-time search filter bar with recursive toggle.
   - Status bar displaying item counts, selected size, and free storage space.

2. Tabs:
   - Multi-tab management (Cmd+T, Cmd+W, Cmd+Shift+T).
   - Drag-and-drop tab reordering.
   - File drop onto tab headers to copy/move files.

3. Grid & Thumbnail Engine:
   - 6 View Modes: Details, List, Small Icons (32x32), Medium Icons (64x64),
     Large Icons (128x128), and Extra Large Icons (256x256).
   - High-performance two-tier thumbnail caching (Memory NSCache + Fast Disk Cache).
   - Asynchronous thumbnail rendering via QLThumbnailGenerator.

4. Image Viewer & Preview Pane:
   - Collapsible Inspector / Preview pane with camera EXIF details, dimensions,
     and POSIX permissions.
   - Dedicated full-featured image viewer modal with zoom (10%-500%), pan, 
     arrow key cycling, and lossless 90-degree image rotation.

5. File Operations & Windows-Style UX:
   - True Cut / Copy / Paste (Cmd+X marks with visual cue, Cmd+V moves file).
   - Conflict resolution dialog (Replace, Skip, Keep Both).
   - Background file system watcher for live directory updates.
   - Native context menus.

SYSTEM REQUIREMENTS
--------------------------------------------------------------------------------
- macOS 13.0 (Ventura) or newer
- Apple Silicon (M1/M2/M3/M4) or Intel Mac
- Swift 5.9+ / Xcode 15+ (for building from source)

BUILDING & RUNNING
--------------------------------------------------------------------------------
Run directly from terminal:
    swift run

Build standalone .app bundle and DMG installer:
    ./scripts/build_dmg.sh

Output artifacts:
    build/OX Finder.app
    build/OX Finder.dmg
================================================================================
