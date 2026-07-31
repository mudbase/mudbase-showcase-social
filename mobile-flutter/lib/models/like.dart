/// Mirrors the web app's `Like` (`web/src/types/like.ts`) and the live
/// `likes` collection schema - `postId`, `userId`. One row per (postId,
/// userId) pair; this collection type has no compound unique index, so
/// uniqueness is enforced at the application layer via a check-then-act
/// read immediately before every toggle (see `LikeRepository.toggle`) - a
/// reasonable, not airtight, guard, per `plan/build-plan.md` "Known
/// limitations".
class Like {
  const Like({required this.id, required this.postId, required this.userId});

  factory Like.fromJson(Map<String, dynamic> json) {
    return Like(
      id: json['_id'] as String? ?? '',
      postId: json['postId'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
    );
  }

  final String id;
  final String postId;
  final String userId;
}
