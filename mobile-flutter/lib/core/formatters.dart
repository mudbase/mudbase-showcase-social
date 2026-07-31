/// Relative time formatting for post/comment timestamps ("2m ago", "3h ago",
/// "5d ago"), falling back to a plain date once it's more than a week old.
/// Deliberately dependency-free (no `intl` `DateFormat` needed for this one
/// case) - `intl` is still a dependency for anything that later needs full
/// locale-aware date formatting.
String formatRelativeTime(DateTime dateTime) {
  final now = DateTime.now();
  final difference = now.difference(dateTime);

  if (difference.isNegative || difference.inSeconds < 60) {
    return 'just now';
  }
  if (difference.inMinutes < 60) {
    return '${difference.inMinutes}m ago';
  }
  if (difference.inHours < 24) {
    return '${difference.inHours}h ago';
  }
  if (difference.inDays < 7) {
    return '${difference.inDays}d ago';
  }

  final month = dateTime.month.toString().padLeft(2, '0');
  final day = dateTime.day.toString().padLeft(2, '0');
  return '${dateTime.year}-$month-$day';
}
