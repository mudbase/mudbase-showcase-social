import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/formatters.dart';
import '../../../models/post.dart';
import '../../../widgets/like_button.dart';

class PostCard extends StatelessWidget {
  const PostCard({
    required this.post,
    required this.isLikedByMe,
    required this.onToggleLike,
    required this.onTapPost,
    required this.onTapAuthor,
    super.key,
  });

  final Post post;
  final bool isLikedByMe;
  final Future<void> Function() onToggleLike;
  final VoidCallback onTapPost;
  final VoidCallback onTapAuthor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final imageUrl = post.imageUrl;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTapPost,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: onTapAuthor,
                borderRadius: BorderRadius.circular(20),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: colorScheme.primaryContainer,
                      child: Text(
                        _initials(post.authorName),
                        style: TextStyle(
                          color: colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            post.authorName,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            formatRelativeTime(post.createdAt),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(post.content, style: Theme.of(context).textTheme.bodyLarge),
              if (imageUrl != null && imageUrl.isNotEmpty) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: 200,
                    placeholder: (context, url) => Container(
                      height: 200,
                      color: colorScheme.surfaceContainerHighest,
                      alignment: Alignment.center,
                      child: const CircularProgressIndicator(strokeWidth: 2),
                    ),
                    errorWidget: (context, url, error) => Container(
                      height: 200,
                      color: colorScheme.surfaceContainerHighest,
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  LikeButton(
                    isLiked: isLikedByMe,
                    likesCount: post.likesCount,
                    onToggle: onToggleLike,
                  ),
                  const SizedBox(width: 4),
                  InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: onTapPost,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 20,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${post.commentsCount}',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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
