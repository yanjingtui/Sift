import Foundation

/// Filesystem operations: scanning folders for images, batch copy with
/// name-collision handling.
enum FileService {

    // MARK: - Scan

    /// Recursively scan `folder` for supported image files, sorted by filename
    /// using natural ordering (IMG_2.jpg before IMG_10.jpg).
    ///
    /// Two-stage filter:
    ///   1. Extension whitelist (fast — skips obvious non-images without
    ///      opening them).
    ///   2. Magic-byte check via `ExifService.isSupportedFormat` — the final
    ///      authority. Catches renamed files (e.g. a `.tiff` saved as `.jpg`)
    ///      so they never appear in the browser.
    static func scanImages(in folder: URL) -> [URL] {
        let resourceKeys: Set<URLResourceKey> = [.isRegularFileKey]
        var urls: [URL] = []

        let enumerator = FileManager.default.enumerator(
            at: folder,
            includingPropertiesForKeys: Array(resourceKeys),
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        )

        while let url = enumerator?.nextObject() as? URL {
            // Stage 1: extension whitelist (derived from ImageFormat.supported).
            let ext = url.pathExtension.lowercased()
            guard ExifService.ImageFormat.supportedExtensions.contains(ext) else { continue }

            let values = try? url.resourceValues(forKeys: resourceKeys)
            guard values?.isRegularFile == true else { continue }

            // Stage 2: magic-byte gate. Only files whose actual header matches
            // a supported format are kept.
            guard ExifService.isSupportedFormat(url: url) else { continue }

            urls.append(url)
        }

        return urls.sorted { a, b in
            a.lastPathComponent.compare(b.lastPathComponent, options: .numeric) == .orderedAscending
        }
    }

    // MARK: - Copy

    /// Copy a list of files to `destination`. If a file with the same name
    /// already exists, `-1`, `-2`, ... is appended to the basename.
    ///
    /// For formats whose rating lives in a `.xmp` sidecar (HEIC, WebP), the
    /// sidecar is copied alongside the image so the rating survives the copy.
    static func copyPhotos(
        _ urls: [URL],
        to destination: URL,
        progress: @escaping (Double) -> Void
    ) throws {
        for (i, url) in urls.enumerated() {
            let dest = uniqueDestination(
                for: destination.appendingPathComponent(url.lastPathComponent)
            )
            try FileManager.default.copyItem(at: url, to: dest)

            // Carry the .xmp sidecar along if the source has one. Without this,
            // HEIC/WebP copies would silently lose their rating.
            let sidecar = ExifService.sidecarURL(for: url)
            if FileManager.default.fileExists(atPath: sidecar.path) {
                let destSidecar = uniqueDestination(
                    for: ExifService.sidecarURL(for: dest)
                )
                try FileManager.default.copyItem(at: sidecar, to: destSidecar)
            }

            progress(Double(i + 1) / Double(urls.count))
        }
    }

    /// Returns `url` if it doesn't exist, otherwise appends `-N` before the
    /// extension until a free name is found.
    static func uniqueDestination(for url: URL) -> URL {
        guard FileManager.default.fileExists(atPath: url.path) else { return url }

        let directory = url.deletingLastPathComponent()
        let baseName = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension

        var counter = 1
        while true {
            let candidate = directory.appendingPathComponent("\(baseName)-\(counter).\(ext)")
            if !FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
            counter += 1
        }
    }
}
