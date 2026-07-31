/// Mirrors the web app's `Comment` (`web/src/types/comment.ts`) and the live
/// `comments` collection schema - `postId`, `authorId`, `authorName`,
/// `content`. One row per comment; the post-detail screen sorts these
/// oldest-first (`sort: "createdAt"`, ascending), same as the web app.
class Comment {
  const Comment({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.authorName,
    required this.content,
    required this.createdAt,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['_id'] as String? ?? '',
      postId: json['postId'] as String? ?? '',
      authorId: json['authorId'] as String? ?? '',
      authorName: json['authorName'] as String? ?? '',
      content: json['content'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  final String id;
  final String postId;
  final String authorId;
  final String authorName;
  final String content;
  final DateTime createdAt;
}
