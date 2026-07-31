import Foundation
import MudbaseSDK

/// Reads and writes against the `comments` collection. Mirrors `../web/src/hooks/useComments.ts`.
struct CommentsService {
    private let gateway: CollectionsGateway

    init(config: AppConfig) {
        gateway = CollectionsGateway(projectId: config.projectId, collectionId: config.commentsCollectionId)
    }

    /// Oldest first, like a normal comment thread — newest replies land at the bottom.
    func list(postId: String, limit: Int = 200) async throws(ErrorResponse) -> [Comment] {
        let result = try await gateway.list(filter: ["postId": .string(postId)], sort: "createdAt", limit: limit)
        return result.documents.map(Comment.init(document:))
    }

    @discardableResult
    func create(postId: String, authorId: String, authorName: String, content: String) async throws(ErrorResponse) -> Comment {
        Comment(document: try await gateway.create(fields: [
            "postId": .string(postId),
            "authorId": .string(authorId),
            "authorName": .string(authorName),
            "content": .string(content),
        ]))
    }
}
