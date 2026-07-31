/// Mirrors the web app's `Post` (`web/src/types/post.ts`) and the live
/// `posts` collection schema (`authorId`, `authorName`, `content`,
/// `imageUrl?`, `likesCount`, `commentsCount`) - confirmed field-for-field
/// against the real server response in this build's own smoke test (see
/// `plan/build-plan.md`).
class Post {
  const Post({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.content,
    required this.imageUrl,
    required this.likesCount,
    required this.commentsCount,
    required this.createdAt,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['_id'] as String? ?? '',
      authorId: json['authorId'] as String? ?? '',
      authorName: json['authorName'] as String? ?? '',
      content: json['content'] as String? ?? '',
      imageUrl: json['imageUrl'] as String?,
      likesCount: (json['likesCount'] as num?)?.toInt() ?? 0,
      commentsCount: (json['commentsCount'] as num?)?.toInt() ?? 0,
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  final String id;
  final String authorId;
  final String authorName;
  final String content;
  final String? imageUrl;
  final int likesCount;
  final int commentsCount;
  final DateTime createdAt;

  /// Immutable update helper - used when a `db:update`/mutation result needs
  /// to patch a cached copy of this post (e.g. a new `likesCount`) without
  /// mutating the original, per this project's immutability rule.
  Post copyWith({
    String? content,
    String? imageUrl,
    int? likesCount,
    int? commentsCount,
  }) {
    return Post(
      id: id,
      authorId: authorId,
      authorName: authorName,
      content: content ?? this.content,
      imageUrl: imageUrl ?? this.imageUrl,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      createdAt: createdAt,
    );
  }
}
