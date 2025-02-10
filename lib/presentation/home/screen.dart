import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:myotherapp/presentation/home/bloc/bottom_nav_bloc.dart';
import 'package:myotherapp/presentation/home/bloc/bottom_nav_event.dart';
import 'package:myotherapp/presentation/home/bloc/bottom_nav_state.dart';
import 'package:myotherapp/presentation/home/pages/clubs_page.dart';
import 'package:myotherapp/presentation/home/pages/courses_page.dart';
import 'package:myotherapp/presentation/home/pages/events_page.dart';
import 'package:myotherapp/presentation/home/pages/home_page.dart';
import 'package:myotherapp/presentation/home/pages/profile_page.dart';

class LandingPage extends StatelessWidget {
  LandingPage({super.key});

  final List<Widget> _pages = <Widget>[
    HomePage(),
    EventsPage(),
    CoursesPage(),
    ClubsPage(),
    ProfilePage()
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
          body: _pages[state.index],
          bottomNavigationBar: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            backgroundColor: Color(0xFF1F1F1F), // Dark background
            currentIndex: state.index,
            unselectedItemColor: Colors.grey[500],
<<<<<<< HEAD
            selectedItemColor:
                Color(0xFFF9FFA1), // Soft yellow for selected item
=======
            selectedItemColor: Color(0xFFFFF176), // Soft yellow for selected item
>>>>>>> b92c26e (fix(tabBar): updated tabBar UI)
            onTap: (index) => onItemTapped(context, index),
            items: getBottomNavBarItems(), // Use the method to get items
          ),
        );
      },
    );
  }
}
<<<<<<< HEAD

List<BottomNavigationBarItem> getBottomNavBarItems() {
  return [
    getBottomNavBarItem(icon: Icons.home, label: 'Home'),
    getBottomNavBarItem(icon: Icons.event, label: 'Events'),
    getBottomNavBarItem(icon: Icons.school, label: 'Courses'),
    getBottomNavBarItem(icon: Icons.groups, label: 'Clubs'),
    getBottomNavBarItem(icon: Icons.person, label: 'Profile'),
  ];
}

BottomNavigationBarItem getBottomNavBarItem(
    {required IconData icon, required String label}) {
=======
 List<BottomNavigationBarItem> getBottomNavBarItems() {
    return [
      getBottomNavBarItem(icon: Icons.home, label: 'Home'),
      getBottomNavBarItem(icon: Icons.event, label: 'Events'),
      getBottomNavBarItem(icon: Icons.school, label: 'Courses'),
      getBottomNavBarItem(icon: Icons.groups, label: 'Clubs'),
      getBottomNavBarItem(icon: Icons.person, label: 'Profile'),
    ];
  }
  
BottomNavigationBarItem getBottomNavBarItem({required IconData icon, required String label}) {
>>>>>>> b92c26e (fix(tabBar): updated tabBar UI)
  return BottomNavigationBarItem(
    icon: Icon(icon),
    label: label,
  );
<<<<<<< HEAD
}
=======
}
>>>>>>> b92c26e (fix(tabBar): updated tabBar UI)
