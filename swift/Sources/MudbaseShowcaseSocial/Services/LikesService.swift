import Foundation
import MudbaseSDK

/// Reads and writes against the `likes` collection. Mirrors `../web/src/hooks/useLikes.ts`.
struct LikesService {
    private let gateway: CollectionsGateway

    /// Demo-scale cap, matching the web app's own `MINE_LIMIT` — this app has no pagination UI
    /// for "posts I've liked," so one bounded page covers every like a demo/smoke-tested account
    /// will ever create.
    private static let mineLimit = 500

    init(config: AppConfig) {
        gateway = CollectionsGateway(projectId: config.projectId, collectionId: config.likesCollectionId)
    }

    /// The signed-in user's own liked-post ids, fetched once per screen and reused by every post
    /// card rendered on it — avoids one query per post, matching
    /// `useMyLikedPostIds`.
    func likedPostIds(userId: String) async throws(ErrorResponse) -> Set<String> {
        let result = try await gateway.list(filter: ["userId": .string(userId)], limit: Self.mineLimit)
        return Set(result.documents.compactMap { $0.string("postId") })
    }

    /// Check-then-act against the server (not just a local cache) right before mutating —
    /// reasonable protection against a double-tap race creating two like rows for the same
    /// (postId, userId), since this collection type has no compound unique index. Returns whether
    /// the post is now liked (mirrors `useToggleLike`'s return shape).
    func toggle(postId: String, userId: String) async throws(ErrorResponse) -> Bool {
        let existing = try await gateway.list(filter: ["postId": .string(postId), "userId": .string(userId)], limit: 1)
        if let match = existing.documents.first {
            try await gateway.delete(documentId: match.id)
            return false
        }
        try await gateway.create(fields: ["postId": .string(postId), "userId": .string(userId)])
        return true
    }
}
