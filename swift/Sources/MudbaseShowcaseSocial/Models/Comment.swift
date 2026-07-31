import Foundation

/// Mirrors `../web/src/types/comment.ts`'s `Comment` interface.
struct Comment: Identifiable, Equatable, Sendable {
    let id: String
    let postId: String
    let authorId: String
    let authorName: String
    let content: String
    let createdAt: Date?

    init(document: MudbaseDocument) {
        id = document.id
        postId = document.string("postId") ?? ""
        authorId = document.string("authorId") ?? ""
        authorName = document.string("authorName") ?? ""
        content = document.string("content") ?? ""
        createdAt = document.createdAt
    }
}
