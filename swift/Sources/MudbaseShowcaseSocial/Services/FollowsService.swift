import Foundation
import MudbaseSDK

/// Reads and writes against the `follows` collection. Mirrors `../web/src/hooks/useFollows.ts`
/// and `useProfileStats.ts`.
struct FollowsService {
    private let gateway: CollectionsGateway

    /// Demo-scale cap, matching the web app's own `MINE_LIMIT` (see `LikesService`).
    private static let mineLimit = 500

    init(config: AppConfig) {
        gateway = CollectionsGateway(projectId: config.projectId, collectionId: config.followsCollectionId)
    }

    /// The signed-in user's own "who am I following" ids. Mirrors `useMyFollowingIds`.
    func followingIds(userId: String) async throws(ErrorResponse) -> Set<String> {
        let result = try await gateway.list(filter: ["followerId": .string(userId)], limit: Self.mineLimit)
        return Set(result.documents.compactMap { $0.string("followingId") })
    }

    /// Counts read via `pagination.total` on a `limit: 1` query rather than pulling every row —
    /// cheap, and correct regardless of how many follow rows exist. Mirrors `useFollowCounts`.
    func followerCount(userId: String) async throws(ErrorResponse) -> Int {
        let result = try await gateway.list(filter: ["followingId": .string(userId)], limit: 1)
        return result.pagination?.total ?? 0
    }

    func followingCount(userId: String) async throws(ErrorResponse) -> Int {
        let result = try await gateway.list(filter: ["followerId": .string(userId)], limit: 1)
        return result.pagination?.total ?? 0
    }

    enum FollowError: Error, LocalizedError {
        case cannotFollowSelf
        var errorDescription: String? {
            switch self {
            case .cannotFollowSelf: return "You can't follow yourself."
            }
        }
    }

    /// Check-then-act against the server, same race-guard rationale as `LikesService.toggle`.
    /// Returns whether the target is now followed. Mirrors `useToggleFollow`.
    func toggle(currentUserId: String, targetUserId: String, targetUserName: String) async throws -> Bool {
        guard currentUserId != targetUserId else { throw FollowError.cannotFollowSelf }
        let existing = try await gateway.list(filter: ["followerId": .string(currentUserId), "followingId": .string(targetUserId)], limit: 1)
        if let match = existing.documents.first {
            try await gateway.delete(documentId: match.id)
            return false
        }
        try await gateway.create(fields: [
            "followerId": .string(currentUserId),
            "followingId": .string(targetUserId),
            "followingName": .string(targetUserName),
        ])
        return true
    }

    /// A profile page has no `users` collection to read a display name from — every author/
    /// commenter/follower name in this data model is denormalized onto the row that references
    /// them. Resolves the best available name for a given userId: their most recent post's
    /// `authorName`, or failing that any `followingName` recorded by someone who follows them, or
    /// the literal string `"Member"`. Mirrors `useResolvedDisplayName`'s exact fallback chain
    /// (implemented here as a plain client-side scan over a bounded page of `follows` rows rather
    /// than the web version's Mongo `$exists`/`$ne` filter operators, which this app's simpler
    /// `CollectionsGateway.list(filter:)` doesn't attempt to model — same result, simpler filter).
    func resolvedDisplayName(userId: String, postsService: PostsService) async -> String {
        if let mostRecentPost = try? await postsService.mostRecentPost(byAuthor: userId),
           !mostRecentPost.authorName.isEmpty {
            return mostRecentPost.authorName
        }
        if let result = try? await gateway.list(filter: ["followingId": .string(userId)], limit: 50),
           let name = result.documents.compactMap({ $0.string("followingName") }).first(where: { !$0.isEmpty }) {
            return name
        }
        return "Member"
    }
}
