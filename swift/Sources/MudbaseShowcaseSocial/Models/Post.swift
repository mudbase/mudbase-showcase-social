import Foundation

/// Mirrors `../web/src/types/post.ts`'s `Post` interface. `likesCount`/`commentsCount` are `var`
/// (not `let`) deliberately: `PostDetailViewModel`/`FeedViewModel` apply a local counter update to
/// their own `@Published` copy immediately after a successful like/comment write (each copy is an
/// independent value — this does not mutate any shared state, just this one in-memory instance),
/// the same "optimistic-ish, but only after the write actually succeeds" pattern
/// `updatePostEverywhere` uses on the web via `queryClient.setQueryData`.
struct Post: Identifiable, Equatable, Sendable {
    let id: String
    let authorId: String
    let authorName: String
    let content: String
    var imageUrl: String?
    var likesCount: Int
    var commentsCount: Int
    let createdAt: Date?

    init(id: String, authorId: String, authorName: String, content: String, imageUrl: String?, likesCount: Int, commentsCount: Int, createdAt: Date?) {
        self.id = id
        self.authorId = authorId
        self.authorName = authorName
        self.content = content
        self.imageUrl = imageUrl
        self.likesCount = likesCount
        self.commentsCount = commentsCount
        self.createdAt = createdAt
    }

    init(document: MudbaseDocument) {
        id = document.id
        authorId = document.string("authorId") ?? ""
        authorName = document.string("authorName") ?? ""
        content = document.string("content") ?? ""
        imageUrl = document.string("imageUrl")
        likesCount = document.int("likesCount") ?? 0
        commentsCount = document.int("commentsCount") ?? 0
        createdAt = document.createdAt
    }
}
