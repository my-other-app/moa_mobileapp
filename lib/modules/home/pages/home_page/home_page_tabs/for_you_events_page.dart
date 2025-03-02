import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:myotherapp/core/api/api_helper.dart';
import 'package:myotherapp/modules/home/custom_widgets/event_card.dart';

class ForYouEventsPage extends StatefulWidget {
  const ForYouEventsPage({super.key});

  @override
  State<ForYouEventsPage> createState() => _ForYouEventsPageState();
  
}

class _ForYouEventsPageState extends State<ForYouEventsPage> with AutomaticKeepAliveClientMixin{

   @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    // Create a ValueNotifier to hold the events
    final ValueNotifier<List<dynamic>> eventsNotifier = ValueNotifier([]);
    final ValueNotifier<bool> isLoadingNotifier = ValueNotifier(true);
    final ValueNotifier<String?> errorMessageNotifier = ValueNotifier(null);

    // Fetch data when the widget is built
    _fetchData(eventsNotifier, isLoadingNotifier, errorMessageNotifier);

    return ValueListenableBuilder<List<dynamic>>(
      valueListenable: eventsNotifier,
      builder: (context, events, child) {
        return ValueListenableBuilder<bool>(
          valueListenable: isLoadingNotifier,
          builder: (context, isLoading, child) {
            if (isLoading) {
              return const Center(
                child: CircularProgressIndicator(
                  backgroundColor: Colors.white,
                ),
              );
            }
            return ValueListenableBuilder<String?>(
              valueListenable: errorMessageNotifier,
              builder: (context, errorMessage, child) {
                if (errorMessage != null) {
                  return Center(child: Text('Error: $errorMessage'));
                }
                // If there are no events, show a message.
                if (events.isEmpty) {
                  return const Scaffold(
                    backgroundColor: Colors.white,
                    body: Center(
                      child: Text(
                        'Nothing to show on the feed',
                        style: TextStyle(fontSize: 18),
                      ),
                    ),
                  );
                }
                return Scaffold(
                  backgroundColor: Colors.white,
                  body: RefreshIndicator(
                    onRefresh: () => _fetchData(eventsNotifier, isLoadingNotifier, errorMessageNotifier),
                    child: _buildEventCards(events),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _fetchData(
      ValueNotifier<List<dynamic>> eventsNotifier,
      ValueNotifier<bool> isLoadingNotifier,
      ValueNotifier<String?> errorMessageNotifier) async {
    try {
      isLoadingNotifier.value = true; // Set loading to true when fetching data
      Response<dynamic> res = await APIService.instance.request(
        '/events/list?offset=0&limit=10',
        DioMethod.get,
      );
      List<dynamic> fetchedEvents = res.data['items'] ?? [];
      // Update the ValueNotifier with the fetched events
      eventsNotifier.value = fetchedEvents;
    } catch (e) {
      errorMessageNotifier.value = e.toString();
    } finally {
      isLoadingNotifier.value = false; // Set loading to false in the end
    }
  }

  Widget _buildEventCards(List<dynamic> events) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: events.length,
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
        final event = events[index];
        return EventCard(
          clubSlug: event['club']?['slug'] ?? '',
          orgImage: event['club']?['logo']?['thumbnail'] ?? '',
          title: event['name'] ?? 'No Title',
          organizer: event['club']?['name'] ?? 'Unknown Organizer',
          tags: [
            event['category']?['name'] ?? '',
            event['is_online'] == true ? 'Online' : 'Offline',
            event['has_fee'] == true ? 'Paid' : 'Free',
            '${event['duration']} Hours'
          ],
          onTap: () {
            // Handle tap event here.
          },
          imageUrl:
              event['poster']?['medium'] ?? 'https://via.placeholder.com/150',
          eventId: event['id'],
          clubId: event['club']['id'],
        );
      },
    );
  }
}