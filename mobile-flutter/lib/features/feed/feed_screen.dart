import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/repository_providers.dart';
import '../../widgets/async_value_view.dart';
import '../../widgets/empty_state.dart';
import '../auth/auth_controller.dart';
import 'feed_controller.dart';
import 'liked_post_ids_controller.dart';
import 'widgets/post_card.dart';
import 'widgets/post_composer_sheet.dart';

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final threshold = _scrollController.position.maxScrollExtent - 200;
    if (_scrollController.position.pixels >= threshold) {
      // Fire-and-forget from a sync scroll listener - FeedController.loadMore
      // already catches its own failures internally (see its try/catch),
      // this just can't be awaited from here.
      unawaited(ref.read(feedControllerProvider.notifier).loadMore());
    }
  }

  Future<void> _toggleLike(String postId, int likesCount) async {
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
  Widget build(BuildContext context) {
    final feedState = ref.watch(feedControllerProvider);
    final likedIds =
        ref.watch(likedPostIdsControllerProvider).valueOrNull ??
        const <String>{};

    return Scaffold(
      appBar: AppBar(title: const Text('Feed')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showPostComposerSheet(context),
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(feedControllerProvider.notifier).refresh(),
        child: AsyncValueView<FeedState>(
          value: feedState,
          onRetry: () => ref.invalidate(feedControllerProvider),
          data: (context, state) {
            if (state.posts.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 120),
                  EmptyState(
                    icon: Icons.forum_outlined,
                    message: 'No posts yet. Be the first to share something!',
                  ),
                ],
              );
            }
            return ListView.separated(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: state.posts.length + (state.hasMore ? 1 : 0),
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                if (index >= state.posts.length) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  );
                }
                final post = state.posts[index];
                return PostCard(
                  post: post,
                  isLikedByMe: likedIds.contains(post.id),
                  onToggleLike: () => _toggleLike(post.id, post.likesCount),
                  onTapPost: () => context.push('/feed/post/${post.id}'),
                  onTapAuthor: () => context.push('/profile/${post.authorId}'),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
