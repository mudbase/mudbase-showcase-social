/// Mirrors the web app's `Follow` (`web/src/types/follow.ts`) and the live
/// `follows` collection schema - `followerId`, `followingId`,
/// `followingName?`. `followingName` is denormalized at write time (there
/// is no `users` collection - see `plan/build-plan.md` "Known limitations")
/// so a profile screen can resolve a display name for a user who has never
/// posted. Same check-then-act uniqueness guard as [Like] - see
/// `FollowRepository.toggle`.
class Follow {
  const Follow({
    required this.id,
    required this.followerId,
    required this.followingId,
    required this.followingName,
  });

  factory Follow.fromJson(Map<String, dynamic> json) {
    return Follow(
      id: json['_id'] as String? ?? '',
      followerId: json['followerId'] as String? ?? '',
      followingId: json['followingId'] as String? ?? '',
      followingName: json['followingName'] as String?,
    );
  }

  final String id;
  final String followerId;
  final String followingId;
  final String? followingName;
}
