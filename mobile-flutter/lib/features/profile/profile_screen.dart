import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/repository_providers.dart';
import '../../widgets/async_value_view.dart';
import '../../widgets/empty_state.dart';
import '../auth/auth_controller.dart';
import '../feed/feed_controller.dart';
import '../feed/liked_post_ids_controller.dart';
import '../feed/widgets/post_card.dart';
import 'profile_controller.dart';
import 'widgets/profile_header.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({required this.userId, super.key});

  final String userId;

  /// Wraps `AuthController.logout()` with error feedback instead of leaving
  /// it as a bare fire-and-forget call from a button's `onPressed` - a
  /// failed secure-storage clear (rare, but possible) must surface to the
  /// user rather than fail silently.
  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(authControllerProvider.notifier).logout();
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _toggleLike(WidgetRef ref, String postId, int likesCount) async {
    final user = ref.read(authControllerProvider).valueOrNull;
    if (user == null) throw StateError('Must be signed in to like a post');
    final authNotifier = ref.read(authControllerProvider.notifier);
    final likeRepo = ref.read(likeRepositoryProvider);
    final postRepo = ref.read(postRepositoryProvider);

    final toggled = await authNotifier.callAuthorized(
      (token) => likeRepo.toggle(
        token: token,
        postId: postId,
        userId: user.id,
        currentLikesCount: likesCount,
      ),
    );
    final updatedPost = await authNotifier.callAuthorized(
      (token) => postRepo.updateCounts(
        token: token,
        postId: postId,
        likesCount: toggled.likesCount,
      ),
    );
    ref.read(feedControllerProvider.notifier).updatePostEverywhere(updatedPost);
    ref
        .read(likedPostIdsControllerProvider.notifier)
        .markLiked(postId, liked: toggled.liked);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = profileControllerProvider(userId);
    final state = ref.watch(provider);
    final likedIds =
        ref.watch(likedPostIdsControllerProvider).valueOrNull ??
        const <String>{};

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: AsyncValueView<ProfileState>(
        value: state,
        onRetry: () => ref.invalidate(provider),
        data: (context, profile) {
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(provider);
              // Keeps the pull-to-refresh spinner visible until the
              // reloaded data actually arrives, not just until invalidation
              // is requested.
              await ref.read(provider.future);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                ProfileHeader(
                  state: profile,
                  onToggleFollow: () =>
                      ref.read(provider.notifier).toggleFollow(),
                  onSignOut: profile.isOwnProfile
                      ? () => _signOut(context, ref)
                      : null,
                ),
                const Divider(height: 1),
                if (profile.posts.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: EmptyState(
                      icon: Icons.grid_view_outlined,
                      message: 'No posts yet.',
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Column(
                      children: [
                        for (final post in profile.posts) ...[
                          PostCard(
                            post: post,
                            isLikedByMe: likedIds.contains(post.id),
                            onToggleLike: () =>
                                _toggleLike(ref, post.id, post.likesCount),
                            onTapPost: () =>
                                context.push('/feed/post/${post.id}'),
                            onTapAuthor: () {},
                          ),
                          const SizedBox(height: 12),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
