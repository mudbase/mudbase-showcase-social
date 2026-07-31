import '../../config/env_config.dart';
import '../../core/mudbase_data_service.dart';
import '../../models/post.dart';

class PostRepository {
  const PostRepository(this._dataService);

  final MudbaseDataService _dataService;

  static const int pageSize = 10;

  /// The feed's paginated read - confirmed live against the real project
  /// (see `plan/build-plan.md`): `sort=-createdAt` (newest first),
  /// server-side `page`/`limit`. Returns the server's own `hasMore` flag
  /// rather than guessing from page length.
  Future<({List<Post> posts, bool hasMore})> listFeedPage({
    required String token,
    required int page,
  }) async {
    final result = await _dataService.listPage(
      EnvConfig.postsCollectionId,
      token: token,
      sort: '-createdAt',
      page: page,
      limit: pageSize,
    );
    return (
      posts: result.items.map(Post.fromJson).toList(),
      hasMore: result.hasMore,
    );
  }

  Future<Post?> getById({required String token, required String id}) async {
    final doc = await _dataService.getById(
      EnvConfig.postsCollectionId,
      id,
      token: token,
    );
    return doc == null ? null : Post.fromJson(doc);
  }

  /// A user's own posts, newest first - used by the profile screen for both
  /// the post list and (via its length/`pagination.total`) the post count.
  Future<List<Post>> listByAuthor({
    required String token,
    required String authorId,
  }) async {
    final docs = await _dataService.list(
      EnvConfig.postsCollectionId,
      token: token,
      filter: {'authorId': authorId},
      sort: '-createdAt',
      limit: 100,
    );
    return docs.map(Post.fromJson).toList();
  }

  Future<Post> create({
    required String token,
    required String authorId,
    required String authorName,
    required String content,
    String? imageUrl,
  }) async {
    final doc = await _dataService.create(EnvConfig.postsCollectionId, {
      'authorId': authorId,
      'authorName': authorName,
      'content': content,
      if (imageUrl != null && imageUrl.isNotEmpty) 'imageUrl': imageUrl,
      'likesCount': 0,
      'commentsCount': 0,
    }, token: token);
    return Post.fromJson(doc);
  }

  Future<Post> updateCounts({
    required String token,
    required String postId,
    int? likesCount,
    int? commentsCount,
  }) async {
    final doc = await _dataService.update(EnvConfig.postsCollectionId, postId, {
      if (likesCount != null) 'likesCount': likesCount,
      if (commentsCount != null) 'commentsCount': commentsCount,
    }, token: token);
    return Post.fromJson(doc);
  }
}
