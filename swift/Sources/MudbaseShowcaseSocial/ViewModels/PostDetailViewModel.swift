import Foundation

/// Backs `PostDetailView`. Mirrors `../web/src/app/posts/[id]/page.tsx` +
/// `useComments.ts`'s `useCreateComment`.
@MainActor
final class PostDetailViewModel: ObservableObject {
    static let maxCommentLength = 300

    @Published private(set) var post: Post?
    @Published private(set) var comments: [Comment] = []
    @Published private(set) var isLoading = true
    @Published private(set) var isLoadingComments = true
    @Published private(set) var errorMessage: String?
    @Published private(set) var liked = false
    @Published private(set) var isFollowingAuthor = false
    @Published var commentDraft = ""
    @Published private(set) var isSubmittingComment = false
    @Published private(set) var isTogglingLike = false
    @Published private(set) var isTogglingFollow = false
    @Published private(set) var actionMessage: String?

    let postId: String
    private let postsService: PostsService
    private let commentsService: CommentsService
    private let likesService: LikesService
    private let followsService: FollowsService

    init(config: AppConfig, postId: String) {
        self.postId = postId
        postsService = PostsService(config: config)
        commentsService = CommentsService(config: config)
        likesService = LikesService(config: config)
        followsService = FollowsService(config: config)
    }

    func load(currentUser: AppUser?) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            post = try await postsService.get(id: postId)
        } catch {
            errorMessage = "This post isn't available."
            return
        }
        await loadComments()
        await refreshMyInteractions(currentUser: currentUser)
    }

    func loadComments() async {
        isLoadingComments = true
        defer { isLoadingComments = false }
        comments = (try? await commentsService.list(postId: postId)) ?? []
    }

    func refreshMyInteractions(currentUser: AppUser?) async {
        guard let currentUser, !currentUser.isGuest, let post else {
            liked = false
            isFollowingAuthor = false
            return
        }
        let likedIds = (try? await likesService.likedPostIds(userId: currentUser.id)) ?? []
        let followingIds = (try? await followsService.followingIds(userId: currentUser.id)) ?? []
        liked = likedIds.contains(postId)
        isFollowingAuthor = followingIds.contains(post.authorId)
    }

    func toggleLike(currentUser: AppUser?) async -> SocialActionOutcome {
        guard let currentUser, !currentUser.isGuest else { return .requiresSignIn }
        guard let post, !isTogglingLike else { return .success }
        isTogglingLike = true
        defer { isTogglingLike = false }
        do {
            let nowLiked = try await likesService.toggle(postId: post.id, userId: currentUser.id)
            let newCount = max(0, post.likesCount + (nowLiked ? 1 : -1))
            try await postsService.setLikesCount(postId: post.id, count: newCount)
            self.post?.likesCount = newCount
            liked = nowLiked
            return .success
        } catch {
            let message = MudbaseAPIError.map(error).message
            actionMessage = message
            return .failure(message)
        }
    }

    func toggleFollow(currentUser: AppUser?) async -> SocialActionOutcome {
        guard let currentUser, !currentUser.isGuest else { return .requiresSignIn }
        guard let post, !isTogglingFollow, post.authorId != currentUser.id else { return .success }
        isTogglingFollow = true
        defer { isTogglingFollow = false }
        do {
            let nowFollowing = try await followsService.toggle(currentUserId: currentUser.id, targetUserId: post.authorId, targetUserName: post.authorName)
            isFollowingAuthor = nowFollowing
            return .success
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? MudbaseAPIError.map(error).message
            actionMessage = message
            return .failure(message)
        }
    }

    func submitComment(currentUser: AppUser?) async -> SocialActionOutcome {
        guard let currentUser, !currentUser.isGuest else { return .requiresSignIn }
        let trimmed = commentDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= Self.maxCommentLength, !isSubmittingComment, let post else {
            return .success
        }
        isSubmittingComment = true
        defer { isSubmittingComment = false }
        do {
            let created = try await commentsService.create(postId: post.id, authorId: currentUser.id, authorName: currentUser.displayName, content: trimmed)
            comments.append(created)
            // Re-read the post immediately before incrementing so a burst of concurrent comments
            // doesn't have both writers increment from the same stale count — same check-then-act
            // guard style as `toggleLike`, and matches `useCreateComment`'s
            // `currentPost = await client.getDocument(...)` re-read.
            let currentPost = try await postsService.get(id: post.id)
            let newCount = currentPost.commentsCount + 1
            try await postsService.setCommentsCount(postId: post.id, count: newCount)
            self.post?.commentsCount = newCount
            commentDraft = ""
            return .success
        } catch {
            let message = MudbaseAPIError.map(error).message
            actionMessage = message
            return .failure(message)
        }
    }
}
