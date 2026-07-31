import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repository_providers.dart';
import '../auth/auth_controller.dart';

/// The signed-in user's own liked-post ids, fetched once and shared by every
/// `LikeButton` in the feed and the post-detail screen - avoids one query
/// per rendered post. Mirrors the web app's `useMyLikedPostIds`, but as an
/// `AsyncNotifier` (rather than a plain query) so a toggle anywhere in the
/// app can update this cache locally via [markLiked] instead of forcing a
/// full re-fetch.
class LikedPostIdsController extends AsyncNotifier<Set<String>> {
  @override
  Future<Set<String>> build() async {
    final user = ref.watch(authControllerProvider).valueOrNull;
    if (user == null) return const {};
    final authNotifier = ref.read(authControllerProvider.notifier);
    final likeRepo = ref.watch(likeRepositoryProvider);
    return authNotifier.callAuthorized(
      (token) => likeRepo.myLikedPostIds(token: token, userId: user.id),
    );
  }

  void markLiked(String postId, {required bool liked}) {
    final current = state.valueOrNull;
    if (current == null) return;
    final next = Set<String>.from(current);
    if (liked) {
      next.add(postId);
    } else {
      next.remove(postId);
    }
    state = AsyncData(next);
  }
}

final likedPostIdsControllerProvider =
    AsyncNotifierProvider<LikedPostIdsController, Set<String>>(
      LikedPostIdsController.new,
    );
