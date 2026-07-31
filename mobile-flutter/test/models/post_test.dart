import 'package:mudbase_showcase_social/models/post.dart';
import 'package:test/test.dart';

void main() {
  Map<String, dynamic> baseJson() => {
    '_id': 'post_1',
    'authorId': 'user_1',
    'authorName': 'Ava Poster',
    'content': 'Hello world',
    'imageUrl': 'https://example.com/image.png',
    'likesCount': 3,
    'commentsCount': 1,
    'createdAt': '2026-07-31T21:54:22.031Z',
    'updatedAt': '2026-07-31T21:54:22.031Z',
  };

  group('Post.fromJson', () {
    test('parses every field from a well-formed document', () {
      final post = Post.fromJson(baseJson());

      expect(post.id, 'post_1');
      expect(post.authorId, 'user_1');
      expect(post.authorName, 'Ava Poster');
      expect(post.content, 'Hello world');
      expect(post.imageUrl, 'https://example.com/image.png');
      expect(post.likesCount, 3);
      expect(post.commentsCount, 1);
      expect(post.createdAt, DateTime.parse('2026-07-31T21:54:22.031Z'));
    });

    test('treats a missing imageUrl as null (text-only post)', () {
      final json = baseJson()..remove('imageUrl');
      final post = Post.fromJson(json);
      expect(post.imageUrl, isNull);
    });

    test('defaults likesCount/commentsCount to 0 when absent', () {
      final json = baseJson()
        ..remove('likesCount')
        ..remove('commentsCount');
      final post = Post.fromJson(json);
      expect(post.likesCount, 0);
      expect(post.commentsCount, 0);
    });

    test(
      'falls back to "now" for an unparseable createdAt rather than throwing',
      () {
        final json = baseJson()..['createdAt'] = 'not-a-date';
        final before = DateTime.now();
        final post = Post.fromJson(json);
        expect(
          post.createdAt.isAfter(before.subtract(const Duration(seconds: 5))),
          isTrue,
        );
      },
    );
  });

  group('Post.copyWith', () {
    test('overrides only the specified fields, immutably', () {
      final original = Post.fromJson(baseJson());
      final updated = original.copyWith(likesCount: 10);

      expect(updated.likesCount, 10);
      expect(updated.commentsCount, original.commentsCount);
      expect(updated.content, original.content);
      // The original instance must be untouched - this project's
      // immutability rule.
      expect(original.likesCount, 3);
    });
  });
}
