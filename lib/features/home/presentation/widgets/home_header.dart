import 'package:flutter/material.dart';
import 'package:finnet/shared/widgets/search_tab_header.dart' show CustomTab;

/// Home's header: the search box over the tabs, as `SearchTabHeader` draws
/// it, but with the tabs and what the search opens handed in -- signed out
/// there is only DISCOVER, and its search is Find events rather than the
/// signed-in feed's.
///
/// With one tab the tab bar is left out.
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
          SliverAppBar(
            floating: true,
            automaticallyImplyLeading: false,
            snap: true,
            pinned: false,
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            elevation: 1,
            shadowColor: Colors.white,
            forceElevated: true,
            expandedHeight: tabbed ? 150.0 : null,
            title: Semantics(
              button: true,
              label: searchHintText,
              excludeSemantics: true,
              child: GestureDetector(
                key: const ValueKey('home-search'),
                onTap: () => onSearch(controller.index),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDFDFC),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: const Color(0xFF1E1E1E), width: 0.5),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search, color: Color(0xFF979797)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          searchHintText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              const TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // As tall as the tabs draw (a padded box over 24 points of
            // label padding), or the app bar overflows; each tab as wide as
            // its name, so three fit a phone without one wrapping.
            bottom: tabbed
                ? PreferredSize(
                    preferredSize: const Size.fromHeight(88),
                    child: TabBar(
                      controller: controller,
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      splashFactory: NoSplash.splashFactory,
                      indicator: const BoxDecoration(color: Colors.transparent),
                      labelColor: Colors.black,
                      labelStyle: const TextStyle(
                          fontFamily: 'BebasNeue', fontSize: 24),
                      labelPadding:
                          const EdgeInsets.only(left: 5, right: 5, bottom: 24),
                      padding: const EdgeInsets.only(left: 12, right: 12),
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: Colors.transparent,
                      dividerColor: Colors.transparent,
                      tabs: [
                        for (var i = 0; i < tabTitles.length; i++)
                          AnimatedBuilder(
                            animation: controller,
                            builder: (_, __) => CustomTab(
                              key: ValueKey('home-tab-$i'),
                              tabTitle: tabTitles[i],
                              isSelected: controller.index == i,
                            ),
                          ),
                      ],
                    ),
                  )
                : null,
          ),
        ],
        body: TabBarView(controller: controller, children: tabPages),
      ),
    );
  }
}
