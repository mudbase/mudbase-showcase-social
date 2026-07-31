import Foundation

/// Backs `ProfileView`. Mirrors `../web/src/app/users/[userId]/page.tsx` +
/// `useProfileStats.ts`.
@MainActor
final class ProfileViewModel: ObservableObject {
    let userId: String

    @Published private(set) var displayName = "Member"
    @Published private(set) var followerCount = 0
    @Published private(set) var followingCount = 0
    @Published private(set) var posts: [Post] = []
    @Published private(set) var likedPostIds: Set<String> = []
    @Published private(set) var isFollowing = false
    @Published private(set) var isLoading = true
    @Published private(set) var errorMessage: String?
    @Published private(set) var isTogglingFollow = false

    private let postsService: PostsService
    private let followsService: FollowsService
    private let likesService: LikesService

    var postCount: Int { posts.count }

    init(config: AppConfig, userId: String) {
        self.userId = userId
        postsService = PostsService(config: config)
        followsService = FollowsService(config: config)
        likesService = LikesService(config: config)
    }

    func load(currentUser: AppUser?) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            posts = try await postsService.posts(byAuthor: userId)
        } catch {
            errorMessage = MudbaseAPIError.map(error).message
        }
        displayName = await followsService.resolvedDisplayName(userId: userId, postsService: postsService)
        followerCount = (try? await followsService.followerCount(userId: userId)) ?? 0
        followingCount = (try? await followsService.followingCount(userId: userId)) ?? 0

        guard let currentUser, !currentUser.isGuest else {
            isFollowing = false
            likedPostIds = []
            return
        }
        let followingIds = (try? await followsService.followingIds(userId: currentUser.id)) ?? []
        isFollowing = followingIds.contains(userId)
        likedPostIds = (try? await likesService.likedPostIds(userId: currentUser.id)) ?? []
    }

    func toggleFollow(currentUser: AppUser?) async -> SocialActionOutcome {
        guard let currentUser, !currentUser.isGuest else { return .requiresSignIn }
        guard !isTogglingFollow, currentUser.id != userId else { return .success }
        isTogglingFollow = true
        defer { isTogglingFollow = false }
        do {
            let nowFollowing = try await followsService.toggle(currentUserId: currentUser.id, targetUserId: userId, targetUserName: displayName)
            isFollowing = nowFollowing
            followerCount = max(0, followerCount + (nowFollowing ? 1 : -1))
            return .success
        } catch {
            return .failure((error as? LocalizedError)?.errorDescription ?? MudbaseAPIError.map(error).message)
        }
    }

    func toggleLike(post: Post, currentUser: AppUser?) async -> SocialActionOutcome {
        guard let currentUser, !currentUser.isGuest else { return .requiresSignIn }
        do {
            let nowLiked = try await likesService.toggle(postId: post.id, userId: currentUser.id)
            let newCount = max(0, post.likesCount + (nowLiked ? 1 : -1))
            try await postsService.setLikesCount(postId: post.id, count: newCount)
            if let index = posts.firstIndex(where: { $0.id == post.id }) {
                posts[index].likesCount = newCount
            }
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
}
