# Release Notes - OX Finder v1.0.0

**Release Date:** September 29, 2026  
**Target Platform:** macOS 13.0+ (Ventura, Sonoma, Sequoia)  
**Architecture:** Universal (Apple Silicon M1/M2/M3/M4 & Intel x86_64)  
**Author & Owner:** Manoj B Yadwad  
**License:** GNU General Public License v3.0 (GPL-3.0)

---

## Overview

We are excited to announce the initial public release of **OX Finder (v1.0.0)**! 

OX Finder is a standalone, non-sandboxed macOS desktop application engineered with Swift, SwiftUI, and AppKit to bring full **Windows File Explorer** parity and fluent ergonomics to macOS. Designed for users who desire the productivity, intuitive navigation, and workflow speed of Windows File Explorer while retaining the elegance and performance of macOS.

---

## What's New in v1.0.0

### 1. Windows 11 Ribbon / Command Toolbar
- **Essential Actions**: Quick single-click access for **New Folder**, **Cut**, **Copy**, **Paste**, **Rename**, **Share**, and **Delete**.
- **View Controls**: Direct dropdowns to change sorting criteria (Name, Date Modified, Type, Size) and ascending/descending order.
- **Inspector Toggle**: Instant toggle for the collapsible side Preview Pane.

### 2. Multi-Tab Management & Tab Drop
- **Full Tab Lifecycle**: Open new tabs with `Cmd+T`, close tabs with `Cmd+W`, and restore closed tabs with `Cmd+Shift+T`.
- **Drag & Reorder**: Reorder tabs smoothly across the tab bar.
- **Direct Tab File Drop**: Drag files and folders directly onto any inactive tab header to initiate an instant copy or move operation into that directory.

### 3. Interactive Address Bar & Breadcrumbs
- **Smart Breadcrumb Trail**: Clickable path segments with popover menus revealing sibling directories for instant jumping without scrolling.
- **Raw Path Mode**: Click on any empty area of the address bar to switch into an editable raw text field (supporting absolute paths, `~`, and clipboard copy/paste).
- **Integrated Search**: Real-time filtering within the current directory with a toggle for recursive subdirectory matching.

### 4. Navigation Sidebar
- **Quick Access**: Pin your most-used folders (Home, Desktop, Documents, Downloads, Pictures, etc.).
- **This Mac**: Real-time detection and listing of mounted storage volumes, external drives, and USB media.
- **Expandable Directory Tree**: Classic Windows Explorer hierarchical folder tree navigation with expandable disclosure chevrons.

### 5. High-Performance Grid & 6 View Modes
- **Details View**: Sortable columns for Name, Date Modified, Type, and Size with keyboard navigation.
- **Compact List View**: Multi-column compact presentation.
- **Icon Grid Views**: 4 distinct icon sizes:
  - Small Icons (32×32)
  - Medium Icons (64×64)
  - Large Icons (128×128)
  - Extra Large Icons (256×256)
- **Two-Tier Thumbnail Cache Engine**: High-speed in-memory caching (`NSCache`) backed by persistent disk caching (`~/Library/Caches/OXFinder/Thumbnails`) using SHA-256 hashes of file path and modification dates, powered by asynchronous `QLThumbnailGenerator`.

### 6. Preview Pane & Built-in Image Viewer
- **Collapsible Inspector Pane (`Option+P` / `Alt+P`)**: Instant high-resolution preview with detailed metadata, including EXIF camera attributes (Camera, Lens, ISO, Aperture, Shutter Speed), pixel dimensions, and POSIX file permissions.
- **Dedicated In-App Image Viewer**:
  - Open with `Enter` or double-click on any image.
  - Smooth zoom from 10% to 500%, 1:1 pixel view, Fit to Screen, and mouse/trackpad pinch/scroll zoom.
  - Arrow key navigation (`Left` / `Right`) to browse through adjacent images seamlessly.
  - Lossless 90° clockwise and counter-clockwise rotation with instant disk synchronization.
  - Caption buttons (Minimize, Maximize, Close) and quick Delete button with confirmation.

### 7. File Operations & Windows-Style UX
- **True Cut / Copy / Paste**:
  - `Cmd+X` marks items for cut with a clear 50% opacity visual cue.
  - `Cmd+V` completes the file move directly without requiring macOS `Option+Cmd+V`.
- **Intelligent Conflict Resolution Dialog**:
  - Automatically identifies duplicate filenames and offers **Replace**, **Skip**, or **Keep Both** (automatically appends sequential suffixes like `file (1).ext`).
- **Live File System Observer**:
  - Real-time directory monitoring powered by debounced `DispatchSourceFileSystemObject` for automatic UI refreshes upon any background filesystem change.
- **Rich Context Menus**:
  - Comprehensive blank-canvas and item-specific contextual menus featuring "Open with", Cut, Copy, Rename, Delete, and Get Info.

---

## System Requirements

- **Operating System:** macOS 13.0 (Ventura), macOS 14.0 (Sonoma), macOS 15.0 (Sequoia), or later
- **Hardware:** Apple Silicon (M1/M2/M3/M4) or Intel 64-bit Mac
- **Permissions:** Full Disk Access recommended for unrestricted file management

---

## Installation & Running

### Building from Source:
```bash
# Clone the repository
git clone https://github.com/manojyadwad/OXFinder.git
cd OXFinder

# Run directly via Swift Package Manager
swift run
```

### Packaging DMG Installer:
```bash
./scripts/build_dmg.sh
```
This generates a drag-and-drop installer disk image at `build/OX Finder.dmg`.

---

## Ownership & License Notice

- **Ownership:** This software is owned by **Manoj B Yadwad** (`manojyadwad@gmail.com`).
- **Copyright:** Copyright © 2026 Manoj B Yadwad. All rights reserved.
- **License:** Distributed under the **GNU General Public License v3.0 (GPL-3.0)**.
- **Terms:** Free to use and distribute under the terms of the GNU General Public License. You are free to run and distribute this software, but you **cannot claim ownership or authorship** of this project. See [LICENSE](LICENSE) for details.
