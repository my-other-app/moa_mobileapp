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
            selectedItemColor:
                Color(0xFFFFF176), // Soft yellow for selected item
            selectedFontSize: 12,
            unselectedFontSize: 12,
            showUnselectedLabels: true,
            onTap: (index) => onItemTapped(context, index),
            items: const <BottomNavigationBarItem>[
              BottomNavigationBarItem(
                icon: Icon(Icons.home),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.event),
                label: 'Events',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.school),
                label: 'Courses',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.groups),
                label: 'Clubs',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person),
                label: 'Profile',
              ),
            ],
          ),
        );
      },
    );
  }
}
