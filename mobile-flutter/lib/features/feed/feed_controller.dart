import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/env_config.dart';
import '../../core/mudbase_socket_service.dart';
import '../../core/service_providers.dart';
import '../../data/repository_providers.dart';
import '../../models/post.dart';
import '../auth/auth_controller.dart';

class FeedState {
  const FeedState({
    required this.posts,
    required this.page,
    required this.hasMore,
    required this.isLoadingMore,
  });

  final List<Post> posts;
  final int page;
  final bool hasMore;
  final bool isLoadingMore;

  FeedState copyWith({
    List<Post>? posts,
    int? page,
    bool? hasMore,
    bool? isLoadingMore,
  }) {
    return FeedState(
      posts: posts ?? this.posts,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

/// Owns the feed: initial + paginated loads, and the realtime subscription
/// that keeps it live. Subscribes to the `posts` collection's Socket.IO room
/// on `build()` and tears the subscription down when this provider is
/// disposed (screen leaves the tree) - same `subscribe:collection` ->
/// `db:create`/`db:update` contract as the web app's `usePostsLive`, ported
/// to Dart and confirmed live in this build's own smoke test (see
/// `plan/build-plan.md` finding #6).
class FeedController extends AsyncNotifier<FeedState> {
  void Function()? _unsubscribeCreate;
  void Function()? _unsubscribeUpdate;
  void Function()? _unsubscribeStatus;

  @override
  Future<FeedState> build() async {
    ref.onDispose(_teardownRealtime);

    final authNotifier = ref.read(authControllerProvider.notifier);
    final repository = ref.watch(postRepositoryProvider);
    final firstPage = await authNotifier.callAuthorized(
      (token) => repository.listFeedPage(token: token, page: 1),
    );

    _setupRealtime();

    return FeedState(
      posts: firstPage.posts,
      page: 1,
      hasMore: firstPage.hasMore,
      isLoadingMore: false,
    );
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || current.isLoadingMore) return;

    state = AsyncData(current.copyWith(isLoadingMore: true));
    try {
      final authNotifier = ref.read(authControllerProvider.notifier);
      final repository = ref.read(postRepositoryProvider);
      final nextPage = current.page + 1;
      final result = await authNotifier.callAuthorized(
        (token) => repository.listFeedPage(token: token, page: nextPage),
      );
      final existingIds = current.posts.map((post) => post.id).toSet();
      final deduped = result.posts.where(
        (post) => !existingIds.contains(post.id),
      );
      state = AsyncData(
        current.copyWith(
          posts: [...current.posts, ...deduped],
          page: nextPage,
          hasMore: result.hasMore,
          isLoadingMore: false,
        ),
      );
    } catch (_) {
      // Load-more failures are non-fatal - the feed already showing content
      // stays visible; just stop the spinner and let the user retry by
      // scrolling again or pulling to refresh.
      final stillCurrent = state.valueOrNull;
      if (stillCurrent != null) {
        state = AsyncData(stillCurrent.copyWith(isLoadingMore: false));
      }
    }
  }

  /// Pull-to-refresh: re-fetches page 1 and replaces the whole list, same
  /// as a fresh `build()` but without tearing down the realtime
  /// subscription (`refresh()` doesn't call `ref.invalidateSelf()` for
  /// exactly that reason).
  Future<void> refresh() async {
    final authNotifier = ref.read(authControllerProvider.notifier);
    final repository = ref.read(postRepositoryProvider);
    final firstPage = await authNotifier.callAuthorized(
      (token) => repository.listFeedPage(token: token, page: 1),
    );
    state = AsyncData(
      FeedState(
        posts: firstPage.posts,
        page: 1,
        hasMore: firstPage.hasMore,
        isLoadingMore: false,
      ),
    );
  }

  /// Inserts a brand-new post at the top of the feed, deduped by `id` so the
  /// composer's own optimistic insert and the realtime `db:create` echo for
  /// the same post never double up - mirrors the web app's `prependPost`.
  void prependPost(Post post) {
    final current = state.valueOrNull;
    if (current == null) return;
    if (current.posts.any((existing) => existing.id == post.id)) return;
    state = AsyncData(current.copyWith(posts: [post, ...current.posts]));
  }

  /// Patches whichever cached copy of a post exists in the feed - what
  /// makes another user's like/comment appear live on a post already
  /// visible in the feed. Mirrors the web app's `updatePostEverywhere`
  /// (the feed-list half of it; `PostDetailController` handles the
  /// standalone-document half for the post-detail screen).
  void updatePostEverywhere(Post updated) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        posts: [
          for (final post in current.posts)
            if (post.id == updated.id) updated else post,
        ],
      ),
    );
  }

  void _setupRealtime() {
    final socket = ref.read(mudbaseSocketServiceProvider);
    const collectionId = EnvConfig.postsCollectionId;

    void trySubscribe() {
      if (!socket.connected) return;
      socket.emit('subscribe:collection', {
        'projectId': EnvConfig.mudbaseProjectId,
        'collectionId': collectionId,
      });
    }

    trySubscribe();
    _unsubscribeStatus = socket.onStatus((status) {
      if (status == SocketConnectionStatus.connected) trySubscribe();
    });

    _unsubscribeCreate = socket.on('db:create', (event) {
      if (event['collectionId'] != collectionId) return;
      final data = event['data'];
      if (data is! Map) return;
      prependPost(Post.fromJson(Map<String, dynamic>.from(data)));
    });

    _unsubscribeUpdate = socket.on('db:update', (event) {
      if (event['collectionId'] != collectionId) return;
      final data = event['data'];
      if (data is! Map) return;
      updatePostEverywhere(Post.fromJson(Map<String, dynamic>.from(data)));
    });
  }

  void _teardownRealtime() {
    final socket = ref.read(mudbaseSocketServiceProvider);
    socket.emit('unsubscribe:collection', {
      'collectionId': EnvConfig.postsCollectionId,
    });
    _unsubscribeCreate?.call();
    _unsubscribeUpdate?.call();
    _unsubscribeStatus?.call();
  }
}

final feedControllerProvider = AsyncNotifierProvider<FeedController, FeedState>(
  FeedController.new,
);
