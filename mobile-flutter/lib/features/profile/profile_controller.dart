import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/follow_repository.dart';
import '../../data/repositories/post_repository.dart';
import '../../data/repository_providers.dart';
import '../../models/post.dart';
import '../auth/auth_controller.dart';

class ProfileState {
  const ProfileState({
    required this.userId,
    required this.displayName,
    required this.posts,
    required this.followerCount,
    required this.followingCount,
    required this.isFollowing,
    required this.isOwnProfile,
  });

  final String userId;
  final String displayName;
  final List<Post> posts;
  final int followerCount;
  final int followingCount;
  final bool isFollowing;
  final bool isOwnProfile;

  ProfileState copyWith({
    List<Post>? posts,
    int? followerCount,
    int? followingCount,
    bool? isFollowing,
  }) {
    return ProfileState(
      userId: userId,
      displayName: displayName,
      posts: posts ?? this.posts,
      followerCount: followerCount ?? this.followerCount,
      followingCount: followingCount ?? this.followingCount,
      isFollowing: isFollowing ?? this.isFollowing,
      isOwnProfile: isOwnProfile,
    );
  }
}

/// A user's profile: resolved display name (best-effort - see
/// `plan/build-plan.md` "Known limitations", there is no `users`
/// collection), their posts, follower/following counts, and whether the
/// signed-in user follows them. Owns follow/unfollow toggling. Mirrors the
/// web app's `useResolvedDisplayName` + `useFollowCounts` + `useToggleFollow`
/// combined into one controller per profile screen.
class ProfileController extends FamilyAsyncNotifier<ProfileState, String> {
  @override
  Future<ProfileState> build(String userId) async {
    final authNotifier = ref.read(authControllerProvider.notifier);
    final postRepo = ref.watch(postRepositoryProvider);
    final followRepo = ref.watch(followRepositoryProvider);
    final currentUser = ref.watch(authControllerProvider).valueOrNull;

    final posts = await authNotifier.callAuthorized(
      (token) => postRepo.listByAuthor(token: token, authorId: userId),
    );
    final displayName = await _resolveDisplayName(
      authNotifier: authNotifier,
      followRepo: followRepo,
      userId: userId,
      posts: posts,
    );
    final counts = await authNotifier.callAuthorized(
      (token) => followRepo.counts(token: token, userId: userId),
    );

    var isFollowing = false;
    if (currentUser != null && currentUser.id != userId) {
      final followingIds = await authNotifier.callAuthorized(
        (token) =>
            followRepo.myFollowingIds(token: token, userId: currentUser.id),
      );
      isFollowing = followingIds.contains(userId);
    }

    return ProfileState(
      userId: userId,
      displayName: displayName,
      posts: posts,
      followerCount: counts.followerCount,
      followingCount: counts.followingCount,
      isFollowing: isFollowing,
      isOwnProfile: currentUser?.id == userId,
    );
  }

  /// Most recent post's `authorName` (posts are already sorted
  /// newest-first), falling back to a `followingName` denormalized by
  /// someone who follows this user, falling back to "Member" - identical
  /// fallback chain to the web app's `useResolvedDisplayName`.
  Future<String> _resolveDisplayName({
    required AuthController authNotifier,
    required FollowRepository followRepo,
    required String userId,
    required List<Post> posts,
  }) async {
    final fromPost = posts.isNotEmpty ? posts.first.authorName : null;
    if (fromPost != null && fromPost.isNotEmpty) return fromPost;

    final fromFollow = await authNotifier.callAuthorized(
      (token) => followRepo.resolveFollowingName(token: token, userId: userId),
    );
    if (fromFollow != null && fromFollow.isNotEmpty) return fromFollow;

    return 'Member';
  }

  Future<void> toggleFollow() async {
    final current = state.valueOrNull;
    if (current == null) return;
    final me = ref.read(authControllerProvider).valueOrNull;
    if (me == null) {
      throw StateError('Must be signed in to follow a user');
    }
    if (me.id == current.userId) {
      throw StateError('Cannot follow yourself');
    }

    final authNotifier = ref.read(authControllerProvider.notifier);
    final followRepo = ref.read(followRepositoryProvider);

    final toggled = await authNotifier.callAuthorized(
      (token) => followRepo.toggle(
        token: token,
        followerId: me.id,
        followingId: current.userId,
        followingName: current.displayName,
      ),
    );
    final counts = await authNotifier.callAuthorized(
      (token) => followRepo.counts(token: token, userId: current.userId),
    );

    state = AsyncData(
      current.copyWith(
        isFollowing: toggled.following,
        followerCount: counts.followerCount,
      ),
    );
  }
}

final profileControllerProvider =
    AsyncNotifierProvider.family<ProfileController, ProfileState, String>(
      ProfileController.new,
    );
