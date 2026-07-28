import Foundation

/// Reads and writes photo star ratings via XMP metadata embedded in JPEG files.
///
/// ImageIO's CGImageDestination does not support the EXIF Rating tag (0x4746),
/// so we write **XMP Rating** (`xmp:Rating`) as a separate APP1 segment instead.
/// This is what exiftool, Lightroom, and Bridge use, and Windows Explorer
/// reads it natively via the `System.Rating` shell property.
///
/// For reading, we check XMP first, then fall back to a binary scan of the
/// EXIF IFD0 for tag 0x4746 (files rated by older tools that wrote EXIF directly).
enum ExifService {

    // XMP namespace identifier (null-terminated, 29 bytes)
    private static let xmpNamespace = "http://ns.adobe.com/xap/1.0/\0"
    private static let xmpNamespaceData = xmpNamespace.data(using: .ascii)!

    // EXIF Rating tag ID (for fallback binary read)
    private static let exifRatingTag: UInt16 = 0x4746

    // MARK: - Public API

    static func readRating(url: URL) -> Int {
        guard let data = try? Data(contentsOf: url) else { return 0 }
        if let xmp = readXMPRating(from: data), xmp > 0 { return xmp }
        return readEXIFRating(from: data)
    }

    static func writeRating(url: URL, rating: Int) throws {
        guard let jpegData = try? Data(contentsOf: url) else {
            throw ExifError.cannotReadFile
        }
        let modified = try writeXMPRating(to: jpegData, rating: rating)
        try modified.write(to: url, options: .atomic)
    }

    // MARK: - XMP Read

    /// Extract `xmp:Rating` from the XMP APP1 segment.
    private static func readXMPRating(from data: Data) -> Int? {
        guard let (_, xml) = findXMPSegment(in: data) else { return nil }
        guard let str = String(data: xml, encoding: .utf8) else { return nil }

        // Simple regex: <xmp:Rating>N</xmp:Rating>
        if let range = str.range(of: #"<xmp:Rating>(\d)</xmp:Rating>"#,
                                options: .regularExpression) {
            let match = str[range]
            let numStr = match.filter { $0.isNumber }
            return Int(numStr)
        }
        return nil
    }

    // MARK: - XMP Write

    /// Add or update the XMP Rating in a JPEG's APP1 segment.
    private static func writeXMPRating(to data: Data, rating: Int) throws -> Data {
        if let (range, xml) = findXMPSegment(in: data) {
            // Update existing XMP
            let updated = updateRatingInXML(String(data: xml, encoding: .utf8) ?? "", rating: rating)
            guard let updatedData = updated.data(using: .utf8) else {
                throw ExifError.xmpEncodingFailed
            }

            // Rebuild the XMP segment
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

    // MARK: - XMP XML helpers

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

    // MARK: - EXIF Binary Read (fallback)

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

    // MARK: - JPEG Segment Scanning

    private struct SegmentRange {
        let markerRange: Range<Int>  // includes marker + length + data
        let dataRange: Range<Int>    // payload only (after marker + length)
    }

    /// Find the APP1 segment containing EXIF data; return the TIFF bytes.
    private static func extractTIFFData(from data: Data) -> Data? {
        guard let seg = findSegment(in: data, namespace: "Exif") else { return nil }
        let payload = data[seg.dataRange]
        // Exif segment starts with "Exif\0\0" (6 bytes), then TIFF data
        guard payload.count > 6 else { return nil }
        return payload.subdata(in: 6..<payload.count)
    }

    /// Find the APP1 segment containing XMP data; return its XML payload.
    private static func findXMPSegment(in data: Data) -> (SegmentRange, Data)? {
        guard let seg = findSegment(in: data, namespace: xmpNamespace) else { return nil }
        let payload = data[seg.dataRange]
        // Skip namespace (29 bytes), rest is XML
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
            guard segEnd <= data.count else { return nil }

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
