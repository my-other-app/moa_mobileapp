import 'package:flutter/material.dart';
import 'package:finnet/shared/widgets/search_tab_header.dart';

/// Home's header: the search box over the tabs, as `SearchTabHeader` draws
/// it, but with the tabs and what the search opens handed in -- signed out
/// there is only DISCOVER, and its search is Find events rather than the
/// signed-in feed's.
///
/// With one tab the tab row is left out.
class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.controller,
    required this.tabTitles,
    required this.tabPages,
    required this.onSearch,
    this.searchHintText = 'Search for Events, Interests, Locations....',
  }) : assert(tabTitles.length == tabPages.length);

  final TabController controller;
  final List<String> tabTitles;
  final List<Widget> tabPages;

  /// The search box was tapped on the tab at this index.
  final ValueChanged<int> onSearch;
  final String searchHintText;

  @override
  Widget build(BuildContext context) {
    final tabbed = tabTitles.length > 1;
    return Scaffold(
      backgroundColor: Colors.white,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SearchTabAppBar(
            search: HeaderSearchBox(
              key: const ValueKey('home-search'),
              hintText: searchHintText,
              onTap: () => onSearch(controller.index),
            ),
            tabs: tabbed
                ? HeaderTabs(
                    controller: controller,
                    titles: tabTitles,
                    keyPrefix: 'home-tab',
                  )
                : null,
          ),
        ],
        body: TabBarView(controller: controller, children: tabPages),
      ),
    );
  }
}
