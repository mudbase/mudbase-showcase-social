import SwiftUI

/// Mirrors `../web/src/app/posts/[id]/page.tsx`.
struct PostDetailView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @EnvironmentObject private var tabRouter: TabRouter
    @StateObject private var viewModel: PostDetailViewModel

    init(config: AppConfig, postId: String) {
        _viewModel = StateObject(wrappedValue: PostDetailViewModel(config: config, postId: postId))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if viewModel.isLoading {
                    LoadingView()
                } else if let errorMessage = viewModel.errorMessage {
                    InlineErrorView(message: errorMessage)
                } else if let post = viewModel.post {
                    PostCardView(
                        post: post,
                        liked: viewModel.liked,
                        isFollowingAuthor: viewModel.isFollowingAuthor,
                        showFollowButton: sessionStore.user?.id != post.authorId,
                        linkToDetail: false,
                        isLikeActionDisabled: viewModel.isTogglingLike,
                        isFollowActionDisabled: viewModel.isTogglingFollow,
                        onToggleLike: { handleLike() },
                        onToggleFollow: { handleFollow() }
                    )

                    Divider()

                    Text("Comments")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    CommentComposerView(
                        viewModel: viewModel,
                        isSignedIn: sessionStore.isSignedIn,
                        onRequiresSignIn: { tabRouter.routeToSignIn() },
                        onSubmit: { Task { await viewModel.submitComment(currentUser: sessionStore.user) } }
                    )

                    if viewModel.isLoadingComments {
                        LoadingView()
                    } else if viewModel.comments.isEmpty {
                        EmptyStateView(message: "No comments yet — start the conversation.")
                    } else {
                        VStack(spacing: 12) {
                            ForEach(viewModel.comments) { comment in
                                CommentRowView(comment: comment)
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .inlineNavigationTitle()
        .navigationTitle("Post")
        .task { await viewModel.load(currentUser: sessionStore.user) }
        .task(id: sessionStore.user?.id) { await viewModel.refreshMyInteractions(currentUser: sessionStore.user) }
    }

    private func handleLike() {
        Task {
            let outcome = await viewModel.toggleLike(currentUser: sessionStore.user)
            if outcome == .requiresSignIn { tabRouter.routeToSignIn() }
        }
    }

    private func handleFollow() {
        Task {
            let outcome = await viewModel.toggleFollow(currentUser: sessionStore.user)
            if outcome == .requiresSignIn { tabRouter.routeToSignIn() }
        }
    }
}
