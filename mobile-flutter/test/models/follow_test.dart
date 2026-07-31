import 'package:mudbase_showcase_social/models/follow.dart';
import 'package:test/test.dart';

void main() {
  group('Follow.fromJson', () {
    test(
      'parses followerId, followingId, and the denormalized followingName',
      () {
        final follow = Follow.fromJson({
          '_id': 'follow_1',
          'followerId': 'user_2',
          'followingId': 'user_1',
          'followingName': 'Ava Poster',
        });

        expect(follow.id, 'follow_1');
        expect(follow.followerId, 'user_2');
        expect(follow.followingId, 'user_1');
        expect(follow.followingName, 'Ava Poster');
      },
    );

    test(
      'treats a missing followingName as null - the "never posted, no name known yet" case',
      () {
        final follow = Follow.fromJson({
          '_id': 'follow_1',
          'followerId': 'user_2',
          'followingId': 'user_1',
        });
        expect(follow.followingName, isNull);
      },
    );
  });
}
