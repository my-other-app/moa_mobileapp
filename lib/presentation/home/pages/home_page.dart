import 'package:flutter/material.dart';
import 'package:myotherapp/presentation/home/pages/home_page_tabs/following_events_page.dart';
import 'package:myotherapp/presentation/home/pages/home_page_tabs/for_you_events_page.dart';
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

  final _tabs = [
    'FOR YOU',
<<<<<<< HEAD
    'FOLLOWING',
=======
    'FOLLOWING',    
>>>>>>> b92c26e (fix(tabBar): updated tabBar UI)
  ];

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(vsync: this, length: _tabs.length);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
<<<<<<< HEAD
        toolbarHeight: kToolbarHeight + 30, // Adds extra space to the bottom
        flexibleSpace: Padding(
          padding: const EdgeInsets.symmetric(
              vertical: 20), // Adjust the bottom padding here
          child: Container(),
        ),
=======
        shadowColor: Colors.black26,
        toolbarHeight: kToolbarHeight + 50, // Adds extra space to the bottom
       
>>>>>>> b92c26e (fix(tabBar): updated tabBar UI)
        // Search Bar
        title: GestureDetector(
          onTap: () {
            // Trigger the search interface
            showSearch(context: context, delegate: CustomSearchDelegate());
          },
          child: Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFDFDFC), // Slightly off-white
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF1E1E1E)), // Dark border
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
        // Tab Bar
        bottom: TabBar(
          splashFactory: NoSplash.splashFactory,
          overlayColor: WidgetStateProperty.resolveWith<Color?>(
              (Set<WidgetState> states) {
            // Use the default focused overlay color
            return states.contains(WidgetState.focused)
                ? null
                : Colors.transparent;
          }),
          controller: _tabController,
          indicator: BoxDecoration(color: Colors.transparent),
          labelColor: Colors.black, // Selected tab text color
          unselectedLabelColor: Colors.grey, // Unselected tab text color
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
          onTap: (index) {
            setState(() {
              _tabController.index = index;
            });
          },
          tabs: _tabs
              .asMap()
              .map((index, tabTitle) {
                return MapEntry(
                  index,
                  CustomTab(
                    tabTitle: tabTitle,
                    isSelected: _tabController.index ==
                        index, // Check if the tab is selected
                  ),
                );
              })
              .values
              .toList(),
        ),
      ),
      // Tab Bar View
      body: TabBarView(
        controller: _tabController,
        children: _tabPages,
      ),
    );
  }
}
<<<<<<< HEAD

=======
>>>>>>> b92c26e (fix(tabBar): updated tabBar UI)
class CustomTab extends StatelessWidget {
  const CustomTab({
    required this.tabTitle,
    required this.isSelected,
    super.key,
  });

  final String tabTitle;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
<<<<<<< HEAD
    return Tab(
      height: 60,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Container(
          width: MediaQuery.of(context).size.width /
              2, // Adjusted to fit both tabs better
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: isSelected
                ? Color(0xFFF9FFA1)
                : Colors.white, // Change color based on selected
            border: Border.all(color: const Color(0xFF1E1E1E)), // Dark border
          ),
          child: Center(child: Text(tabTitle)),
=======
    return Padding(
      padding: const EdgeInsets.only(top: 10 ,bottom: 25),
      child: SizedBox(
        height: 60, // Increase the height of the Tab container
        child: Tab(
          child: FractionallySizedBox(
            widthFactor: 1,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: isSelected
                    ? Colors.yellow.shade200
                    : Colors.white, // Change color based on selected
                border: Border.all(
                  color: Colors.black,
                ),
              ),
              child: Center(child: Text(tabTitle)),
            ),
          ),
>>>>>>> b92c26e (fix(tabBar): updated tabBar UI)
        ),
      ),
    );
  }
}
