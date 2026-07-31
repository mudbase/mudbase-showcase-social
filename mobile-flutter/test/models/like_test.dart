import 'package:mudbase_showcase_social/models/like.dart';
import 'package:test/test.dart';

void main() {
  group('Like.fromJson', () {
    test('parses postId and userId', () {
      final like = Like.fromJson({
        '_id': 'like_1',
        'postId': 'post_1',
        'userId': 'user_2',
      });

      expect(like.id, 'like_1');
      expect(like.postId, 'post_1');
      expect(like.userId, 'user_2');
    });

    test('defaults every missing field to empty rather than throwing', () {
      final like = Like.fromJson(const {});
      expect(like.id, '');
      expect(like.postId, '');
      expect(like.userId, '');
    });
  });
}
