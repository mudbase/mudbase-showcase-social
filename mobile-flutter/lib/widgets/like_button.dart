import 'package:flutter/material.dart';

/// Shared like-toggle control used by both the feed's `PostCard` and the
/// post-detail screen - a single tappable icon + count, disabled while a
/// toggle is in flight so a fast double-tap can't fire two overlapping
/// mutations against the check-then-act `likes` collection guard.
class LikeButton extends StatefulWidget {
  const LikeButton({
    required this.isLiked,
    required this.likesCount,
    required this.onToggle,
    super.key,
  });

  final bool isLiked;
  final int likesCount;
  final Future<void> Function() onToggle;

  @override
  State<LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<LikeButton> {
  bool _toggling = false;

  Future<void> _handleTap() async {
    if (_toggling) return;
    setState(() => _toggling = true);
    try {
      await widget.onToggle();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _toggling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: _toggling ? null : _handleTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              widget.isLiked ? Icons.favorite : Icons.favorite_border,
              size: 20,
              color: widget.isLiked
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              '${widget.likesCount}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: widget.isLiked
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
