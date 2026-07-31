import 'package:mudbase_showcase_social/core/formatters.dart';
import 'package:test/test.dart';

void main() {
  group('formatRelativeTime', () {
    test('reports a timestamp seconds ago as "just now"', () {
      final now = DateTime.now();
      expect(
        formatRelativeTime(now.subtract(const Duration(seconds: 10))),
        'just now',
      );
    });

    test('reports minutes ago', () {
      final now = DateTime.now();
      expect(
        formatRelativeTime(now.subtract(const Duration(minutes: 5))),
        '5m ago',
      );
    });

    test('reports hours ago', () {
      final now = DateTime.now();
      expect(
        formatRelativeTime(now.subtract(const Duration(hours: 3))),
        '3h ago',
      );
    });

    test('reports days ago for anything under a week', () {
      final now = DateTime.now();
      expect(
        formatRelativeTime(now.subtract(const Duration(days: 4))),
        '4d ago',
      );
    });

    test('falls back to a plain date once older than a week', () {
      final now = DateTime.now();
      final eightDaysAgo = now.subtract(const Duration(days: 8));
      final formatted = formatRelativeTime(eightDaysAgo);
      expect(formatted, matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
    });

    test(
      'treats a timestamp slightly in the future as "just now" rather than throwing',
      () {
        final now = DateTime.now();
        expect(
          formatRelativeTime(now.add(const Duration(seconds: 2))),
          'just now',
        );
      },
    );
  });
}
