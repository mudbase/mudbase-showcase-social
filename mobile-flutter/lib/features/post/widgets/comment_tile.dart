import 'package:flutter/material.dart';

import '../../../core/formatters.dart';
import '../../../models/comment.dart';

class CommentTile extends StatelessWidget {
  const CommentTile({
    required this.comment,
    required this.onTapAuthor,
    super.key,
  });

  final Comment comment;
  final VoidCallback onTapAuthor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onTapAuthor,
            borderRadius: BorderRadius.circular(16),
            child: CircleAvatar(
              radius: 14,
              backgroundColor: colorScheme.secondaryContainer,
              child: Text(
                _initials(comment.authorName),
                style: TextStyle(
                  color: colorScheme.onSecondaryContainer,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    InkWell(
                      onTap: onTapAuthor,
                      child: Text(
                        comment.authorName,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      formatRelativeTime(comment.createdAt),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  comment.content,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    final parts = trimmed.split(RegExp(r'\s+'));
    final first = parts.first.isNotEmpty ? parts.first[0] : '';
    final last = parts.length > 1 && parts.last.isNotEmpty ? parts.last[0] : '';
    final initials = '$first$last'.toUpperCase();
    return initials.isEmpty ? '?' : initials;
  }
}
