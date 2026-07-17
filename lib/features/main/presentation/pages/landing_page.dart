import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:finnet/core/resources/asset_resources.dart';
import 'package:finnet/features/home/presentation/providers/bottom_nav_provider.dart';
import 'package:finnet/features/clubs/presentation/pages/clubs_page.dart';
import 'package:finnet/features/events/presentation/pages/events_page.dart';
import 'package:finnet/features/home/presentation/pages/home_page.dart';
import 'package:finnet/features/profile/presentation/pages/profile_page.dart';

BottomNavigationBarItem getBottomNavBarItem({
  required String image,
  required String label,
}) {
  return BottomNavigationBarItem(
    icon: SvgPicture.asset(image,
        colorFilter: ColorFilter.mode(Colors.grey, BlendMode.srcIn)),
    activeIcon: SvgPicture.asset(image,
        colorFilter: ColorFilter.mode(Color(0xFFF9FFA1), BlendMode.srcIn)),
    label: label,
  );
}

List<BottomNavigationBarItem> getBottomNavBarItems() {
  return [
    getBottomNavBarItem(image: AssetResources.home, label: 'Home'),
    getBottomNavBarItem(image: AssetResources.events, label: 'Events'),
    getBottomNavBarItem(image: AssetResources.clubs, label: 'Clubs'),
    getBottomNavBarItem(image: AssetResources.profile, label: 'Profile'),
  ];
}

/// Landing page - fully migrated to Riverpod (no Bloc).
class LandingPage extends ConsumerWidget {
  final List<Widget> _pages = <Widget>[
    HomePage(),
    EventsPage(),
    ClubsPage(),
    ProfilePage(),
  ];

  LandingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(bottomNavIndexProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _pages[currentIndex],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xFF2C333D),
        currentIndex: currentIndex,
        unselectedItemColor: Colors.grey[500],
        selectedItemColor: const Color(0xFFF9FFA1),
        onTap: (index) =>
            ref.read(bottomNavIndexProvider.notifier).updateIndex(index),
        items: getBottomNavBarItems(),
      ),
    );
  }
}
