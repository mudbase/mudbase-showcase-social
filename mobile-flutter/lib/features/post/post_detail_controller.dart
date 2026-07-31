import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repository_providers.dart';
import '../../models/comment.dart';
import '../../models/post.dart';
import '../auth/auth_controller.dart';
import '../feed/feed_controller.dart';
import '../feed/liked_post_ids_controller.dart';

class PostDetailState {
  const PostDetailState({
    required this.post,
    required this.comments,
    required this.isLikedByMe,
  });

  final Post post;
  final List<Comment> comments;
  final bool isLikedByMe;

  PostDetailState copyWith({
    Post? post,
    List<Comment>? comments,
    bool? isLikedByMe,
  }) {
    return PostDetailState(
      post: post ?? this.post,
      comments: comments ?? this.comments,
      isLikedByMe: isLikedByMe ?? this.isLikedByMe,
    );
  }
}

/// A single post's full detail: the post itself, its comment thread
/// (oldest-first), and whether the signed-in user has liked it. Owns like
/// toggling and comment creation, and best-effort propagates the resulting
/// post (new `likesCount`/`commentsCount`) back to [FeedController] so a
/// post already visible in the feed list reflects the change too - mirrors
/// the web app's `updatePostEverywhere` touching both the feed cache and
/// the standalone post-detail document cache.
class PostDetailController
    extends FamilyAsyncNotifier<PostDetailState, String> {
  @override
  Future<PostDetailState> build(String postId) async {
    final authNotifier = ref.read(authControllerProvider.notifier);
    final postRepo = ref.watch(postRepositoryProvider);
    final commentRepo = ref.watch(commentRepositoryProvider);
    final likeRepo = ref.watch(likeRepositoryProvider);
    final currentUser = ref.watch(authControllerProvider).valueOrNull;

    final post = await authNotifier.callAuthorized(
      (token) => postRepo.getById(token: token, id: postId),
    );
    if (post == null) {
      throw StateError('This post no longer exists.');
    }

    final comments = await authNotifier.callAuthorized(
      (token) => commentRepo.listForPost(token: token, postId: postId),
    );

    var isLikedByMe = false;
    if (currentUser != null) {
      final likedIds = await authNotifier.callAuthorized(
        (token) =>
            likeRepo.myLikedPostIds(token: token, userId: currentUser.id),
      );
      isLikedByMe = likedIds.contains(postId);
    }

    return PostDetailState(
      post: post,
      comments: comments,
      isLikedByMe: isLikedByMe,
    );
  }

  Future<void> toggleLike() async {
    final current = state.valueOrNull;
    if (current == null) return;
    final user = ref.read(authControllerProvider).valueOrNull;
    if (user == null) {
      throw StateError('Must be signed in to like a post');
    }

    final authNotifier = ref.read(authControllerProvider.notifier);
    final likeRepo = ref.read(likeRepositoryProvider);
    final postRepo = ref.read(postRepositoryProvider);

    final toggled = await authNotifier.callAuthorized(
      (token) => likeRepo.toggle(
        token: token,
        postId: current.post.id,
        userId: user.id,
        currentLikesCount: current.post.likesCount,
      ),
    );
    final updatedPost = await authNotifier.callAuthorized(
      (token) => postRepo.updateCounts(
        token: token,
        postId: current.post.id,
        likesCount: toggled.likesCount,
      ),
    );

    state = AsyncData(
      current.copyWith(post: updatedPost, isLikedByMe: toggled.liked),
    );
    _propagateToFeed(updatedPost);
    ref
        .read(likedPostIdsControllerProvider.notifier)
        .markLiked(current.post.id, liked: toggled.liked);
  }

  Future<void> addComment(String content) async {
    final current = state.valueOrNull;
    if (current == null) return;
    final user = ref.read(authControllerProvider).valueOrNull;
    if (user == null) {
      throw StateError('Must be signed in to comment');
    }

    final authNotifier = ref.read(authControllerProvider.notifier);
    final commentRepo = ref.read(commentRepositoryProvider);
    final postRepo = ref.read(postRepositoryProvider);

    final created = await authNotifier.callAuthorized(
      (token) => commentRepo.create(
        token: token,
        postId: current.post.id,
        authorId: user.id,
        authorName: user.fullName,
        content: content,
      ),
    );

    // Re-read the post immediately before incrementing so a burst of
    // concurrent comments doesn't have both writers increment from the same
    // stale count - same check-then-act guard style as the like toggle.
    final freshPost = await authNotifier.callAuthorized(
      (token) => postRepo.getById(token: token, id: current.post.id),
    );
    final commentsCount =
        (freshPost?.commentsCount ?? current.post.commentsCount) + 1;
    final updatedPost = await authNotifier.callAuthorized(
      (token) => postRepo.updateCounts(
        token: token,
        postId: current.post.id,
        commentsCount: commentsCount,
      ),
    );

    state = AsyncData(
      current.copyWith(
        post: updatedPost,
        comments: [...current.comments, created],
      ),
    );
    _propagateToFeed(updatedPost);
  }

  void _propagateToFeed(Post updatedPost) {
    ref.read(feedControllerProvider.notifier).updatePostEverywhere(updatedPost);
  }
}

final postDetailControllerProvider =
    AsyncNotifierProvider.family<PostDetailController, PostDetailState, String>(
      PostDetailController.new,
    );
