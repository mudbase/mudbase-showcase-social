import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// The bottom navigation shell (Feed / Account), one branch per tab via
/// `StatefulShellRoute.indexedStack` - each tab keeps its own navigation
/// stack and scroll position when switching away and back. Only two tabs:
/// this app has no seller/admin split (see `plan/build-plan.md` - a single
/// `customer` application role), unlike the sibling ecommerce showcase.
class HomeShell extends StatelessWidget {
  const HomeShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dynamic_feed_outlined),
            selectedIcon: Icon(Icons.dynamic_feed),
            label: 'Feed',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Account',
          ),
        ],
      ),
    );
  }
}
