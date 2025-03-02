import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:myotherapp/modules/home/bloc/bottom_nav_bloc.dart';
import 'package:myotherapp/modules/home/bloc/bottom_nav_event.dart';
import 'package:myotherapp/modules/home/bloc/bottom_nav_state.dart';
import 'package:myotherapp/modules/home/pages/clubs_page/clubs_page.dart';
import 'package:myotherapp/modules/home/pages/event_page/events_page.dart';
import 'package:myotherapp/modules/home/pages/home_page/home_page.dart';
import 'package:myotherapp/modules/home/pages/profile_page/profile_page.dart';

class LandingPage extends StatelessWidget {
  LandingPage({super.key});

  final List<Widget> _pages = <Widget>[
    HomePage(),
    EventsPage(),
    ClubsPage(),
    ProfilePage(),
  ];

  void onItemTapped(BuildContext context, int index) {
    context.read<BottomNavigatorBloc>().add(UpdateIndexEvent(index: index));
  }

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
}

List<BottomNavigationBarItem> getBottomNavBarItems() {
  return [
    getBottomNavBarItem(icon: Icons.home, label: 'Home'),
    getBottomNavBarItem(icon: Icons.event, label: 'Events'),
    getBottomNavBarItem(icon: Icons.groups, label: 'Clubs'),
    getBottomNavBarItem(icon: Icons.person, label: 'Profile'),
  ];
}

BottomNavigationBarItem getBottomNavBarItem({
  required IconData icon,
  required String label,
}) {
  return BottomNavigationBarItem(
    icon: Icon(icon),
    label: label,
  );
}