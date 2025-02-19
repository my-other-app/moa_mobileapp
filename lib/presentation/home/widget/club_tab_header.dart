import 'package:flutter/material.dart';
import 'package:myotherapp/core/themes/app_colors.dart';

import '../../../core/resources/asset_resources.dart';
import 'svg_icon.dart';

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

class ClubTabHeader extends StatefulWidget {
  /// Titles that appear in the TabBar.
  final List<String> tabTitles;

  /// Pages (scrollable) associated with each tab.
  final List<Widget> tabPages;

  const ClubTabHeader({
    super.key,
    required this.tabTitles,
    required this.tabPages,
  });

  @override
  State<ClubTabHeader> createState() => _ClubTabHeaderState();
}

class _ClubTabHeaderState extends State<ClubTabHeader>
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
              shadowColor: Colors.grey,
              forceElevated: true,
              // The height when fully expanded (can adjust as desired)
              expandedHeight: 150.0,

              // The "title" area: put the search bar here.
              // Alternatively, you could use flexibleSpace and
              // FlexibleSpaceBar for more complex behavior.
              title: const Text(
                'TinkerHub CET',
                style: TextStyle(fontSize: 24, fontFamily: 'BebasNeue'),
              ),
              actions: [
                IconButton(
                  icon: SvgIcon(svgIconPath: AssetResources.share),
                  onPressed: () {
                    // TODO: Implement share functionality
                  },
                ),
              ],
              centerTitle: true,

              foregroundColor: Colors.black,

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
