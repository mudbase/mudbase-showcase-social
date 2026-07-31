import '../../config/env_config.dart';
import '../../core/mudbase_data_service.dart';
import '../../models/comment.dart';

class CommentRepository {
  const CommentRepository(this._dataService);

  final MudbaseDataService _dataService;

  /// Oldest first, like a normal comment thread - confirmed live (see
  /// `plan/build-plan.md`): `sort: "createdAt"` ascending.
  Future<List<Comment>> listForPost({
    required String token,
    required String postId,
  }) async {
    final docs = await _dataService.list(
      EnvConfig.commentsCollectionId,
      token: token,
      filter: {'postId': postId},
      sort: 'createdAt',
      limit: 200,
    );
    return docs.map(Comment.fromJson).toList();
  }

  Future<Comment> create({
    required String token,
    required String postId,
    required String authorId,
    required String authorName,
    required String content,
  }) async {
    final doc = await _dataService.create(EnvConfig.commentsCollectionId, {
      'postId': postId,
      'authorId': authorId,
      'authorName': authorName,
      'content': content,
    }, token: token);
    return Comment.fromJson(doc);
  }
}
