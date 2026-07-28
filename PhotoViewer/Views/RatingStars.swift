import SwiftUI

/// Reusable star rating component.
/// Supports display-only and interactive modes.
struct RatingStars: View {
    let rating: Int
    var size: CGFloat = 14
    var interactive: Bool = false
    var onRate: ((Int) -> Void)? = nil

    var body: some View {
        HStack(spacing: size * 0.15) {
            ForEach(1...5, id: \.self) { star in
                Image(systemName: star <= rating ? "star.fill" : "star")
                    .font(.system(size: size))
                    .foregroundStyle(star <= rating ? .yellow : .secondary)
                    .if(interactive) { view in
                        view
                            .contentShape(Rectangle())
                            .onTapGesture { onRate?(star) }
                    }
            }
        }
    }
}

// MARK: - Conditional modifier helper

private extension View {
    @ViewBuilder
    func `if`<Transform: View>(_ condition: Bool, transform: (Self) -> Transform) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
