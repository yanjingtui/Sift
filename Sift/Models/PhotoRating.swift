import SwiftUI

/// Three-bucket rating system surfaced in the UI. The underlying XMP value
/// stays on the standard 0-5 star scale so files remain compatible with
/// Lightroom, Bridge, Windows Explorer, and exiftool. Sift only ever writes
/// 0/1/3/5; values 2 and 4 (which other tools may produce) are normalised on
/// read so the picker always shows a clean three-way choice.
enum PhotoRating: Int, CaseIterable, Identifiable {
    case maybe = 1   // "Maybe" — keep for now, decide later
    case good  = 3   // "Good"  — decent shot
    case love  = 5   // "Love"  — standout

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .maybe: return String(localized: "Maybe")
        case .good:  return String(localized: "Good")
        case .love:  return String(localized: "Love")
        }
    }

    var icon: String {
        switch self {
        case .maybe: return "questionmark.diamond"
        case .good:  return "hand.thumbsup"
        case .love:  return "heart"
        }
    }

    var color: Color {
        switch self {
        case .maybe: return .blue
        case .good:  return .green
        case .love:  return .pink
        }
    }

    /// Map any 0-5 value onto the three-bucket scale.
    /// Returns nil for 0 (unrated). 2 → maybe, 4 → good for forward-compat.
    static func from(rating: Int) -> PhotoRating? {
        switch rating {
        case 0:         return nil
        case 1, 2:      return .maybe
        case 3, 4:      return .good
        default:        return .love
        }
    }

    /// Collapse a raw rating to one of {0, 1, 3, 5}. Applied on read so the
    /// in-memory model never carries 2 or 4.
    static func normalize(_ rating: Int) -> Int {
        from(rating: rating)?.rawValue ?? 0
    }
}
