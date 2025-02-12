import 'package:flutter/material.dart';

import '../../widget/event_card.dart';
import '../../widget/note_card.dart';

class FollowingEventsPage extends StatelessWidget {
  const FollowingEventsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: ListView(
        padding: const EdgeInsets.all(8),
        children: <Widget>[
          NoteCard(
            logoUrl:
                'https://fastly.picsum.photos/id/288/536/354.jpg?hmac=0_DALLGv6guhuEVpDdbFjlA-yvbIhMjnl1YhHtfhW10',
            headerTitle: 'Tinkerhub HQ',
            headerSubtitle: '2 days ago',
            cardTitle: 'Another TinkerHub Card',
            description:
                'A longer description shows how the card automatically grows '
                'as the content increases.',
          ),
          SizedBox(
            height: 10,
          ),
          EventCard(
            title: 'Blender free 2 day',
            organizer: 'IEDC CET',
            tags: ['workshop', 'online', 'paid', '2 hours'],
            onTap: () {},
            imageUrl:
                'https://fastly.picsum.photos/id/288/536/354.jpg?hmac=0_DALLGv6guhuEVpDdbFjlA-yvbIhMjnl1YhHtfhW10',
          ),
          SizedBox(
            height: 10,
          ),
          EventCard(
            title: 'Blender free 2 day',
            organizer: 'IEDC CET',
            tags: ['workshop', 'online', 'paid', '2 hours'],
            onTap: () {},
            imageUrl:
                'https://fastly.picsum.photos/id/288/536/354.jpg?hmac=0_DALLGv6guhuEVpDdbFjlA-yvbIhMjnl1YhHtfhW10',
          ),
          EventCard(
            title: 'Blender free 2 day',
            organizer: 'IEDC CET',
            tags: ['workshop', 'online', 'paid', '2 hours'],
            onTap: () {},
            imageUrl:
                'https://fastly.picsum.photos/id/288/536/354.jpg?hmac=0_DALLGv6guhuEVpDdbFjlA-yvbIhMjnl1YhHtfhW10',
          ),
        ],
      ),
    );
  }
}
