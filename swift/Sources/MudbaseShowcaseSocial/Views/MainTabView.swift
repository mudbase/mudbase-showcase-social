import SwiftUI

/// Two tabs: Feed (always browsable, real or guest) and Profile (the signed-in user's own profile,
/// or the sign-in screen while still a guest — see `ProfileTabView`).
struct MainTabView: View {
    let config: AppConfig
    let user: AppUser
    @EnvironmentObject private var tabRouter: TabRouter

    var body: some View {
        TabView(selection: $tabRouter.selection) {
            NavigationStack {
                FeedView(config: config)
                    .socialNavigationDestinations(config: config)
            }
            .tabItem { Label("Feed", systemImage: "text.bubble.fill") }
            .tag(TabRouter.Tab.feed)

            ProfileTabView(config: config)
                .tabItem {
                    Label(
                        user.isGuest ? "Sign In" : "Profile",
                        systemImage: user.isGuest ? "person.crop.circle.badge.plus" : "person.crop.circle.fill"
                    )
                }
                .tag(TabRouter.Tab.profile)
        }
    }
}

/// The Profile tab's root content: the signed-in user's own `ProfileView` once real, or
/// `AuthGateView` while the session is still the anonymous guest.
private struct ProfileTabView: View {
    let config: AppConfig
    @EnvironmentObject private var sessionStore: SessionStore

    var body: some View {
        NavigationStack {
            Group {
                if let user = sessionStore.user, !user.isGuest {
                    ProfileView(config: config, userId: user.id)
                } else {
                    AuthGateView()
                }
            }
            .socialNavigationDestinations(config: config)
        }
    }
}
