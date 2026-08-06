import Foundation

/// Reads and writes photo star ratings via XMP metadata.
///
/// Format support:
/// - **JPEG**: XMP embedded in an APP1 segment (lossless).
/// - **PNG**: XMP embedded in an iTXt chunk with keyword `XML:com.adobe.xmp`
///   (lossless).
/// - **HEIC / WebP / others**: XMP written as a sidecar `.xmp` file alongside
///   the image, so the original file is never modified.
///
/// The XMP `Rating` tag is what exiftool, Lightroom, Bridge, and Windows
/// Explorer all read.
enum ExifService {

    // XMP namespace identifier (null-terminated, 29 bytes) — used in JPEG APP1
    private static let xmpNamespace = "http://ns.adobe.com/xap/1.0/\0"
    private static let xmpNamespaceData = xmpNamespace.data(using: .ascii)!

    // EXIF Rating tag ID (for JPEG EXIF fallback read)
    private static let exifRatingTag: UInt16 = 0x4746

    // PNG iTXt keyword for XMP
    private static let pngXMPKeyword = "XML:com.adobe.xmp"

    // MARK: - Public API

    static func readRating(url: URL) -> Int {
        guard let data = readHeader(url: url, maxBytes: 256 * 1024) else { return 0 }
        let format = detectFormat(of: data)

        switch format {
        case .jpeg:
            if let xmp = readJPEGXMPRating(from: data), xmp > 0 { return xmp }
            return readEXIFRating(from: data)
        case .png:
            return readPNGRating(from: data)
        case .heic, .webp, .other:
            return readSidecarRating(url: url)
        }
    }

    static func writeRating(url: URL, rating: Int) throws {
        guard let data = try? Data(contentsOf: url) else {
            throw ExifError.cannotReadFile
        }

        switch detectFormat(of: data) {
        case .jpeg:
            let modified = try writeJPEGXMPRating(to: data, rating: rating)
            try modified.write(to: url, options: .atomic)
        case .png:
            let modified = try writePNGXMPRating(to: data, rating: rating)
            try modified.write(to: url, options: .atomic)
        case .heic, .webp, .other:
            try writeSidecarXMPRating(url: url, rating: rating)
        }
    }

    // MARK: - Format Detection

    enum ImageFormat {
        case jpeg, png, heic, webp, other
    }

    /// Detect image format from the first bytes of the file.
    static func detectFormat(of data: Data) -> ImageFormat {
        guard data.count >= 4 else { return .other }
        // JPEG: FF D8
        if data[0] == 0xFF && data[1] == 0xD8 { return .jpeg }
        // PNG: 89 50 4E 47
        if data[0] == 0x89 && data[1] == 0x50 && data[2] == 0x4E && data[3] == 0x47 {
            return .png
        }
        // HEIF/HEIC: "ftyp" box at offset 4
        if data.count >= 12,
           data[4] == 0x66, data[5] == 0x74, data[6] == 0x79, data[7] == 0x70 {
            let brands = ["heic", "heix", "hevc", "heim", "heis", "mif1", "hevs", "avci", "avcs"]
            let brand = String(data: data.subdata(in: 8..<12), encoding: .ascii) ?? ""
            if brands.contains(brand) { return .heic }
        }
        // WebP: RIFF....WEBP
        if data.count >= 12,
           data[0] == 0x52, data[1] == 0x49, data[2] == 0x46, data[3] == 0x46,
           data[8] == 0x57, data[9] == 0x45, data[10] == 0x42, data[11] == 0x50 {
            return .webp
        }
        return .other
    }

    // MARK: - Read helpers

    /// Reads up to `maxBytes` from the start of the file.
    private static func readHeader(url: URL, maxBytes: Int) -> Data? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        return try? handle.read(upToCount: maxBytes)
    }

    // MARK: - JPEG XMP

    /// Extract `xmp:Rating` from the XMP APP1 segment.
    private static func readJPEGXMPRating(from data: Data) -> Int? {
        guard let (_, xml) = findXMPSegment(in: data) else { return nil }
        guard let str = String(data: xml, encoding: .utf8) else { return nil }
        return extractRatingFromXML(str)
    }

    /// Add or update the XMP Rating in a JPEG's APP1 segment.
    private static func writeJPEGXMPRating(to data: Data, rating: Int) throws -> Data {
        if let (range, xml) = findXMPSegment(in: data) {
            // Update existing XMP
            let updated = updateRatingInXML(String(data: xml, encoding: .utf8) ?? "", rating: rating)
            guard let updatedData = updated.data(using: .utf8) else {
                throw ExifError.xmpEncodingFailed
            }
            let newSegment = buildXMPSegment(data: updatedData)
            var result = Data()
            result.append(data[0..<range.markerRange.lowerBound])
            result.append(newSegment)
            result.append(data[range.markerRange.upperBound..<data.count])
            return result

        } else {
            // No existing XMP — create new segment
            let xml = createMinimalXMP(rating: rating)
            let segment = buildXMPSegment(data: xml.data(using: .utf8)!)

            // Insert after APP segments (APP0/APP1 EXIF), before quantization tables etc.
            let insertionPoint = findAPPSectionEnd(in: data)
            var result = Data()
            result.append(data[0..<insertionPoint])
            result.append(segment)
            result.append(data[insertionPoint..<data.count])
            return result
        }
    }

    private static func buildXMPSegment(data: Data) -> Data {
        var segment = Data()
        segment.append(contentsOf: [0xFF, 0xE1])  // APP1 marker

        // Length: 2 (length field) + 29 (namespace) + xml.count
        let length = UInt16(2 + xmpNamespaceData.count + data.count)
        segment.append(UInt8(length >> 8))
        segment.append(UInt8(length & 0xFF))

        segment.append(xmpNamespaceData)
        segment.append(data)
        return segment
    }

    // MARK: - JPEG EXIF (fallback read)

    /// Scan IFD0 for the EXIF Rating tag (0x4746). Read-only, no modification.
    private static func readEXIFRating(from data: Data) -> Int {
        guard let tiffData = extractTIFFData(from: data) else { return 0 }
        guard tiffData.count >= 8 else { return 0 }

        let littleEndian: Bool
        switch (tiffData[0], tiffData[1]) {
        case (0x49, 0x49): littleEndian = true   // "II"
        case (0x4D, 0x4D): littleEndian = false   // "MM"
        default: return 0
        }

        let ifd0Offset = Int(readU32(tiffData, at: 4, le: littleEndian))
        guard ifd0Offset + 2 <= tiffData.count else { return 0 }

        let entryCount = Int(readU16(tiffData, at: ifd0Offset, le: littleEndian))
        for i in 0..<entryCount {
            let entryOff = ifd0Offset + 2 + i * 12
            guard entryOff + 12 <= tiffData.count else { break }
            let tag = readU16(tiffData, at: entryOff, le: littleEndian)
            if tag == exifRatingTag {
                return Int(readU16(tiffData, at: entryOff + 8, le: littleEndian))
            }
        }
        return 0
    }

    // MARK: - PNG XMP

    /// Read `xmp:Rating` from a PNG iTXt chunk.
    private static func readPNGRating(from data: Data) -> Int {
        guard let (rating, _) = findPNGXMPChunk(in: data) else { return 0 }
        return rating
    }

    /// Write or replace the XMP iTXt chunk in a PNG. Lossless — only adds or
    /// replaces a single metadata chunk, pixel data is untouched.
    private static func writePNGXMPRating(to data: Data, rating: Int) throws -> Data {
        let xmpXML = createMinimalXMP(rating: rating)
        let iTXtData = buildPNGiTXtData(keyword: pngXMPKeyword, text: xmpXML)
        let iTXtChunk = buildPNGChunk(type: "iTXt", chunkData: iTXtData)

        // Walk chunks to find IHDR end (insertion point) and existing XMP chunk.
        var ihdrEnd: Int? = nil
        var existingXMPRange: Range<Int>? = nil

        var offset = 8  // skip 8-byte PNG signature
        while offset + 8 <= data.count {
            let chunkLen = Int(readU32(data, at: offset, le: false))
            let typeStart = offset + 4
            let typeStr = String(data: data.subdata(in: typeStart..<typeStart + 4), encoding: .ascii) ?? "????"
            let dataStart = offset + 8
            guard dataStart + chunkLen + 4 <= data.count else { break }

            if typeStr == "IHDR" {
                ihdrEnd = dataStart + chunkLen + 4  // after CRC
            }

            if typeStr == "iTXt" {
                let chunkData = data.subdata(in: dataStart..<dataStart + chunkLen)
                if let kwEnd = chunkData.firstIndex(of: 0) {
                    let kw = String(data: chunkData.subdata(in: 0..<kwEnd), encoding: .ascii) ?? ""
                    if kw == pngXMPKeyword {
                        existingXMPRange = offset..<(dataStart + chunkLen + 4)
                        break
                    }
                }
            }

            if typeStr == "IEND" { break }
            offset = dataStart + chunkLen + 4
        }

        var result = Data()

        if let xmpRange = existingXMPRange {
            // Replace existing XMP chunk
            result.append(data[0..<xmpRange.lowerBound])
            result.append(iTXtChunk)
            result.append(data[xmpRange.upperBound..<data.count])
        } else if let insertAt = ihdrEnd {
            // Insert new XMP chunk after IHDR
            result.append(data[0..<insertAt])
            result.append(iTXtChunk)
            result.append(data[insertAt..<data.count])
        } else {
            throw ExifError.cannotReadFile
        }

        return result
    }

    /// Find the XMP iTXt chunk in a PNG; return (rating, fullChunkRange).
    private static func findPNGXMPChunk(in data: Data) -> (Int, Range<Int>)? {
        guard data.count > 8 else { return nil }
        guard data[0] == 0x89 && data[1] == 0x50 && data[2] == 0x4E && data[3] == 0x47 else { return nil }

        var offset = 8
        while offset + 8 <= data.count {
            let chunkLen = Int(readU32(data, at: offset, le: false))
            let typeStart = offset + 4
            let typeStr = String(data: data.subdata(in: typeStart..<typeStart + 4), encoding: .ascii) ?? "????"
            let dataStart = offset + 8
            guard dataStart + chunkLen + 4 <= data.count else { return nil }

            if typeStr == "iTXt" {
                let chunkData = data.subdata(in: dataStart..<dataStart + chunkLen)
                if let kwEnd = chunkData.firstIndex(of: 0) {
                    let kw = String(data: chunkData.subdata(in: 0..<kwEnd), encoding: .ascii) ?? ""
                    if kw == pngXMPKeyword {
                        if let xml = parsePNGiTXtText(chunkData) {
                            let rating = extractRatingFromXML(xml)
                            return (rating, offset..<(dataStart + chunkLen + 4))
                        }
                    }
                }
            }

            if typeStr == "IEND" { return nil }
            offset = dataStart + chunkLen + 4
        }
        return nil
    }

    /// Extract the text field from an iTXt chunk (uncompressed only).
    private static func parsePNGiTXtText(_ chunkData: Data) -> String? {
        guard let kwEnd = chunkData.firstIndex(of: 0) else { return nil }
        var pos = kwEnd + 1
        guard pos + 2 <= chunkData.count else { return nil }
        let compressionFlag = chunkData[pos]
        pos += 2  // skip compression flag + method
        guard compressionFlag == 0 else { return nil }  // only uncompressed

        // Skip language tag (null-terminated)
        while pos < chunkData.count && chunkData[pos] != 0 { pos += 1 }
        pos += 1
        // Skip translated keyword (null-terminated)
        while pos < chunkData.count && chunkData[pos] != 0 { pos += 1 }
        pos += 1

        guard pos < chunkData.count else { return nil }
        return String(data: chunkData.subdata(in: pos..<chunkData.count), encoding: .utf8)
    }

    /// Build the data portion of an iTXt chunk.
    private static func buildPNGiTXtData(keyword: String, text: String) -> Data {
        var d = Data()
        d.append(keyword.data(using: .ascii)!)
        d.append(0)                    // null terminator for keyword
        d.append(0)                    // compression flag (0 = uncompressed)
        d.append(0)                    // compression method
        d.append(0)                    // empty language tag + null terminator
        d.append(0)                    // empty translated keyword + null terminator
        d.append(text.data(using: .utf8)!)
        return d
    }

    /// Build a complete PNG chunk: length + type + data + CRC.
    private static func buildPNGChunk(type: String, chunkData: Data) -> Data {
        var chunk = Data()
        // Length (4 bytes, big-endian)
        let length = UInt32(chunkData.count)
        chunk.append(UInt8(truncatingIfNeeded: length >> 24))
        chunk.append(UInt8(truncatingIfNeeded: length >> 16))
        chunk.append(UInt8(truncatingIfNeeded: length >> 8))
        chunk.append(UInt8(truncatingIfNeeded: length))
        // Type (4 bytes)
        let typeData = type.data(using: .ascii)!
        chunk.append(typeData)
        // Data
        chunk.append(chunkData)
        // CRC over type + data
        var crcInput = Data()
        crcInput.append(typeData)
        crcInput.append(chunkData)
        let crc = crc32(crcInput)
        chunk.append(UInt8(truncatingIfNeeded: crc >> 24))
        chunk.append(UInt8(truncatingIfNeeded: crc >> 16))
        chunk.append(UInt8(truncatingIfNeeded: crc >> 8))
        chunk.append(UInt8(truncatingIfNeeded: crc))
        return chunk
    }

    // MARK: - Sidecar XMP (HEIC, WebP, other)

    /// Read rating from a `.xmp` sidecar next to the image.
    private static func readSidecarRating(url: URL) -> Int {
        let sidecar = sidecarURL(for: url)
        guard let data = try? Data(contentsOf: sidecar),
              let xml = String(data: data, encoding: .utf8) else { return 0 }
        return extractRatingFromXML(xml)
    }

    /// Write rating to a `.xmp` sidecar. The original image file is untouched.
    private static func writeSidecarXMPRating(url: URL, rating: Int) throws {
        let sidecar = sidecarURL(for: url)
        let xml = createMinimalXMP(rating: rating)
        guard let xmlData = xml.data(using: .utf8) else {
            throw ExifError.xmpEncodingFailed
        }
        try xmlData.write(to: sidecar, options: .atomic)
    }

    /// Path of the `.xmp` sidecar paired with `url` (whether or not it exists).
    /// Public so file-management operations (copy, trash) can keep image and
    /// sidecar together — HEIC/WebP ratings live there and would otherwise be
    /// silently stranded.
    static func sidecarURL(for url: URL) -> URL {
        url.deletingPathExtension().appendingPathExtension("xmp")
    }

    // MARK: - XMP XML helpers

    /// Extract the rating value from XMP XML.
    private static func extractRatingFromXML(_ xml: String) -> Int {
        guard let range = xml.range(of: #"<xmp:Rating>(\d)</xmp:Rating>"#,
                                    options: .regularExpression) else { return 0 }
        return Int(xml[range].filter { $0.isNumber }) ?? 0
    }

    private static func createMinimalXMP(rating: Int) -> String {
        """
        <?xpacket begin="\u{FEFF}" id="W5M0MpCehiHzreSzNTczkc9d"?>
        <x:xmpmeta xmlns:x="adobe:ns:meta/">
        <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
        <rdf:Description rdf:about=""
          xmlns:xmp="http://ns.adobe.com/xap/1.0/">
          <xmp:Rating>\(rating)</xmp:Rating>
        </rdf:Description>
        </rdf:RDF>
        </x:xmpmeta>
        <?xpacket end="w"?>
        """
    }

    private static func updateRatingInXML(_ xml: String, rating: Int) -> String {
        // Try to replace existing xmp:Rating value
        if let range = xml.range(of: #"<xmp:Rating>\d</xmp:Rating>"#, options: .regularExpression) {
            return xml.replacingCharacters(in: range, with: "<xmp:Rating>\(rating)</xmp:Rating>")
        }

        // Rating tag not found — insert before </rdf:Description>
        let insertTag = "  <xmp:Rating>\(rating)</xmp:Rating>\n"
        if let descRange = xml.range(of: "</rdf:Description>") {
            return xml.replacingCharacters(in: descRange, with: insertTag + "</rdf:Description>")
        }

        // No rdf:Description — fall back to creating fresh XMP
        return createMinimalXMP(rating: rating)
    }

    // MARK: - JPEG Segment Scanning

    private struct SegmentRange {
        let markerRange: Range<Int>  // includes marker + length + data
        let dataRange: Range<Int>    // payload only (after marker + length)
    }

    /// Find the APP1 segment containing EXIF data; return the TIFF bytes.
    private static func extractTIFFData(from data: Data) -> Data? {
        guard let seg = findSegment(in: data, namespace: "Exif") else { return nil }
        // Data() wrapper resets startIndex to 0 — slices have non-zero offsets
        let payload = Data(data[seg.dataRange])
        guard payload.count > 6 else { return nil }
        return payload.subdata(in: 6..<payload.count)
    }

    /// Find the APP1 segment containing XMP data; return its XML payload.
    private static func findXMPSegment(in data: Data) -> (SegmentRange, Data)? {
        guard let seg = findSegment(in: data, namespace: xmpNamespace) else { return nil }
        let payload = Data(data[seg.dataRange])
        guard payload.count > xmpNamespaceData.count else { return nil }
        let xml = payload.subdata(in: xmpNamespaceData.count..<payload.count)
        return (seg, xml)
    }

    /// Generic APP1 segment finder. `namespace` is the prefix after marker+length
    /// that identifies the segment type (e.g., "Exif", "http://ns.adobe.com/xap/1.0/\0").
    private static func findSegment(in data: Data, namespace: String) -> SegmentRange? {
        let nsData = namespace.data(using: .ascii) ?? Data()
        guard data.count > 4, data[0] == 0xFF, data[1] == 0xD8 else { return nil }

        var offset = 2
        while offset < data.count - 4 {
            guard data[offset] == 0xFF else { return nil }
            let marker = data[offset + 1]

            if marker == 0xDA { return nil }  // SOS — no more APP segments
            if marker == 0xD9 || (0xD0...0xD7).contains(marker) {
                offset += 2
                continue
            }

            let length = (Int(data[offset + 2]) << 8) | Int(data[offset + 3])
            let segEnd = offset + 2 + length
            guard length >= 2, segEnd <= data.count else { return nil }

            // Check if this is APP1 with matching namespace
            if marker == 0xE1 {
                let payloadStart = offset + 4
                if payloadStart + nsData.count <= data.count {
                    let prefix = data.subdata(in: payloadStart..<payloadStart + nsData.count)
                    if prefix == nsData {
                        return SegmentRange(
                            markerRange: offset..<segEnd,
                            dataRange: payloadStart..<segEnd
                        )
                    }
                }
            }

            offset = segEnd
        }
        return nil
    }

    /// Find the byte offset where APP segments end (good XMP insertion point).
    private static func findAPPSectionEnd(in data: Data) -> Int {
        guard data.count > 4, data[0] == 0xFF, data[1] == 0xD8 else { return 2 }

        var offset = 2
        while offset < data.count - 4 {
            guard data[offset] == 0xFF else { return offset }
            let marker = data[offset + 1]

            if marker == 0xDA { return offset }
            if marker == 0xD9 || (0xD0...0xD7).contains(marker) {
                offset += 2
                continue
            }

            let length = (Int(data[offset + 2]) << 8) | Int(data[offset + 3])
            guard length >= 2 else { return offset }
            offset += 2 + length

            // Stop after we've passed all APPn and COM segments
            if !((0xE0...0xEF).contains(marker) || marker == 0xFE) {
                return offset
            }
        }
        return offset
    }

    // MARK: - Binary read helpers

    private static func readU16(_ data: Data, at offset: Int, le: Bool) -> UInt16 {
        let b0 = UInt16(data[offset])
        let b1 = UInt16(data[offset + 1])
        return le ? (b0 | (b1 << 8)) : ((b0 << 8) | b1)
    }

    private static func readU32(_ data: Data, at offset: Int, le: Bool) -> UInt32 {
        let b0 = UInt32(data[offset])
        let b1 = UInt32(data[offset + 1])
        let b2 = UInt32(data[offset + 2])
        let b3 = UInt32(data[offset + 3])
        return le
            ? (b0 | (b1 << 8) | (b2 << 16) | (b3 << 24))
            : ((b0 << 24) | (b1 << 16) | (b2 << 8) | b3)
    }

    // MARK: - CRC32 (for PNG chunks)

    private static let crcTable: [UInt32] = {
        var table = [UInt32](repeating: 0, count: 256)
        for n in 0..<256 {
            var c = UInt32(n)
            for _ in 0..<8 {
                c = (c & 1 != 0) ? (0xEDB88320 ^ (c >> 1)) : (c >> 1)
            }
            table[n] = c
        }
        return table
    }()

    private static func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFFFFFF
        for byte in data {
            let idx = Int((crc ^ UInt32(byte)) & 0xFF)
            crc = crcTable[idx] ^ (crc >> 8)
        }
        return crc ^ 0xFFFFFFFF
    }
}

enum ExifError: LocalizedError {
    case cannotReadFile
    case xmpEncodingFailed

    var errorDescription: String? {
        switch self {
        case .cannotReadFile:     return "Cannot read image file."
        case .xmpEncodingFailed:  return "Failed to encode XMP metadata."
        }
    }
}
