import 'package:flutter/material.dart';
import 'package:finnet/core/themes/app_colors.dart';
import 'package:finnet/shared/widgets/custom_search_delegate.dart';

const _ink = Color(0xFF1E1E1E);
const _muted = Color(0xFF6B6B6B);

/// The main tabs' header, measured once so Home, Events and Clubs line up:
/// the search box and the tabs share the same gutter, so their edges meet.
abstract final class TabHeaderLayout {
  /// Left and right of the search box and the tabs.
  static const gutter = 16.0;

  static const searchHeight = 48.0;

  /// Above the search box, and under it when there are no tabs.
  static const top = 8.0;

  /// Between the search box and the tabs.
  static const gap = 10.0;

  static const tabHeight = 42.0;

  /// Between one tab and the next.
  static const tabSpacing = 8.0;

  /// Under the tabs.
  static const bottom = 12.0;

  static const radius = 10.0;

  /// How far the header's text grows with the phone's text size. Past it
  /// the hint and the tab names stay put rather than break the header,
  /// which is a fixed height so it can float and snap.
  static const maxTextScale = 1.3;

  /// The toolbar: the search box with [top] above and below it.
  static const toolbarHeight = searchHeight + 2 * top;
}

/// One tab in the header's row: as wide as its share of the row, filled
/// yellow when it is the one showing and outlined otherwise.
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
    return SizedBox(
      height: TabHeaderLayout.tabHeight,
      width: double.infinity,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.softYellow : Colors.white,
          borderRadius: BorderRadius.circular(TabHeaderLayout.radius),
          border: Border.all(
            color: AppColors.border,
            width: isSelected ? 1 : 0.5,
          ),
        ),
        // Shrinks rather than wraps or clips: "FOLLOWING" fits a third of
        // a small phone at any text size.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            tabTitle,
            maxLines: 1,
            style: TextStyle(
              fontFamily: 'BebasNeue',
              fontSize: 21,
              height: 1.1,
              letterSpacing: 0.6,
              color: isSelected ? _ink : _muted,
            ),
          ),
        ),
      ),
    );
  }
}

/// The header's search box: shaped like a field, 48 points tall, and a
/// button that opens the search.
class HeaderSearchBox extends StatelessWidget {
  const HeaderSearchBox({
    super.key,
    required this.hintText,
    required this.onTap,
  });

  final String hintText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context)
        .clamp(maxScaleFactor: TabHeaderLayout.maxTextScale);
    return Semantics(
      button: true,
      label: hintText,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: const Color(0xFFFDFDFC),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TabHeaderLayout.radius),
          side: const BorderSide(color: AppColors.border, width: 0.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: TabHeaderLayout.searchHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  const Icon(Icons.search, size: 22, color: Color(0xFF979797)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      hintText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textScaler: scaler,
                      style: const TextStyle(
                        color: Color(0xFF8A8A8A),
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The header's tabs: one row filling the width between the gutters, in
/// equal shares, under the search box.
class HeaderTabs extends StatelessWidget implements PreferredSizeWidget {
  const HeaderTabs({
    super.key,
    required this.controller,
    required this.titles,
    this.keyPrefix,
    this.onTap,
  });

  final TabController controller;
  final List<String> titles;

  /// Each tab is keyed `$keyPrefix-$index` when given.
  final String? keyPrefix;
  final ValueChanged<int>? onTap;

  // The toolbar already leaves [TabHeaderLayout.top] under the search box.
  static const _above = TabHeaderLayout.gap - TabHeaderLayout.top;

  @override
  Size get preferredSize => const Size.fromHeight(
      _above + TabHeaderLayout.tabHeight + TabHeaderLayout.bottom);

  @override
  Widget build(BuildContext context) {
    const half = TabHeaderLayout.tabSpacing / 2;
    return Padding(
      // Half the spacing sits either side of every tab, so the outer edges
      // land on the gutter.
      padding: const EdgeInsets.fromLTRB(TabHeaderLayout.gutter - half, _above,
          TabHeaderLayout.gutter - half, TabHeaderLayout.bottom),
      child: TabBar(
        controller: controller,
        isScrollable: false,
        tabAlignment: TabAlignment.fill,
        padding: EdgeInsets.zero,
        labelPadding: const EdgeInsets.symmetric(horizontal: half),
        indicator: const BoxDecoration(),
        indicatorWeight: 0,
        dividerHeight: 0,
        dividerColor: Colors.transparent,
        splashFactory: NoSplash.splashFactory,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        textScaler: MediaQuery.textScalerOf(context)
            .clamp(maxScaleFactor: TabHeaderLayout.maxTextScale),
        onTap: onTap,
        tabs: [
          for (var i = 0; i < titles.length; i++)
            AnimatedBuilder(
              animation: controller,
              builder: (_, __) => CustomTab(
                key: keyPrefix == null ? null : ValueKey('$keyPrefix-$i'),
                tabTitle: titles[i],
                isSelected: controller.index == i,
              ),
            ),
        ],
      ),
    );
  }
}

/// The main tabs' header as a sliver: [search] over [tabs] (when there are
/// any), floating away as the page scrolls and snapping back.
class SearchTabAppBar extends StatelessWidget {
  const SearchTabAppBar({super.key, required this.search, this.tabs});

  final Widget search;
  final HeaderTabs? tabs;

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      floating: true,
      snap: true,
      pinned: false,
      automaticallyImplyLeading: false,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 1,
      shadowColor: Colors.white,
      forceElevated: true,
      toolbarHeight: TabHeaderLayout.toolbarHeight,
      titleSpacing: TabHeaderLayout.gutter,
      centerTitle: false,
      title: search,
      bottom: tabs,
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

  /// Filter types for each tab (used for event search).
  /// Values: 'for_you', 'following', 'registered', 'past'
  final List<String>? tabFilterTypes;

  const SearchTabHeader({
    super.key,
    required this.tabTitles,
    required this.tabPages,
    this.searchHintText = 'Search for Events, Interests, Locations...',
    this.tabFilterTypes,
  });

  @override
  State<SearchTabHeader> createState() => _SearchTabHeaderState();
}

class _SearchTabHeaderState extends State<SearchTabHeader>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  void _search() {
    // The search is for the tab showing.
    final index = _tabController.index;
    final types = widget.tabFilterTypes;
    final filterType =
        types != null && index < types.length ? types[index] : 'for_you';
    showSearch(
      context: context,
      delegate: EventSearchDelegate(filterType: filterType),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: NestedScrollView(
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
          return [
            SearchTabAppBar(
              search: HeaderSearchBox(
                hintText: widget.searchHintText,
                onTap: _search,
              ),
              tabs: HeaderTabs(
                controller: _tabController,
                titles: widget.tabTitles,
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
  }
}
