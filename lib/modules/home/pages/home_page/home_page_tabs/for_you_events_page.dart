import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:myotherapp/core/api/api_helper.dart';
import 'package:myotherapp/modules/home/custom_widgets/event_card.dart';

class ForYouEventsPage extends StatefulWidget {
  const ForYouEventsPage({super.key});

  @override
  State<ForYouEventsPage> createState() => _ForYouEventsPageState();
}

class _ForYouEventsPageState extends State<ForYouEventsPage> {
  List<dynamic> events = [];
  bool isLoading = true;
  String? errorMessage;

  Future<void> _fetchData() async {
    try {
      Response<dynamic> res = await APIService.instance.request(
        '/events/list?offset=0&limit=10',
        DioMethod.get,
      );
      setState(() {
        events = res.data['items'] ?? [];
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Widget _buildEventCards() {
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

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
          child: CircularProgressIndicator(
        backgroundColor: Colors.white,
      ));
    }
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
      body: _buildEventCards(),
    );
  }
}
