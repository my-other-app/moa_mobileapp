import 'package:flutter/material.dart';
import 'package:finnet/core/api/api_helper.dart';
import 'package:finnet/features/events/presentation/utils/event_feed.dart';
import 'package:finnet/features/events/presentation/utils/saved_feed.dart';
import 'package:finnet/shared/widgets/error_view.dart';
import 'package:finnet/shared/widgets/shimmer_widgets.dart';
import 'package:finnet/features/home/presentation/pages/home_page_tabs/no_following_club_page.dart';
import 'package:finnet/shared/widgets/entrance.dart';

class FollowingEventsPage extends StatefulWidget {
  const FollowingEventsPage({super.key});

  @override
  State<FollowingEventsPage> createState() => _FollowingEventsPageState();
}

class _FollowingEventsPageState extends State<FollowingEventsPage>
    with AutomaticKeepAliveClientMixin, SavedFirstPageFeed<FollowingEventsPage> {
  @override
  bool get wantKeepAlive => true;

  @override
  String feedPage(int offset) =>
      '/events/list?is_following=true&is_ended=false&offset=$offset&limit=${SavedFirstPageFeed.pageSize}';

  @override
  CachePolicy get feedPolicy => CachePolicy.shared;

  @override
  String get feedErrorFallback => 'Could not load events from clubs you follow.';

  @override
  void initState() {
    super.initState();
    fetchFirstPage();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (isLoading) {
      return Container(
        color: Colors.white,
        child: const SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              ShimmerEventCard(),
              SizedBox(height: 32),
              ShimmerEventCard(),
              SizedBox(height: 32),
              ShimmerEventCard(),
            ],
          ),
        ),
      );
    }

    if (errorMessage != null) {
      return Container(
        color: Colors.white,
        child: ErrorView(
          message: errorMessage,
          onRetry: fetchFirstPage,
        ),
      );
    }

    if (events.isEmpty) {
      return NoFollowingClubPage();
    }

    return NotificationListener<ScrollNotification>(
      onNotification: onFeedScroll,
      child: EntranceScope(
        child: RefreshIndicator(
          onRefresh: fetchFirstPage,
          child: ListView.separated(
            primary: true,
            padding: const EdgeInsets.all(16),
            itemCount: events.length + (hasMore ? 1 : 0),
            separatorBuilder: (context, index) => const Padding(
              padding: EdgeInsets.symmetric(vertical: 20.0),
              child: Divider(
                thickness: 1,
                color: Colors.black,
                indent: 50,
                endIndent: 50,
              ),
            ),
            itemBuilder: (context, index) {
              if (index == events.length) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              final event = Map<String, dynamic>.from(
                  events[index] as Map? ?? const <String, dynamic>{});
              // The first few cards come in one after another.
              return Entrance(index: index, child: eventCardFromJson(event));
            },
          ),
        ),
      ),
    );
  }
}
