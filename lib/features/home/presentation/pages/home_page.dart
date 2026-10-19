import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/auth/presentation/widgets/email_verification_banner.dart';
import 'package:finnet/features/discover/presentation/discover_navigation.dart';
import 'package:finnet/features/home/presentation/pages/home_page_tabs/discover_home_page.dart';
import 'package:finnet/features/home/presentation/pages/home_page_tabs/following_events_page.dart';
import 'package:finnet/features/home/presentation/pages/home_page_tabs/for_you_events_page.dart';
import 'package:finnet/features/home/presentation/widgets/home_header.dart';
import 'package:finnet/shared/widgets/custom_search_delegate.dart';

/// Where Home's search opens: Find events, its search box ready.
const homeSearchLocation = '$findEventsPath?focus=search';

/// Home: DISCOVER (the website's front page), then -- signed in -- FOR YOU
/// and FOLLOWING as before, with the verify-your-email banner above for an
/// email/password account that has not verified yet.
///
/// Signed out there is only DISCOVER: the other two are about the person.
/// DISCOVER's search opens Find events; FOR YOU's and FOLLOWING's search
/// their own feeds, as they always have.
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  static const discoverTab = 'DISCOVER';
  static const signedInTabs = [discoverTab, 'FOR YOU', 'FOLLOWING'];
  static const signedOutTabs = [discoverTab];

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage>
    with TickerProviderStateMixin {
  TabController? _tabs;

  /// The controller for [length] tabs: the same one while the tabs stay,
  /// a new one when signing in or out changes them. The old one is let go
  /// after the frame, once the tab bar has stopped listening to it.
  TabController _controllerFor(int length) {
    final current = _tabs;
    if (current != null && current.length == length) return current;
    if (current != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => current.dispose());
    }
    return _tabs = TabController(length: length, vsync: this);
  }

  @override
  void dispose() {
    _tabs?.dispose();
    super.dispose();
  }

  void _search(int index, List<String> titles) {
    if (titles[index] == HomePage.discoverTab) {
      context.push(homeSearchLocation);
      return;
    }
    showSearch(
      context: context,
      delegate: EventSearchDelegate(
        filterType: titles[index] == 'FOLLOWING' ? 'following' : 'for_you',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = ref.watch(isAuthenticatedProvider);
    final titles = signedIn ? HomePage.signedInTabs : HomePage.signedOutTabs;
    final controller = _controllerFor(titles.length);
    final following = titles.indexOf('FOLLOWING');

    return Column(
      children: [
        if (signedIn) const EmailVerificationBanner(),
        Expanded(
          child: HomeHeader(
            key: ValueKey('home-tabs-${titles.length}'),
            controller: controller,
            tabTitles: titles,
            tabPages: [
              DiscoverHomePage(
                onSeeFollowing: following < 0
                    ? null
                    : () => controller.animateTo(following),
              ),
              if (signedIn) ...const [ForYouEventsPage(), FollowingEventsPage()],
            ],
            searchHintText: 'Search for Events, Interests, Locations....',
            onSearch: (index) => _search(index, titles),
          ),
        ),
      ],
    );
  }
}
