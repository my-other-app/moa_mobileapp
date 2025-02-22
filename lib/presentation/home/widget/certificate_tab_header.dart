import 'package:flutter/material.dart';
import 'package:myotherapp/core/themes/app_colors.dart';

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
      padding: const EdgeInsets.all(13),
      alignment: Alignment.center,
      child: Text(tabTitle),
    );
  }
}

class CertificateTabHeader extends StatefulWidget {
  /// Titles that appear in the TabBar.
  final List<String> tabTitles;

  /// Pages (scrollable) associated with each tab.
  final List<Widget> tabPages;

  /// Optional custom SearchDelegate for showSearch().
  final SearchDelegate? searchDelegate;

  /// Placeholder text in the search bar.
  final String searchHintText;

  const CertificateTabHeader({
    Key? key,
    required this.tabTitles,
    required this.tabPages,
    this.searchDelegate,
    this.searchHintText = 'Search for Certificates',
  }) : super(key: key);

  @override
  State<CertificateTabHeader> createState() => _CertificateTabHeaderState();
}

class _CertificateTabHeaderState extends State<CertificateTabHeader>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();

    // Validate that we have matching counts for titles and pages.
    if (widget.tabTitles.isEmpty || widget.tabPages.isEmpty) {
      throw FlutterError(
        'tabTitles and tabPages must not be empty.',
      );
    }
    if (widget.tabTitles.length != widget.tabPages.length) {
      throw FlutterError(
        'tabTitles and tabPages must have the same length.',
      );
    }

    // Create a TabController for the given number of tabs.
    _tabController = TabController(
      length: widget.tabTitles.length,
      vsync: this,
    );

    // Listen to tab index changes if you need to rebuild the UI or run logic.
    _tabController.addListener(() {
      if (_tabController.index != _tabController.previousIndex) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Fallback delegate if user didn't pass a custom SearchDelegate
  SearchDelegate get _defaultSearchDelegate => _DummySearchDelegate();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: NestedScrollView(
          // NestedScrollView allows the SliverAppBar to remain pinned
          // and your content to scroll inside the TabBarView
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverAppBar(
              // Pinned so the entire bar (title, search, tabs) stays at the top.
              pinned: false,
              floating: false,
              snap: false,

              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              elevation: 1.0,
              shadowColor: Colors.grey,
              // forceElevated ensures a shadow appears when scrolled.
              forceElevated: innerBoxIsScrolled,

              // Center the title (optional).
              centerTitle: true,
              title: const Text(
                'Certificates',
                style: TextStyle(
                  fontSize: 24,
                  fontFamily: 'BebasNeue',
                ),
              ),

              // If you want extra space for a collapsing layout,
              // you can use expandedHeight + flexibleSpace.
              // For a simple pinned layout, prefer using bottom + PreferredSize.

              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(120.0),
                child: Column(
                  children: [
                    // Search bar
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: GestureDetector(
                        onTap: () {
                          showSearch(
                            context: context,
                            delegate:
                                widget.searchDelegate ?? _defaultSearchDelegate,
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFDFDFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFF1E1E1E),
                              width: 0.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.search,
                                  color: Color(0xFF979797)),
                              const SizedBox(width: 8),
                              Text(
                                widget.searchHintText,
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // TabBar
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TabBar(
                        controller: _tabController,
                        splashFactory: NoSplash.splashFactory,
                        indicator:
                            const BoxDecoration(color: Colors.transparent),
                        labelColor: Colors.black,
                        labelStyle: const TextStyle(
                          fontFamily: 'BebasNeue',
                          fontSize: 24,
                        ),
                        unselectedLabelColor: Colors.grey,
                        indicatorColor: Colors.transparent,
                        dividerColor: Colors.transparent,
                        labelPadding: EdgeInsets.zero,
                        onTap: (index) => setState(() {
                          _tabController.index = index;
                        }),
                        tabs: widget.tabTitles.asMap().entries.map((entry) {
                          final index = entry.key;
                          final title = entry.value;
                          return Padding(
                            // If you want a 12px gap between tabs,
                            // you can do 6px for the right side of the first tab,
                            // and 6px for the left side of the subsequent tabs:
                            padding: index == 0
                                ? const EdgeInsets.only(right: 6)
                                : const EdgeInsets.only(left: 6),
                            child: CustomTab(
                              tabTitle: title,
                              isSelected: _tabController.index == index,
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ],
          body: TabBarView(
            controller: _tabController,
            children: widget.tabPages,
          ),
        ),
      ),
    );
  }
}

/// A simple SearchDelegate that does nothing, just to avoid errors.
class _DummySearchDelegate extends SearchDelegate {
  @override
  List<Widget> buildActions(BuildContext context) => [];
  @override
  Widget buildLeading(BuildContext context) => BackButton();
  @override
  Widget buildResults(BuildContext context) => Container();
  @override
  Widget buildSuggestions(BuildContext context) => Container();
}
