import 'package:mudbase_showcase_social/models/mudbase_user.dart';
import 'package:test/test.dart';

void main() {
  group('MudbaseUser.fromJson', () {
    test('parses every field, preferring "id" over "_id"', () {
      final user = MudbaseUser.fromJson({
        'id': 'user_1',
        '_id': 'should_not_be_used',
        'email': 'ava@example.com',
        'firstName': 'Ava',
        'lastName': 'Poster',
        'customRole': 'customer',
        'emailVerified': true,
      });

      expect(user.id, 'user_1');
      expect(user.email, 'ava@example.com');
      expect(user.customRole, 'customer');
      expect(user.emailVerified, isTrue);
    });

    test('falls back to "_id" when "id" is absent', () {
      final user = MudbaseUser.fromJson({
        '_id': 'user_1',
        'email': 'ava@example.com',
        'firstName': 'Ava',
        'lastName': 'Poster',
        'emailVerified': true,
      });
      expect(user.id, 'user_1');
    });
  });

  group('MudbaseUser.fullName', () {
    test('joins first and last name', () {
      const user = MudbaseUser(
        id: 'u1',
        email: 'ava@example.com',
        firstName: 'Ava',
        lastName: 'Poster',
        customRole: 'customer',
        emailVerified: true,
      );
      expect(user.fullName, 'Ava Poster');
    });

    test('falls back to email when both names are blank', () {
      const user = MudbaseUser(
        id: 'u1',
        email: 'ava@example.com',
        firstName: '',
        lastName: '',
        customRole: 'customer',
        emailVerified: true,
      );
      expect(user.fullName, 'ava@example.com');
    });
  });
}
