import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:myotherapp/core/resources/asset_resources.dart';
import 'package:myotherapp/modules/home/bloc/bottom_nav_bloc.dart';
import 'package:myotherapp/modules/home/bloc/bottom_nav_event.dart';
import 'package:myotherapp/modules/home/bloc/bottom_nav_state.dart';
import 'package:myotherapp/modules/home/pages/clubs_page/clubs_page.dart';
import 'package:myotherapp/modules/home/pages/event_page/events_page.dart';
import 'package:myotherapp/modules/home/pages/home_page/home_page.dart';
import 'package:myotherapp/modules/home/pages/profile_page/profile_page.dart';

BottomNavigationBarItem getBottomNavBarItem({
  required String image,
  required String label,
}) {
  return BottomNavigationBarItem(
    icon: SvgPicture.asset(image, colorFilter: ColorFilter.mode(Colors.grey, BlendMode.srcIn)),
    activeIcon: SvgPicture.asset(image, colorFilter: ColorFilter.mode(Color(0xFFF9FFA1), BlendMode.srcIn)),
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

class LandingPage extends StatelessWidget {
  final List<Widget> _pages = <Widget>[
    HomePage(),
    EventsPage(),
    ClubsPage(),
    ProfilePage(),
  ];

  LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BottomNavigatorBloc, BottomNavigatorState>(
      builder: (context, state) {
        return Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: IndexedStack(
              index: state.index,
              children: _pages,
            ),
          ),
          bottomNavigationBar: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            backgroundColor: const Color(0xFF2C333D),
            currentIndex: state.index,
            unselectedItemColor: Colors.grey[500],
            selectedItemColor: const Color(0xFFF9FFA1),
            onTap: (index) => onItemTapped(context, index),
            items: getBottomNavBarItems(),
          ),
        );
      },
    );
  }

  void onItemTapped(BuildContext context, int index) {
    context.read<BottomNavigatorBloc>().add(UpdateIndexEvent(index: index));
  }
}
