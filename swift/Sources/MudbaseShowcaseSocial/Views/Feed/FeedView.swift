import SwiftUI

/// Mirrors `../web/src/components/feed/FeedList.tsx` + `PostComposer.tsx` combined onto one
/// screen, the same way `../web/src/app/page.tsx` composes them. Public read — the composer only
/// renders for a real signed-in user; a guest tapping Like/Follow gets routed to the Profile tab's
/// sign-in screen via `TabRouter` instead of the write silently failing.
struct FeedView: View {
    let config: AppConfig
    @EnvironmentObject private var sessionStore: SessionStore
    @EnvironmentObject private var tabRouter: TabRouter
    @StateObject private var viewModel: FeedViewModel

    init(config: AppConfig) {
        self.config = config
        _viewModel = StateObject(wrappedValue: FeedViewModel(config: config))
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if let user = sessionStore.user, !user.isGuest {
                    PostComposerView(config: config, currentUser: user) { post in
                        viewModel.prepend(post)
                    }
                }

                content
            }
            .padding()
        }
        .navigationTitle("Feed")
        .refreshable { await viewModel.loadFirstPage(currentUser: sessionStore.user) }
        .task { await viewModel.loadFirstPage(currentUser: sessionStore.user) }
        .task(id: sessionStore.user?.id) { await viewModel.refreshMyInteractions(currentUser: sessionStore.user) }
        .task { await viewModel.pollLoop(currentUser: sessionStore.user) }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            LoadingView()
        } else if let errorMessage = viewModel.errorMessage {
            InlineErrorView(message: errorMessage) {
                Task { await viewModel.loadFirstPage(currentUser: sessionStore.user) }
            }
        } else if viewModel.posts.isEmpty {
            EmptyStateView(message: "No posts yet — be the first to share something.")
        } else {
            ForEach(viewModel.posts) { post in
                PostCardView(
                    post: post,
                    liked: viewModel.likedPostIds.contains(post.id),
                    isFollowingAuthor: viewModel.followingIds.contains(post.authorId),
                    showFollowButton: sessionStore.user?.id != post.authorId,
                    isLikeActionDisabled: viewModel.togglingLikePostIds.contains(post.id),
                    isFollowActionDisabled: viewModel.togglingFollowAuthorIds.contains(post.authorId),
                    onToggleLike: { handleLike(post: post) },
                    onToggleFollow: { handleFollow(post: post) }
                )
            }

            if viewModel.hasMore {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .task { await viewModel.loadNextPage(currentUser: sessionStore.user) }
            }
        }
    }

    private func handleLike(post: Post) {
        Task {
            let outcome = await viewModel.toggleLike(post: post, currentUser: sessionStore.user)
            if outcome == .requiresSignIn { tabRouter.routeToSignIn() }
        }
    }

    private func handleFollow(post: Post) {
        Task {
            let outcome = await viewModel.toggleFollow(authorId: post.authorId, authorName: post.authorName, currentUser: sessionStore.user)
            if outcome == .requiresSignIn { tabRouter.routeToSignIn() }
        }
    }
}
