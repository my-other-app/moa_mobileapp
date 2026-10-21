import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:finnet/core/resources/asset_resources.dart';
import 'package:finnet/features/events/presentation/widgets/saved_tickets_sync.dart';
import 'package:finnet/features/main/presentation/providers/navigation_index_provider.dart';
import 'package:finnet/shared/motion.dart';

export 'package:finnet/features/main/presentation/providers/navigation_index_provider.dart';

/// Main shell widget that contains the bottom navigation bar.
///
/// This widget wraps the main navigation routes and provides
/// a persistent bottom navigation bar across all main screens.
class MainShell extends ConsumerWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(navigationIndexProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      // The signed-in screens: while they are up, the tickets on the phone
      // are kept current for the door.
      body: SavedTicketsSync(child: SafeArea(child: child)),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF2C333D),
        currentIndex: currentIndex,
        unselectedItemColor: Colors.grey[500],
        selectedItemColor: const Color(0xFFF9FFA1),
        onTap: (index) => _onItemTapped(context, ref, index),
        items: _buildNavItems(),
      ),
    );
  }

  List<BottomNavigationBarItem> _buildNavItems() {
    return [
      _buildNavItem(image: AssetResources.home, label: 'Home'),
      _buildNavItem(image: AssetResources.events, label: 'Events'),
      _buildNavItem(image: AssetResources.clubs, label: 'Clubs'),
      _buildNavItem(image: AssetResources.profile, label: 'Profile'),
    ];
  }

  BottomNavigationBarItem _buildNavItem({
    required String image,
    required String label,
  }) {
    return BottomNavigationBarItem(
      icon: SvgPicture.asset(
        image,
        colorFilter: const ColorFilter.mode(Colors.grey, BlendMode.srcIn),
      ),
      // Built afresh each time its tab is chosen, so it pops as it lights.
      activeIcon: _ChosenIcon(
        child: SvgPicture.asset(
          image,
          colorFilter:
              const ColorFilter.mode(Color(0xFFF9FFA1), BlendMode.srcIn),
        ),
      ),
      label: label,
    );
  }

  void _onItemTapped(BuildContext context, WidgetRef ref, int index) {
    // Choosing another tab is felt; tapping the one already open is not.
    if (index != ref.read(navigationIndexProvider)) Haptics.selection();

    // Update the navigation index
    ref.read(navigationIndexProvider.notifier).state = index;

    // Navigate to the corresponding route
    switch (index) {
      case 0:
        context.go('/');
        break;
      case 1:
        context.go('/events');
        break;
      case 2:
        context.go('/clubs');
        break;
      case 3:
        context.go('/profile');
        break;
    }
  }
}

/// The chosen tab's icon: it grows from a little under its size to its
/// size, with a slight overshoot, as the tab is chosen.
class _ChosenIcon extends StatelessWidget {
  const _ChosenIcon({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.8, end: 1),
      duration: motionDuration(context, Motion.slow),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: child,
    );
  }
}
