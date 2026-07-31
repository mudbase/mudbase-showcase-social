import Foundation
import MudbaseSDK

/// Reads and writes against the `posts` collection. Mirrors `../web/src/hooks/usePostsFeed.ts`
/// and `useCollection.ts`'s `useDocuments`/`useDocument`.
struct PostsService {
    private let gateway: CollectionsGateway

    init(config: AppConfig) {
        gateway = CollectionsGateway(projectId: config.projectId, collectionId: config.postsCollectionId)
    }

    struct Page {
        let posts: [Post]
        let pagination: Pagination?

        /// `Pagination` has no `hasMore` field (unlike the web client's hand-rolled
        /// `PaginationMeta`) — derived the same way it's computed: more pages exist while the
        /// current page is behind the total page count.
        var hasMore: Bool {
            guard let page = pagination?.page, let totalPages = pagination?.totalPages else { return false }
            return page < totalPages
        }
    }

    func feed(page: Int, limit: Int = 10) async throws(ErrorResponse) -> Page {
        let result = try await gateway.list(sort: "-createdAt", page: page, limit: limit)
        return Page(posts: result.documents.map(Post.init(document:)), pagination: result.pagination)
    }

    /// Mirrors `../web/src/components/profile/ProfilePostList.tsx`'s `PROFILE_POSTS_LIMIT` —
    /// demo-scale cap, no further pagination UI on a profile.
    func posts(byAuthor authorId: String, limit: Int = 100) async throws(ErrorResponse) -> [Post] {
        let result = try await gateway.list(filter: ["authorId": .string(authorId)], sort: "-createdAt", limit: limit)
        return result.documents.map(Post.init(document:))
    }

    /// Most recent post by this author, used by `FollowsService.resolvedDisplayName`.
    func mostRecentPost(byAuthor authorId: String) async throws(ErrorResponse) -> Post? {
        let result = try await gateway.list(filter: ["authorId": .string(authorId)], sort: "-createdAt", limit: 1)
        return result.documents.first.map(Post.init(document:))
    }

    func postCount(byAuthor authorId: String) async throws(ErrorResponse) -> Int {
        let result = try await gateway.list(filter: ["authorId": .string(authorId)], limit: 1)
        return result.pagination?.total ?? 0
    }

    func get(id: String) async throws(ErrorResponse) -> Post {
        Post(document: try await gateway.get(documentId: id))
    }

    @discardableResult
    func create(content: String, imageUrl: String?, authorId: String, authorName: String) async throws(ErrorResponse) -> Post {
        var fields: [String: JSONValue?] = [
            "authorId": .string(authorId),
            "authorName": .string(authorName),
            "content": .string(content),
            "likesCount": .int(0),
            "commentsCount": .int(0),
        ]
        if let imageUrl, !imageUrl.isEmpty { fields["imageUrl"] = .string(imageUrl) }
        return Post(document: try await gateway.create(fields: fields))
    }

    /// Writes an absolute count, not an atomic increment — Mudbase Collections have no
    /// server-side `$inc`. Callers compute the new value from their own most recently read count
    /// (see `FeedViewModel.toggleLike`/`PostDetailViewModel.submitComment`'s re-read-before-write),
    /// which under two genuinely concurrent likers/commenters on the *same* post can still
    /// under/over-count by one — the same accepted, documented tradeoff the web app's own
    /// check-then-act guards make for `likes`/`follows` (see `LikesService`/`FollowsService`).
    /// `FeedViewModel`'s per-post `togglingLikePostIds` guard closes the more likely race (one
    /// user double-tapping), not the cross-user one.
    func setLikesCount(postId: String, count: Int) async throws(ErrorResponse) {
        try await gateway.update(documentId: postId, fields: ["likesCount": .int(count)])
    }

    func setCommentsCount(postId: String, count: Int) async throws(ErrorResponse) {
        try await gateway.update(documentId: postId, fields: ["commentsCount": .int(count)])
    }
}
