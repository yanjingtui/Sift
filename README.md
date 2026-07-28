# PhotoViewer

A lightweight macOS photo culling tool — browse any folder, rate photos with stars,
filter by rating, and batch-copy your favorites. Built for photographers who need
a fast screening workflow without importing into a library.

## Features

- **Browse any folder** — SD cards, local drives, anywhere on your filesystem
- **Star rating (0–5)** — rate via keyboard (0–5 keys) or click stars on thumbnails
- **Rating persists in the file** — writes XMP metadata, readable by Lightroom,
  Bridge, Windows Explorer, and exiftool. No database or sidecar files.
- **Filter by rating** — show only ★3+ photos, with live counts per filter level
- **Batch copy** — copy all filtered photos to a destination folder in one click
- **Keyboard-driven** — ←/→ navigate, 0–5 rate, Esc back to grid
- **Native macOS 26 design** — Liquid Glass materials, SF Symbols

## Requirements

- macOS 26.0+ (Tahoe)
- Xcode 26+ (for building from source)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) — `brew install xcodegen`

## Build

```bash
cd PhotoViewer
xcodegen generate
open PhotoViewer.xcodeproj
```

Or build from command line:

```bash
xcodegen generate
xcodebuild -project PhotoViewer.xcodeproj -scheme PhotoViewer -configuration Debug build
```

## Usage

1. **Open a folder** — click "Open Folder" or press ⌘O
2. **Browse** — scroll the thumbnail grid, double-click for full-screen view
3. **Rate** — hover over a thumbnail and click stars, or in detail view press 0–5
4. **Filter** — in the sidebar, select a rating threshold (e.g., ★★★ and above)
5. **Copy** — click "Copy N to…" and choose a destination folder

The rating is written directly into the JPEG file's XMP metadata. Copy the file
anywhere — the rating travels with it.

## Supported Formats

- JPEG / JPG (full support)
- PNG, HEIC, WebP (viewing only; rating writes JPEG-specific)

### Future: RAW Support

RAW formats (CR3, NEF, ARW, RAF) are planned. For now, shoot RAW+JPEG and
cull the JPEGs.

## License

MIT
