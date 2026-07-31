import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/formatters.dart';
import '../../widgets/async_value_view.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/like_button.dart';
import 'post_detail_controller.dart';
import 'widgets/comment_composer.dart';
import 'widgets/comment_tile.dart';

class PostDetailScreen extends ConsumerWidget {
  const PostDetailScreen({required this.postId, super.key});

  final String postId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = postDetailControllerProvider(postId);
    final state = ref.watch(provider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Post')),
      body: AsyncValueView<PostDetailState>(
        value: state,
        onRetry: () => ref.invalidate(provider),
        data: (context, detail) {
          final post = detail.post;
          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    InkWell(
                      onTap: () => context.push('/profile/${post.authorId}'),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: colorScheme.primaryContainer,
                            child: Text(
                              post.authorName.isNotEmpty
                                  ? post.authorName[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                color: colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
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
                                    ?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      post.content,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    if (post.imageUrl != null && post.imageUrl!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          imageUrl: post.imageUrl!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: 240,
                          errorWidget: (context, url, error) => Container(
                            height: 240,
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
                    LikeButton(
                      isLiked: detail.isLikedByMe,
                      likesCount: post.likesCount,
                      onToggle: () => ref.read(provider.notifier).toggleLike(),
                    ),
                    const Divider(height: 32),
                    Text(
                      'Comments',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (detail.comments.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: EmptyState(
                          icon: Icons.chat_bubble_outline,
                          message: 'No comments yet. Start the conversation.',
                        ),
                      )
                    else
                      for (final comment in detail.comments)
                        CommentTile(
                          comment: comment,
                          onTapAuthor: () =>
                              context.push('/profile/${comment.authorId}'),
                        ),
                  ],
                ),
              ),
              const Divider(height: 1),
              CommentComposer(
                onSubmit: (content) =>
                    ref.read(provider.notifier).addComment(content),
              ),
            ],
          );
        },
      ),
    );
  }
}
