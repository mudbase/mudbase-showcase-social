import 'package:mudbase_showcase_social/models/comment.dart';
import 'package:test/test.dart';

void main() {
  group('Comment.fromJson', () {
    test('parses every field from a well-formed document', () {
      final comment = Comment.fromJson({
        '_id': 'comment_1',
        'postId': 'post_1',
        'authorId': 'user_2',
        'authorName': 'Ben Follower',
        'content': 'Nice post!',
        'createdAt': '2026-07-31T21:54:36.869Z',
      });

      expect(comment.id, 'comment_1');
      expect(comment.postId, 'post_1');
      expect(comment.authorId, 'user_2');
      expect(comment.authorName, 'Ben Follower');
      expect(comment.content, 'Nice post!');
      expect(comment.createdAt, DateTime.parse('2026-07-31T21:54:36.869Z'));
    });

    test(
      'defaults every missing string field to empty rather than throwing',
      () {
        final comment = Comment.fromJson(const {});
        expect(comment.id, '');
        expect(comment.postId, '');
        expect(comment.authorId, '');
        expect(comment.authorName, '');
        expect(comment.content, '');
      },
    );
  });
}
