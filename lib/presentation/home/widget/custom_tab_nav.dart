import 'package:flutter/material.dart';

class CustomTabNav extends StatefulWidget {
  const CustomTabNav({super.key});

  @override
  State<CustomTabNav> createState() => _CustomTabNavState();
}

class _CustomTabNavState extends State<CustomTabNav>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this); // Two tabs
  }

  @override
  void dispose() {
    _tabController.dispose(); // Dispose the controller
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          TabBarView(
            controller: _tabController,
            children: const [
              Center(
                child: Text(
                  'UPCOMING TAB',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),
              Center(
                child: Text(
                  'PAST TAB',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
