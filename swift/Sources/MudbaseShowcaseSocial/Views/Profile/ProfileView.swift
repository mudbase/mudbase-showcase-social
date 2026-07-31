import SwiftUI

/// Mirrors `../web/src/app/users/[userId]/page.tsx` + `ProfilePostList.tsx`. Serves both "my
/// profile" (the Profile tab, for the signed-in user's own `userId`) and "someone else's profile"
/// (pushed from a `PostCardView`'s author link anywhere in the app), matching how the web route is
/// a single dynamic `[userId]` page either way.
struct ProfileView: View {
    let config: AppConfig
    @EnvironmentObject private var sessionStore: SessionStore
    @EnvironmentObject private var tabRouter: TabRouter
    @StateObject private var viewModel: ProfileViewModel

    init(config: AppConfig, userId: String) {
        self.config = config
        _viewModel = StateObject(wrappedValue: ProfileViewModel(config: config, userId: userId))
    }

    private var isOwnProfile: Bool { sessionStore.user?.id == viewModel.userId }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ProfileHeaderView(
                    displayName: viewModel.displayName,
                    followerCount: viewModel.followerCount,
                    followingCount: viewModel.followingCount,
                    postCount: viewModel.postCount,
                    showFollowButton: !isOwnProfile,
                    isFollowing: viewModel.isFollowing,
                    isFollowActionDisabled: viewModel.isTogglingFollow,
                    onToggleFollow: { handleFollow() }
                )

                if viewModel.isLoading {
                    LoadingView()
                } else if let errorMessage = viewModel.errorMessage {
                    InlineErrorView(message: errorMessage) { Task { await viewModel.load(currentUser: sessionStore.user) } }
                } else if viewModel.posts.isEmpty {
                    EmptyStateView(message: "No posts yet.")
                } else {
                    VStack(spacing: 12) {
                        ForEach(viewModel.posts) { post in
                            // No outer NavigationLink here — `PostCardView` already exposes its
                            // own comment-count NavigationLink to post detail (same as FeedView).
                            // Wrapping the whole card would nest a NavigationLink around this
                            // card's own Like button and author-avatar NavigationLink, making tap
                            // targets ambiguous.
                            PostCardView(
                                post: post,
                                liked: viewModel.likedPostIds.contains(post.id),
                                isFollowingAuthor: viewModel.isFollowing,
                                showFollowButton: false,
                                isLikeActionDisabled: false,
                                isFollowActionDisabled: true,
                                onToggleLike: { handleLike(post: post) },
                                onToggleFollow: {}
                            )
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle(viewModel.displayName)
        .inlineNavigationTitle()
        .toolbar {
            if isOwnProfile {
                ToolbarItem(placement: .primaryAction) {
                    Button("Sign Out") { Task { await sessionStore.logout() } }
                }
            }
        }
        // `.task(id:)` alone covers both the initial load (it also fires on first appearance)
        // and a reload whenever the signed-in user changes (sign in from guest, sign out) — a
        // second plain `.task` here would just duplicate the initial fetch.
        .task(id: sessionStore.user?.id) { await viewModel.load(currentUser: sessionStore.user) }
    }

    private func handleFollow() {
        Task {
            let outcome = await viewModel.toggleFollow(currentUser: sessionStore.user)
            if outcome == .requiresSignIn { tabRouter.routeToSignIn() }
        }
    }

    private func handleLike(post: Post) {
        Task {
            let outcome = await viewModel.toggleLike(post: post, currentUser: sessionStore.user)
            if outcome == .requiresSignIn { tabRouter.routeToSignIn() }
        }
    }
}
