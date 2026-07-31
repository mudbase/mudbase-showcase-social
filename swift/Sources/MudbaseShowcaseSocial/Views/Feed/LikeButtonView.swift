import SwiftUI

/// Mirrors `../web/src/components/social/LikeButton.tsx`. Purely presentational — the caller
/// decides what tapping it does (toggle, or route a guest to sign in), matching how the web
/// component's own `onClick` branches on `isAuthenticated` before ever calling the mutation.
struct LikeButtonView: View {
    let liked: Bool
    let count: Int
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("\(count)", systemImage: liked ? "heart.fill" : "heart")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(liked ? .red : .secondary)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .accessibilityLabel(liked ? "Unlike post" : "Like post")
    }
}
