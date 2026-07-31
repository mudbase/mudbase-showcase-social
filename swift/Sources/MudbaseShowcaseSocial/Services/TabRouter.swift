import Foundation

/// The SwiftUI equivalent of the web app's `router.push("/login")` redirect — `LikeButton`,
/// `FollowButton`, `PostComposer`, and `CommentComposer` all guard writes with
/// `if (!isAuthenticated) { router.push("/login"); return }`. A native `TabView` has no URL to
/// push, so a guest tapping one of those same actions instead switches to the Profile tab (which
/// renders the sign-in screen whenever `sessionStore.user` is the anonymous guest — see
/// `ProfileTabView`). Injected as an `@EnvironmentObject` from the app root so any view three
/// levels deep in the Feed tab can request the switch without threading a callback through every
/// intermediate view.
@MainActor
final class TabRouter: ObservableObject {
    enum Tab: Hashable {
        case feed
        case profile
    }

    @Published var selection: Tab = .feed

    func routeToSignIn() {
        selection = .profile
    }
}
