import Foundation

/// The result of any auth-gated write attempt (like, follow, post, comment) initiated from a view
/// model. Mirrors the web app's own gating shape (`if (!isAuthenticated) { router.push("/login");
/// return }` inside `LikeButton`/`FollowButton`/`PostComposer`/`CommentComposer`) — a guest tapping
/// one of these actions isn't a network failure, it's a routing decision the view makes (switch
/// `TabRouter` to the Profile tab's sign-in screen), so it gets its own case rather than being
/// folded into `.failure`.
enum SocialActionOutcome: Equatable {
    case success
    case requiresSignIn
    case failure(String)
}
