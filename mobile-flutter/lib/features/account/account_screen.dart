import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import '../profile/profile_screen.dart';

/// The "Account" tab is just the signed-in user's own profile - there is no
/// separate account-settings surface in this app's brief. Reads the current
/// user id and delegates entirely to [ProfileScreen], which already renders
/// a "Sign out" button in place of a follow button when
/// `ProfileState.isOwnProfile` is true.
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).valueOrNull;
    if (user == null) {
      // The router's redirect sends a signed-out session to /login before
      // this can render in practice - this is a defensive fallback only.
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return ProfileScreen(userId: user.id);
  }
}
