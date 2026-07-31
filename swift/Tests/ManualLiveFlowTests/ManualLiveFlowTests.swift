import Foundation
import Testing
@testable import MudbaseShowcaseSocial
import MudbaseSDK

/// Standalone, headless verification that exercises this app's own `Services`/`Networking` layer
/// — the exact `AuthGateway`, `PostsService`, `CommentsService`, `LikesService`, `FollowsService`,
/// and `AccessTokenCoordinator` types the SwiftUI views and view models call — directly against
/// the real, live `cloud.mudbase.dev` project. There is no iOS Simulator in this environment, so
/// this stands in for clicking through the actual UI — the same headless-verification approach the
/// ecommerce Swift port used
/// (`../../mudbase-showcase-ecommerce/swift/Tests/ManualLiveFlowTests/ManualLiveFlowTests.swift`).
///
/// Disabled unless `RUN_LIVE_FLOW_TEST=1` is set, since it makes real network calls against a live
/// project and writes real documents (a post, a comment, a like, a follow) — a plain `swift test`
/// must never do that on its own. Run it explicitly with:
///
///   RUN_LIVE_FLOW_TEST=1 swift test --filter ManualLiveFlowTests
@Suite(.serialized)
struct ManualLiveFlowTests {
    static let isEnabled = ProcessInfo.processInfo.environment["RUN_LIVE_FLOW_TEST"] == "1"

    static let config = AppConfig(
        projectId: "6a6cf79dd07caabbbdfbe9c5",
        baseURL: URL(string: "https://cloud.mudbase.dev")!,
        postsCollectionId: "6a6cf7d0d07caabbbdfbe9db",
        commentsCollectionId: "6a6cf7d1d07caabbbdfbe9f1",
        likesCollectionId: "6a6cf81ed07caabbbdfbea20",
        followsCollectionId: "6a6cf81ed07caabbbdfbea32"
    )

    // The two already-verified accounts supplied for this build — see the task brief and
    // README "Provisioning". Logging into these instead of self-registering sidesteps the
    // tightly-rate-limited signup endpoint entirely.
    static let avaEmail = "mudhaxk+mbsocial1@gmail.com"
    static let benEmail = "mudhaxk+mbsocial2@gmail.com"
    static let sharedPassword = "SocialTest123!"

    /// Optional pre-minted token-pair fallback for both accounts, read from the environment —
    /// mirrors the task brief's own "fallback pre-minted tokens if login 429s" design (the auth
    /// endpoint's rate limit is a real, shared-IP constraint across every sibling port's own live
    /// verification runs against this same project, not specific to this build). When set, these
    /// are used instead of calling `authGateway.login`, so a rerun doesn't have to spend more of
    /// the shared per-IP budget. Each pair must be independently valid (this helper does not
    /// refresh or verify them — `AccessTokenCoordinator`'s own 401-refresh-retry handles an
    /// access token that expires mid-test, same as it would for a freshly logged-in session).
    private static func resolveSession(authGateway: AuthGateway, email: String, accessEnvKey: String, refreshEnvKey: String) async throws -> AuthGateway.LoginResult {
        let environment = ProcessInfo.processInfo.environment
        if let accessToken = environment[accessEnvKey], let refreshToken = environment[refreshEnvKey],
           !accessToken.isEmpty, !refreshToken.isEmpty {
            return AuthGateway.LoginResult(accessToken: accessToken, refreshToken: refreshToken)
        }
        return try await authGateway.login(email: email, password: sharedPassword)
    }

    @Test(.enabled(if: ManualLiveFlowTests.isEnabled))
    @MainActor
    func fullSocialFlow() async throws {
        MudbaseSDKBootstrap.configure(baseURL: Self.config.baseURL)

        let authGateway = AuthGateway(projectId: Self.config.projectId)
        let postsService = PostsService(config: Self.config)
        let commentsService = CommentsService(config: Self.config)
        let likesService = LikesService(config: Self.config)
        let followsService = FollowsService(config: Self.config)

        // --- Public read / auth-gated writes: an anonymous session can read the feed but cannot
        // create a post. ---
        let anonymousSession = try await authGateway.loginAnonymous()
        MudbaseSDKBootstrap.setAccessToken(anonymousSession.accessToken)
        let anonymousUser = try await authGateway.currentUser()
        #expect(anonymousUser.isGuest, "a freshly created anonymous session should report isGuest == true")
        _ = try await postsService.feed(page: 1, limit: 5)
        do {
            _ = try await postsService.create(content: "should never be created", imageUrl: nil, authorId: anonymousUser.id, authorName: "Anon")
            Issue.record("an anonymous session was able to create a post — expected the platform to reject this with 403")
        } catch {
            let displayable = MudbaseAPIError.map(error)
            #expect(displayable.statusCode == 403, "expected anonymous post-create to 403, got \(displayable.statusCode): \(displayable.message)")
        }

        // --- Ava signs in and creates a post ---
        let avaSession = try await Self.resolveSession(authGateway: authGateway, email: Self.avaEmail, accessEnvKey: "AVA_ACCESS_TOKEN", refreshEnvKey: "AVA_REFRESH_TOKEN")
        MudbaseSDKBootstrap.setAccessToken(avaSession.accessToken)
        let ava = try await authGateway.currentUser()
        #expect(!ava.isGuest, "Ava's login session should not be the anonymous guest")
        #expect(ava.email == Self.avaEmail)

        let uniqueSuffix = UUID().uuidString.prefix(8)
        let post = try await postsService.create(
            content: "Manual live flow test post — safe to delete (\(uniqueSuffix)).",
            imageUrl: nil,
            authorId: ava.id,
            authorName: ava.displayName
        )
        #expect(post.authorId == ava.id)

        // --- Feed read includes the just-created post ---
        let firstPage = try await postsService.feed(page: 1, limit: 20)
        #expect(firstPage.posts.contains { $0.id == post.id }, "feed read did not include the just-created post")

        // --- Ben signs in, comments, likes, and follows Ava ---
        let benSession = try await Self.resolveSession(authGateway: authGateway, email: Self.benEmail, accessEnvKey: "BEN_ACCESS_TOKEN", refreshEnvKey: "BEN_REFRESH_TOKEN")
        MudbaseSDKBootstrap.setAccessToken(benSession.accessToken)
        let ben = try await authGateway.currentUser()
        #expect(!ben.isGuest)
        #expect(ben.email == Self.benEmail)

        let comment = try await commentsService.create(postId: post.id, authorId: ben.id, authorName: ben.displayName, content: "Nice post! (manual live flow test)")
        #expect(comment.postId == post.id)
        try await postsService.setCommentsCount(postId: post.id, count: 1)

        let nowLiked = try await likesService.toggle(postId: post.id, userId: ben.id)
        #expect(nowLiked, "expected the first toggle to like the post")
        try await postsService.setLikesCount(postId: post.id, count: 1)

        // Normalize starting state: this live project is shared across every sibling port's own
        // live verification runs against these same two accounts (see `../web/plan/build-plan.md`
        // "Live smoke test results" — that run already created a real Ben-follows-Ava row, and
        // this app has no delete UI for it, matching the reference web app). Ensure Ben starts
        // this section *not* following Ava, regardless of what an earlier run left behind, so the
        // toggle below deterministically creates rather than deletes.
        if try await followsService.followingIds(userId: ben.id).contains(ava.id) {
            _ = try await followsService.toggle(currentUserId: ben.id, targetUserId: ava.id, targetUserName: ava.displayName)
        }

        let nowFollowing = try await followsService.toggle(currentUserId: ben.id, targetUserId: ava.id, targetUserName: ava.displayName)
        #expect(nowFollowing, "expected the first toggle to follow Ava")

        // --- Verify from Ben's perspective: liked ids / following ids include what was just done ---
        let benLikedIds = try await likesService.likedPostIds(userId: ben.id)
        #expect(benLikedIds.contains(post.id))
        let benFollowingIds = try await followsService.followingIds(userId: ben.id)
        #expect(benFollowingIds.contains(ava.id))

        // --- Post detail: comments (oldest-first) include Ben's comment ---
        let comments = try await commentsService.list(postId: post.id)
        #expect(comments.contains { $0.id == comment.id })

        // --- The updated post's counters persisted ---
        let refetchedPost = try await postsService.get(id: post.id)
        #expect(refetchedPost.likesCount == 1)
        #expect(refetchedPost.commentsCount == 1)

        // --- Ava's follower count reflects Ben's follow ---
        let avaFollowerCount = try await followsService.followerCount(userId: ava.id)
        #expect(avaFollowerCount >= 1)

        // --- Resolved display name for Ava (from her post's authorName) ---
        let resolvedName = await followsService.resolvedDisplayName(userId: ava.id, postsService: postsService)
        #expect(resolvedName == ava.displayName)

        // --- 401 refresh-and-retry: force the in-memory access token invalid, keep the real
        // refresh token in a scratch Keychain entry, and confirm `AccessTokenCoordinator`
        // transparently refreshes and retries once instead of the call failing outright. This is
        // the exact policy `AccessTokenCoordinator`'s doc comment describes — applied here to a
        // plain feed read rather than a write, since reads are just as authenticated a call as
        // writes are in this app (both a real session and an anonymous one carry a refresh
        // token). ---
        let scratchTokenStore = KeychainTokenStore(service: "dev.mudbase.showcase.social.manualtest")
        scratchTokenStore.save(.init(accessToken: benSession.accessToken, refreshToken: benSession.refreshToken))
        await AccessTokenCoordinator.shared.configure(authGateway: authGateway, tokenStore: scratchTokenStore)
        MudbaseSDKBootstrap.setAccessToken("this-access-token-is-intentionally-invalid")
        let postsAfterForcedExpiry = try await postsService.feed(page: 1, limit: 5)
        #expect(!postsAfterForcedExpiry.posts.isEmpty, "a call made with a deliberately invalid access token did not recover via refresh-and-retry")
        scratchTokenStore.clear()

        // --- Cleanup: unlike / unfollow (toggle back), matching real user behavior. The current
        // access token is already Ben's — the coordinator's refresh above set it via
        // `MudbaseSDKBootstrap.setAccessToken` internally, so no re-assignment is needed here.
        // Posts/comments have no delete UI in this app (same as the web reference) so they're left
        // in place, clearly labeled as test data in their content string. ---
        let unliked = try await likesService.toggle(postId: post.id, userId: ben.id)
        #expect(!unliked)
        let unfollowed = try await followsService.toggle(currentUserId: ben.id, targetUserId: ava.id, targetUserName: ava.displayName)
        #expect(!unfollowed)

        // --- Sign out both accounts (best-effort) ---
        try? await authGateway.logout()
    }
}
