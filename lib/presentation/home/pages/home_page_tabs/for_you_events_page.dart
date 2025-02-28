import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:myotherapp/core/api/api_helper.dart';
import 'package:myotherapp/presentation/home/widget/event_card.dart';
import 'package:myotherapp/presentation/home/widget/note_card.dart';

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
      // Assuming the response contains a key "items" with an array of events.
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
        print(event['club']?['name']);
        // Map API data to your EventCard properties.
        return EventCard(
          title: event['name'] ?? 'No Title',
          organizer: event['club']?['name'] ?? 'Unknown Organizer',
          // For tags, here we add category name and other optional details.
          tags: [
            event['category']?['name'] ?? '',
            event['is_online'] == true ? 'Online' : 'Offline',
            if (event['has_fee'] == true) 'Paid' else 'Free',
            '${event['duration']} Hours'
          ],
          onTap: () {
            // Handle tap event here.
          },
          // Using the "medium" poster image as an example.
          imageUrl:
              event['poster']?['medium'] ?? 'https://via.placeholder.com/150',
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (errorMessage != null) {
      return Center(child: Text('Error: $errorMessage'));
    }
    return Scaffold(
      backgroundColor: Colors.white,
      body: _buildEventCards(),
    );
  }
}
