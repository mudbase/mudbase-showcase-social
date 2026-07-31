import SwiftUI

/// Mirrors `../web/src/components/social/FollowButton.tsx`. The caller is responsible for never
/// rendering this for the signed-in user's own posts/profile (matches the web component's own
/// `if (isAuthenticated && user?.id === targetUserId) return null` guard, applied at each call
/// site here instead — see `PostCardView`/`ProfileHeaderView`).
struct FollowButtonView: View {
    let isFollowing: Bool
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(isFollowing ? "Following" : "Follow", action: action)
            .buttonStyle(.bordered)
            .tint(isFollowing ? .secondary : .accentColor)
            .controlSize(.small)
            .disabled(isDisabled)
    }
}
