import Foundation

/// Backs `FeedView`. Mirrors `../web/src/hooks/usePostsFeed.ts` + `useLikes.ts`'s
/// `useMyLikedPostIds` + `useFollows.ts`'s `useMyFollowingIds`, combined into one view model since
/// SwiftUI has no equivalent of React Query's cross-component cache — each screen that needs "my
/// likes"/"my follows" fetches its own batch (see `PostDetailViewModel`/`ProfileViewModel` doing
/// the same), rather than sharing one global store, matching how each of those web hooks is called
/// independently per page too.
@MainActor
final class FeedViewModel: ObservableObject {
    @Published private(set) var posts: [Post] = []
    @Published private(set) var likedPostIds: Set<String> = []
    @Published private(set) var followingIds: Set<String> = []
    @Published private(set) var isLoading = true
    @Published private(set) var isLoadingMore = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var hasMore = false
    /// Per-post/per-author in-flight guards — a single shared boolean would block toggling a
    /// *different* post/author while one toggle is in flight, which a list of many posts can't
    /// afford. Also closes a real double-tap race: `likes`/`follows` have no compound unique index
    /// (see `LikesService`/`FollowsService`), so two concurrent toggles for the same post/author
    /// before the first's check-then-act completes could each create their own row.
    @Published private(set) var togglingLikePostIds: Set<String> = []
    @Published private(set) var togglingFollowAuthorIds: Set<String> = []

    private var currentPage = 1
    private let postsService: PostsService
    private let likesService: LikesService
    private let followsService: FollowsService

    /// How often the feed polls for new posts while on screen — see `plan/build-plan.md`
    /// "Deviations from the ecommerce Swift port" item 4 for why this is polling rather than a
    /// Socket.IO subscription.
    static let pollIntervalNanoseconds: UInt64 = 8_000_000_000

    init(config: AppConfig) {
        postsService = PostsService(config: config)
        likesService = LikesService(config: config)
        followsService = FollowsService(config: config)
    }

    func loadFirstPage(currentUser: AppUser?) async {
        isLoading = true
        errorMessage = nil
        currentPage = 1
        defer { isLoading = false }
        do {
            let page = try await postsService.feed(page: currentPage)
            posts = page.posts
            hasMore = page.hasMore
        } catch {
            errorMessage = MudbaseAPIError.map(error).message
        }
        await refreshMyInteractions(currentUser: currentUser)
    }

    func loadNextPage(currentUser: AppUser?) async {
        guard hasMore, !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let nextPage = currentPage + 1
            let page = try await postsService.feed(page: nextPage)
            let existingIds = Set(posts.map(\.id))
            posts.append(contentsOf: page.posts.filter { !existingIds.contains($0.id) })
            currentPage = nextPage
            hasMore = page.hasMore
        } catch {
            errorMessage = MudbaseAPIError.map(error).message
        }
    }

    /// Re-fetches "my likes"/"my follows" — called after first load and whenever the signed-in
    /// user changes (sign in, sign out).
    func refreshMyInteractions(currentUser: AppUser?) async {
        guard let currentUser, !currentUser.isGuest else {
            likedPostIds = []
            followingIds = []
            return
        }
        likedPostIds = (try? await likesService.likedPostIds(userId: currentUser.id)) ?? []
        followingIds = (try? await followsService.followingIds(userId: currentUser.id)) ?? []
    }

    /// Prepends a brand-new post, deduped by id — matches `prependPost`'s dedupe rationale on the
    /// web (here: the composer's own optimistic insert vs. the next poll cycle re-fetching the
    /// same post from page 1).
    func prepend(_ post: Post) {
        guard !posts.contains(where: { $0.id == post.id }) else { return }
        posts.insert(post, at: 0)
    }

    func toggleLike(post: Post, currentUser: AppUser?) async -> SocialActionOutcome {
        guard let currentUser, !currentUser.isGuest else { return .requiresSignIn }
        guard !togglingLikePostIds.contains(post.id) else { return .success }
        togglingLikePostIds.insert(post.id)
        defer { togglingLikePostIds.remove(post.id) }
        do {
            let nowLiked = try await likesService.toggle(postId: post.id, userId: currentUser.id)
            let newCount = max(0, post.likesCount + (nowLiked ? 1 : -1))
            try await postsService.setLikesCount(postId: post.id, count: newCount)
            applyPostUpdate(postId: post.id) { $0.likesCount = newCount }
            if nowLiked {
                likedPostIds.insert(post.id)
            } else {
                likedPostIds.remove(post.id)
            }
            return .success
        } catch {
            return .failure(MudbaseAPIError.map(error).message)
        }
    }

    func toggleFollow(authorId: String, authorName: String, currentUser: AppUser?) async -> SocialActionOutcome {
        guard let currentUser, !currentUser.isGuest else { return .requiresSignIn }
        guard currentUser.id != authorId else { return .success }
        guard !togglingFollowAuthorIds.contains(authorId) else { return .success }
        togglingFollowAuthorIds.insert(authorId)
        defer { togglingFollowAuthorIds.remove(authorId) }
        do {
            let nowFollowing = try await followsService.toggle(currentUserId: currentUser.id, targetUserId: authorId, targetUserName: authorName)
            if nowFollowing {
                followingIds.insert(authorId)
            } else {
                followingIds.remove(authorId)
            }
            return .success
        } catch {
            return .failure((error as? LocalizedError)?.errorDescription ?? MudbaseAPIError.map(error).message)
        }
    }

    /// Runs until cancelled (SwiftUI cancels the enclosing `.task` automatically when `FeedView`
    /// disappears — e.g. the user switches tabs). Re-fetches page 1 every
    /// `pollIntervalNanoseconds` and merges any post not already in `posts` in at the front,
    /// oldest-of-the-new-batch first so multiple new posts since the last poll still land in
    /// newest-first order.
    func pollLoop(currentUser: AppUser?) async {
        while !Task.isCancelled {
            do {
                try await Task.sleep(nanoseconds: Self.pollIntervalNanoseconds)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            do {
                let page = try await postsService.feed(page: 1)
                let existingIds = Set(posts.map(\.id))
                let newPosts = page.posts.filter { !existingIds.contains($0.id) }
                if !newPosts.isEmpty {
                    posts.insert(contentsOf: newPosts, at: 0)
                }
            } catch {
                // A transient poll failure isn't worth surfacing as a page-level error — the next
                // cycle simply tries again.
            }
        }
    }

    private func applyPostUpdate(postId: String, _ mutate: (inout Post) -> Void) {
        guard let index = posts.firstIndex(where: { $0.id == postId }) else { return }
        mutate(&posts[index])
    }
}
