import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/account/account_screen.dart';
import '../features/auth/auth_controller.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/feed/feed_screen.dart';
import '../features/post/post_detail_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/shell/home_shell.dart';

/// Bridges Riverpod's [authControllerProvider] to go_router's
/// `refreshListenable` - go_router only re-evaluates `redirect` on
/// navigation or when this notifies, so a sign-in/sign-out that happens
/// without a navigation event (e.g. the splash-screen session bootstrap
/// resolving) still re-runs the redirect logic below. Ported from the
/// sibling ecommerce Flutter app's `router/app_router.dart`.
class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(Ref ref) {
    ref.listen(authControllerProvider, (previous, next) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _AuthRefreshNotifier(ref);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refreshNotifier,
    redirect: (context, state) => _redirect(ref, state),
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const _SplashScreen(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            HomeShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/feed',
                builder: (context, state) => const FeedScreen(),
                routes: [
                  GoRoute(
                    path: 'post/:id',
                    builder: (context, state) =>
                        PostDetailScreen(postId: state.pathParameters['id']!),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/account',
                builder: (context, state) => const AccountScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/profile/:userId',
        builder: (context, state) =>
            ProfileScreen(userId: state.pathParameters['userId']!),
      ),
    ],
  );
});

String? _redirect(Ref ref, GoRouterState state) {
  final authState = ref.read(authControllerProvider);
  final location = state.matchedLocation;
  final isAuthRoute = location == '/login' || location == '/register';

  if (authState.isLoading) {
    return location == '/splash' ? null : '/splash';
  }

  final user = authState.valueOrNull;
  if (user == null) {
    return isAuthRoute ? null : '/login';
  }

  if (isAuthRoute || location == '/splash') {
    return '/feed';
  }

  return null;
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
