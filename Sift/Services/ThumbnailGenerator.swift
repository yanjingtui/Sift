import AppKit
import ImageIO

/// Generates memory-efficient thumbnails using CGImageSource.
///
/// For JPEG files from cameras, `CGImageSourceCreateThumbnailAtIndex` reads
/// the embedded preview JPEG rather than decoding the full image — typically
/// < 10 ms per file.
enum ThumbnailGenerator {

    /// LRU cache for small thumbnails shared across grid, filmstrip, and
    /// detail-view placeholder. Avoids re-reading from slow SD cards.
    private static let cache = NSCache<NSURL, NSImage>()

    /// Limits concurrent file reads so rapid scrolling doesn't flood the
    /// SD card with hundreds of simultaneous I/O requests.
    private static let ioSemaphore = DispatchSemaphore(value: 8)

    static func generate(url: URL, maxDimension: CGFloat) -> NSImage? {
        // Wait for a concurrency slot with short timeouts so the calling
        // task can bail out (Task.isCancelled) if the cell scrolled away
        // before we start any file I/O.
        while ioSemaphore.wait(timeout: .now() + 0.05) == .timedOut {
            if Task.isCancelled { return nil }
        }
        defer { ioSemaphore.signal() }

        let options: [CFString: Any] = [
            kCGImageSourceThumbnailMaxPixelSize: maxDimension,
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,   // honor EXIF orientation
            kCGImageSourceShouldCache: false,
        ]

        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }

        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }

    /// Returns the cached thumbnail if present, nil otherwise.
    /// Does not trigger generation — safe to call on the main thread.
    static func cachedThumbnail(url: URL) -> NSImage? {
        cache.object(forKey: url as NSURL)
    }

    /// Returns a cached small thumbnail (max 300px) for `url`, generating
    /// and caching it on first access. Shared by grid, filmstrip, and the
    /// detail-view placeholder so the same file is decoded only once.
    static func thumbnail(url: URL) -> NSImage? {
        if let cached = cache.object(forKey: url as NSURL) {
            return cached
        }
        guard let img = generate(url: url, maxDimension: 300) else { return nil }
        cache.setObject(img, forKey: url as NSURL)
        return img
    }
}
