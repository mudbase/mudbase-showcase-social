import '../../config/env_config.dart';
import '../../core/mudbase_data_service.dart';
import '../../models/follow.dart';

class FollowToggleResult {
  const FollowToggleResult({required this.following});

  final bool following;
}

class FollowCounts {
  const FollowCounts({
    required this.followerCount,
    required this.followingCount,
  });

  final int followerCount;
  final int followingCount;
}

class FollowRepository {
  const FollowRepository(this._dataService);

  final MudbaseDataService _dataService;

  Future<Set<String>> myFollowingIds({
    required String token,
    required String userId,
  }) async {
    final docs = await _dataService.list(
      EnvConfig.followsCollectionId,
      token: token,
      filter: {'followerId': userId},
      limit: 500,
    );
    return docs
        .map(Follow.fromJson)
        .map((follow) => follow.followingId)
        .toSet();
  }

  /// Counts are read via `pagination.total` on a `limit: 1` query rather
  /// than pulling every row - cheap, and correct regardless of how many
  /// follow rows exist. Mirrors the web app's `useFollowCounts`.
  Future<FollowCounts> counts({
    required String token,
    required String userId,
  }) async {
    final followerCount = await _dataService.count(
      EnvConfig.followsCollectionId,
      token: token,
      filter: {'followingId': userId},
    );
    final followingCount = await _dataService.count(
      EnvConfig.followsCollectionId,
      token: token,
      filter: {'followerId': userId},
    );
    return FollowCounts(
      followerCount: followerCount,
      followingCount: followingCount,
    );
  }

  /// Best-effort fallback used by `ProfileController`'s display-name
  /// resolution: the `followingName` denormalized by anyone who follows
  /// [userId], if that user has never posted (see `plan/build-plan.md`
  /// "Known limitations" - there is no `users` collection). Mirrors the web
  /// app's
  /// `useResolvedDisplayName` exactly, including the `$exists`/`$ne` filter
  /// so an empty-string `followingName` from an older row doesn't win.
  Future<String?> resolveFollowingName({
    required String token,
    required String userId,
  }) async {
    final docs = await _dataService.list(
      EnvConfig.followsCollectionId,
      token: token,
      filter: {
        'followingId': userId,
        'followingName': {r'$exists': true, r'$ne': ''},
      },
      limit: 1,
    );
    if (docs.isEmpty) return null;
    return Follow.fromJson(docs.first).followingName;
  }

  /// Same check-then-act uniqueness guard as [LikeRepository.toggle] - a
  /// real duplicate follow row from an earlier concurrent session was
  /// observed live during this build's own verification (see
  /// `plan/build-plan.md` finding #7), confirming this is a real, not
  /// theoretical, constraint of the shared collection type.
  Future<FollowToggleResult> toggle({
    required String token,
    required String followerId,
    required String followingId,
    required String followingName,
  }) async {
    if (followerId == followingId) {
      throw ArgumentError('Cannot follow yourself');
    }

    final existing = await _dataService.list(
      EnvConfig.followsCollectionId,
      token: token,
      filter: {'followerId': followerId, 'followingId': followingId},
      limit: 1,
    );

    if (existing.isNotEmpty) {
      final followId = existing.first['_id'] as String?;
      if (followId != null) {
        await _dataService.delete(
          EnvConfig.followsCollectionId,
          followId,
          token: token,
        );
      }
      return const FollowToggleResult(following: false);
    }

    await _dataService.create(EnvConfig.followsCollectionId, {
      'followerId': followerId,
      'followingId': followingId,
      'followingName': followingName,
    }, token: token);
    return const FollowToggleResult(following: true);
  }
}
