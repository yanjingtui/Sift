import SwiftUI

/// Three-bucket rating picker. Renders as a row of capsule buttons — one per
/// `PhotoRating` bucket — plus an explicit unrated affordance. Tapping the
/// active bucket clears the rating (sets it back to 0).
///
/// Two sizes:
/// - Default: labelled capsules, used in the detail view control bar.
/// - Compact: icon-only circles, used in the thumbnail hover overlay.
struct RatingPicker: View {
    let rating: Int
    var compact: Bool = false
    var onRate: (Int) -> Void

    var body: some View {
        HStack(spacing: compact ? 4 : 6) {
            ForEach(PhotoRating.allCases) { bucket in
                capsule(for: bucket, active: rating == bucket.rawValue)
            }
        }
    }

    @ViewBuilder
    private func capsule(for bucket: PhotoRating, active: Bool) -> some View {
        Button {
            onRate(active ? 0 : bucket.rawValue)
        } label: {
            Group {
                if compact {
                    Image(systemName: active ? filledIcon(bucket) : bucket.icon)
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 26, height: 26)
                } else {
                    Label(bucket.label, systemImage: active ? filledIcon(bucket) : bucket.icon)
                        .labelStyle(.titleAndIcon)
                        .font(.callout.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                }
            }
            .foregroundStyle(active ? .white : bucket.color)
            .background(
                (compact ? AnyShape(Circle()) : AnyShape(Capsule()))
                    .fill(active ? AnyShapeStyle(bucket.color) : AnyShapeStyle(bucket.color.opacity(0.15)))
            )
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }

    /// Pick a filled SF Symbol variant when active so the icon reads as "on".
    private func filledIcon(_ bucket: PhotoRating) -> String {
        switch bucket {
        case .maybe: return "questionmark.diamond.fill"
        case .good:  return "hand.thumbsup.fill"
        case .love:  return "heart.fill"
        }
    }
}
