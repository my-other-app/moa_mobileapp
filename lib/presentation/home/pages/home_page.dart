import 'package:flutter/material.dart';
import 'package:myotherapp/presentation/home/pages/following_events_page.dart';
import 'package:myotherapp/presentation/home/pages/for_you_events_page.dart';
import 'package:myotherapp/presentation/home/widget/custom_search_delegate.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  // TabBar Pages
  final List<Widget> _tabPages = const [
    ForYouEventsPage(),
    FollowingEventsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _tabPages.length, // Automatically set based on tabs
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 1,
          // Search Bar
          title: GestureDetector(
            onTap: () {
              // Trigger the search interface
              showSearch(context: context, delegate: CustomSearchDelegate());
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Container(
                height: 56,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDFDFC), // Slightly off-white
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: const Color(0xFF1E1E1E)), // Dark border
                ),
                child: Row(
                  children: const [
                    Icon(Icons.search, color: Color(0xFF979797)),
                    SizedBox(width: 8),
                    Text(
                      'Search for Events, Interests, Locations....',
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Tab Bar
          bottom: TabBar(
            indicator: BoxDecoration(
              color: Colors.yellow, // Background color for the selected tab
              borderRadius: BorderRadius.circular(30), // Rounded corners
            ),
            labelColor: Colors.black, // Selected tab text color
            unselectedLabelColor: Colors.grey, // Unselected tab text color
            labelStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
            tabs: const [
              Tab(text: 'FOR YOU'),
              Tab(text: 'FOLLOWING'),
            ],
          ),
        ),
        // Tab Bar View
        body: TabBarView(
          children: _tabPages,
        ),
      ),
    );
  }
}
