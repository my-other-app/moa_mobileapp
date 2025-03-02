import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:myotherapp/core/api/api_helper.dart';
import 'package:myotherapp/modules/home/custom_widgets/event_card.dart';
import 'package:myotherapp/modules/home/pages/clubs_page/no_notes_page.dart';

class PastEventsPage extends StatefulWidget {
  const PastEventsPage({super.key});

  @override
  State<PastEventsPage> createState() => _PastEventsPageState();
}

class _PastEventsPageState extends State<PastEventsPage> {
  List<dynamic> events = [];
  bool isLoading = true;
  String? errorMessage;

  Future<void> _fetchData() async {
    try {
      Response<dynamic> res = await APIService.instance.request(
        '/events/list?is_registered=true&is_ended=true&offset=0&limit=10',
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
          clubSlug: event['club']?['slug'] ?? '',
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (errorMessage != null) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: Text('Error: $errorMessage')),
      );
    }
    if (events.isEmpty) {
      return NoNotesPage();
    }
    return Scaffold(
      backgroundColor: Colors.white,
      body: _buildEventCards(),
    );
  }
}
