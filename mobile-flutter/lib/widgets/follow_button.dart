import 'package:flutter/material.dart';

/// Shared follow/unfollow control - used on profile screens (hidden on the
/// signed-in user's own profile, gated by [ProfileState.isOwnProfile] at the
/// call site).
class FollowButton extends StatefulWidget {
  const FollowButton({
    required this.isFollowing,
    required this.onToggle,
    super.key,
  });

  final bool isFollowing;
  final Future<void> Function() onToggle;

  @override
  State<FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends State<FollowButton> {
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
    final busy = _toggling;
    if (widget.isFollowing) {
      return OutlinedButton(
        onPressed: busy ? null : _handleTap,
        child: busy
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Following'),
      );
    }
    return ElevatedButton(
      onPressed: busy ? null : _handleTap,
      child: busy
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Text('Follow'),
    );
  }
}
