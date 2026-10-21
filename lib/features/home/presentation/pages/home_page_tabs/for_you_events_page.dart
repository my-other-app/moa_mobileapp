import 'package:flutter/material.dart';
import 'package:finnet/core/api/api_helper.dart';
import 'package:finnet/features/events/presentation/utils/event_feed.dart';
import 'package:finnet/features/events/presentation/utils/saved_feed.dart';
import 'package:finnet/features/topics/presentation/widgets/browse_by_topic_row.dart';
import 'package:finnet/shared/widgets/error_view.dart';
import 'package:finnet/shared/widgets/shimmer_widgets.dart';
import 'package:finnet/shared/widgets/entrance.dart';

class ForYouEventsPage extends StatefulWidget {
  const ForYouEventsPage({super.key});

  @override
  State<ForYouEventsPage> createState() => _ForYouEventsPageState();
}

class _ForYouEventsPageState extends State<ForYouEventsPage>
    with AutomaticKeepAliveClientMixin, SavedFirstPageFeed<ForYouEventsPage> {
  @override
  bool get wantKeepAlive => true;

  @override
  String feedPage(int offset) =>
      '/events/for-you?offset=$offset&limit=${SavedFirstPageFeed.pageSize}';

  /// The feed is ranked for the person, but holds nothing private.
  @override
  CachePolicy get feedPolicy => CachePolicy.shared;

  @override
  String get feedErrorFallback => 'Could not load your feed.';

  @override
  void initState() {
    super.initState();
    fetchFirstPage();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // Loading state
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
            ],
          ),
        ),
      );
    }

    // Error state
    if (errorMessage != null) {
      return Container(
        color: Colors.white,
        child: ErrorView(
          message: errorMessage,
          onRetry: fetchFirstPage,
        ),
      );
    }

    // Empty state -- with the topics to browse, a way to find something.
    if (events.isEmpty) {
      return Container(
        color: Colors.white,
        padding: const EdgeInsets.all(16),
        child: const Column(
          children: [
            BrowseByTopicRow(bottomGap: 20),
            Expanded(
              child: Center(
                child: Text(
                  'Nothing to show on the feed',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Content with NotificationListener for pagination
    return NotificationListener<ScrollNotification>(
      onNotification: onFeedScroll,
      child: EntranceScope(
          child: RefreshIndicator(
        onRefresh: fetchFirstPage,
        child: ListView.separated(
          // Use primary: true to cooperate with NestedScrollView
          primary: true,
          padding: const EdgeInsets.all(16),
          // "Browse by topic" first, then the feed.
          itemCount: 1 + events.length + (hasMore ? 1 : 0),
          separatorBuilder: (context, index) => index == 0
              ? const SizedBox.shrink()
              : const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20.0),
                  child: Divider(
                    thickness: 1,
                    color: Colors.black,
                    indent: 50,
                    endIndent: 50,
                  ),
                ),
          itemBuilder: (context, position) {
            if (position == 0) return const BrowseByTopicRow(bottomGap: 20);
            final index = position - 1;
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
      )),
    );
  }
}
