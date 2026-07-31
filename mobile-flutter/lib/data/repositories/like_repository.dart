import '../../config/env_config.dart';
import '../../core/mudbase_data_service.dart';
import '../../models/like.dart';

/// The result of toggling a like - the new state plus the post's updated
/// `likesCount`, so the caller can patch its cached copy of the post
/// immutably (see `FeedController`/`PostDetailController`).
class LikeToggleResult {
  const LikeToggleResult({required this.liked, required this.likesCount});

  final bool liked;
  final int likesCount;
}

class LikeRepository {
  const LikeRepository(this._dataService);

  final MudbaseDataService _dataService;

  Future<Set<String>> myLikedPostIds({
    required String token,
    required String userId,
  }) async {
    final docs = await _dataService.list(
      EnvConfig.likesCollectionId,
      token: token,
      filter: {'userId': userId},
      limit: 500,
    );
    return docs.map(Like.fromJson).map((like) => like.postId).toSet();
  }

  /// Check-then-act against the server (not just the local cache) right
  /// before mutating - reasonable protection against a double-tap race
  /// creating two like rows for the same (postId, userId), since this
  /// collection type has no compound unique index. Mirrors the web app's
  /// `useToggleLike` exactly, including the `Math.max(0, ...)` floor on
  /// decrement.
  Future<LikeToggleResult> toggle({
    required String token,
    required String postId,
    required String userId,
    required int currentLikesCount,
  }) async {
    final existing = await _dataService.list(
      EnvConfig.likesCollectionId,
      token: token,
      filter: {'postId': postId, 'userId': userId},
      limit: 1,
    );

    if (existing.isNotEmpty) {
      final likeId = existing.first['_id'] as String?;
      if (likeId != null) {
        await _dataService.delete(
          EnvConfig.likesCollectionId,
          likeId,
          token: token,
        );
      }
      final likesCount = currentLikesCount > 0 ? currentLikesCount - 1 : 0;
      return LikeToggleResult(liked: false, likesCount: likesCount);
    }

    await _dataService.create(EnvConfig.likesCollectionId, {
      'postId': postId,
      'userId': userId,
    }, token: token);
    return LikeToggleResult(liked: true, likesCount: currentLikesCount + 1);
  }
}
