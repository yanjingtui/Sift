import AppKit
import ImageIO

/// Generates memory-efficient thumbnails using CGImageSource.
///
/// For JPEG files from cameras, `CGImageSourceCreateThumbnailAtIndex` reads
/// the embedded preview JPEG rather than decoding the full image — typically
/// < 10 ms per file.
enum ThumbnailGenerator {

    static func generate(url: URL, maxDimension: CGFloat) -> NSImage? {
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
}
