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
          body: _pages[state.index], 
          bottomNavigationBar: BottomNavigationBar(
            backgroundColor: Colors.black,
            currentIndex: state.index,
            unselectedItemColor: Colors.black38,
            selectedItemColor: Colors.amber[800],
            onTap: (index) => onItemTapped(context, index), 
            items: const <BottomNavigationBarItem>[
              BottomNavigationBarItem(
                icon: Icon(Icons.home),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.business),
                label: 'Events',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.school),
                label: 'Courses',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.groups),  // Changed the icon for Clubs
                label: 'Clubs',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_2_rounded),
                label: 'Profile',
              ),
            ],
          ),
        );
      },
    );
  }
}
