import SwiftUI

/// `navigationDestination(for:)` registers one destination builder per *type* within a given
/// `NavigationStack`. Two different navigation targets that both happened to push a bare `String`
/// (a post id and a user id) would collide if they ever appear in the same stack — a post's detail
/// screen and a profile screen are both reachable from the feed, and a profile screen can itself
/// push a post detail. These small wrapper types give each navigation edge its own type so the two
/// destinations can never be confused with one another. Same pattern as the ecommerce Swift port's
/// `Support/NavigationReferences.swift` (`OrderReference`/`PaymentTokenReference`).
struct PostReference: Hashable {
    let postId: String
}

struct UserReference: Hashable {
    let userId: String
}

/// Registers both destinations once per `NavigationStack` root. `navigationDestination(for:)`
/// resolves for any push made from anywhere within that stack's view tree — including from a
/// screen that was itself pushed as a destination (e.g. a post pushed from the feed can push a
/// user profile, and that profile can push another post) — so attaching this once at each tab's
/// root is sufficient for the whole tab, not just its first screen.
extension View {
    func socialNavigationDestinations(config: AppConfig) -> some View {
        self
            .navigationDestination(for: PostReference.self) { reference in
                PostDetailView(config: config, postId: reference.postId)
            }
            .navigationDestination(for: UserReference.self) { reference in
                ProfileView(config: config, userId: reference.userId)
            }
    }
}
