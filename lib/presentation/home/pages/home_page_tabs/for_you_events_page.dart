import 'package:flutter/material.dart';
import 'package:myotherapp/presentation/home/widget/event_card.dart';
import 'package:myotherapp/presentation/home/widget/note_card.dart';

class ForYouEventsPage extends StatelessWidget {
  const ForYouEventsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: ListView(
        padding: const EdgeInsets.all(8),
        children: <Widget>[
          EventCard(
            title: 'Blender free 2 day',
            organizer: 'IEDC CET',
            tags: ['Workshop', 'Online', 'Paid', '2 Hours'],
            onTap: () {},
            imageUrl:
                'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcQpZUOgLnH_wGkFZoKfK7qY7DVdisgM5v7cJg&s',
          ),
          SizedBox(
            height: 10,
          ),
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
            tags: ['Workshop', 'Online', 'Paid', '2 Hours'],
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
            tags: ['Workshop', 'Online', 'Paid', '2 Hours'],
            onTap: () {},
            imageUrl:
                'https://fastly.picsum.photos/id/288/536/354.jpg?hmac=0_DALLGv6guhuEVpDdbFjlA-yvbIhMjnl1YhHtfhW10',
          ),
          EventCard(
            title: 'Blender free 2 day',
            organizer: 'IEDC CET',
            tags: ['Workshop', 'Online', 'Paid', '2 Hours'],
            onTap: () {},
            imageUrl:
                'https://fastly.picsum.photos/id/288/536/354.jpg?hmac=0_DALLGv6guhuEVpDdbFjlA-yvbIhMjnl1YhHtfhW10',
          ),
        ],
      ),
    );
  }
}
