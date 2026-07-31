import 'package:flutter/material.dart';

import '../../../widgets/follow_button.dart';
import '../profile_controller.dart';

class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    required this.state,
    required this.onToggleFollow,
    required this.onSignOut,
    super.key,
  });

  final ProfileState state;
  final Future<void> Function() onToggleFollow;
  final Future<void> Function()? onSignOut;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: colorScheme.primaryContainer,
            child: Text(
              _initials(state.displayName),
              style: TextStyle(
                color: colorScheme.onPrimaryContainer,
                fontSize: 28,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            state.displayName,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _StatColumn(label: 'Posts', value: state.posts.length),
              const SizedBox(width: 32),
              _StatColumn(label: 'Followers', value: state.followerCount),
              const SizedBox(width: 32),
              _StatColumn(label: 'Following', value: state.followingCount),
            ],
          ),
          const SizedBox(height: 20),
          if (!state.isOwnProfile)
            FollowButton(
              isFollowing: state.isFollowing,
              onToggle: onToggleFollow,
            )
          else if (onSignOut != null)
            OutlinedButton.icon(
              onPressed: onSignOut,
              icon: const Icon(Icons.logout),
              label: const Text('Sign out'),
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

class _StatColumn extends StatelessWidget {
  const _StatColumn({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Text(
          '$value',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
