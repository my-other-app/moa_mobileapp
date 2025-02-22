import 'package:flutter/material.dart';
import 'package:myotherapp/core/themes/app_colors.dart';
import 'package:myotherapp/presentation/home/widget/custom_search_delegate.dart';

class CustomTab extends StatelessWidget {
  final String tabTitle;
  final bool isSelected;

  const CustomTab({
    required this.tabTitle,
    required this.isSelected,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: isSelected ? Colors.yellow.shade200 : Colors.white,
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      padding: EdgeInsets.all(13),
      alignment: Alignment.center,
      child: Text(tabTitle),
    );
  }
}

class SearchTabHeader extends StatefulWidget {
  /// Titles that appear in the TabBar.
  final List<String> tabTitles;

  /// Pages (scrollable) associated with each tab.
  final List<Widget> tabPages;

  /// Optional hint text for the search bar.
  final String searchHintText;

  /// Optional custom `SearchDelegate`.
  final SearchDelegate? searchDelegate;

  const SearchTabHeader({
    super.key,
    required this.tabTitles,
    required this.tabPages,
    this.searchHintText = 'Search for Events, Interests, Locations...',
    this.searchDelegate,
  });

  @override
  State<SearchTabHeader> createState() => _SearchTabHeaderState();
}

class _SearchTabHeaderState extends State<SearchTabHeader>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  int currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Instead of using a regular appBar, we will build it with Slivers
      body: NestedScrollView(
        // The SliverAppBar + TabBar will be the "headerSliverBuilder" part.
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
          return [
            SliverAppBar(
              // Makes the app bar float up/down as you scroll
              floating: true,
              // Snaps the app bar into view when you scroll up
              snap: true,
              // If pinned = true, the AppBar remains visible at the top;
              // if pinned = false, it fully hides.
              pinned: false,
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              elevation: 1,
              shadowColor: Colors.white,
              forceElevated: true,
              // The height when fully expanded (can adjust as desired)
              expandedHeight: 150.0,

              // The "title" area: put the search bar here.
              // Alternatively, you could use flexibleSpace and
              // FlexibleSpaceBar for more complex behavior.
              title: GestureDetector(
                onTap: () {
                  showSearch(
                    context: context,
                    delegate: widget.searchDelegate ?? CustomSearchDelegate(),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDFDFC), // Slightly off-white
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: const Color(0xFF1E1E1E), width: 0.5),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search, color: Color(0xFF979797)),
                      const SizedBox(width: 8),
                      Text(
                        widget.searchHintText,
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),

              // Put the TabBar in the bottom of the SliverAppBar
              bottom: TabBar(
                controller: _tabController,
                splashFactory: NoSplash.splashFactory,
                indicator: const BoxDecoration(color: Colors.transparent),
                labelColor: Colors.black,
                labelStyle: TextStyle(
                  fontFamily: 'BebasNeue',
                  fontSize: 24,
                ),
                labelPadding: EdgeInsets.only(left: 5, right: 5, bottom: 24),
                padding: EdgeInsets.only(left: 12, right: 12, top: 0),
                unselectedLabelColor: Colors.grey,
                indicatorColor: Colors.transparent,
                dividerColor: Colors.transparent,
                onTap: (index) {
                  setState(() {
                    _tabController.index = index;
                  });
                },
                tabs: widget.tabTitles.asMap().entries.map((entry) {
                  final index = entry.key;
                  final title = entry.value;
                  return CustomTab(
                    tabTitle: title,
                    isSelected: _tabController.index == index,
                  );
                }).toList(),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: widget.tabPages,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    if (widget.tabTitles.isEmpty || widget.tabPages.isEmpty) {
      throw FlutterError(
        'tabTitles and tabPages must not be empty and must have the same length.',
      );
    }

    if (widget.tabTitles.length != widget.tabPages.length) {
      throw FlutterError(
        'The length of tabTitles and tabPages must match.',
      );
    }

    _tabController = TabController(
      vsync: this,
      length: widget.tabTitles.length,
    );
    _tabController.addListener(() {
      if (_tabController.index != _tabController.previousIndex) {
        setState(() {});
      }
    });
  }
}
