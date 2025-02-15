import 'package:flutter/material.dart';
import 'package:myotherapp/presentation/home/widget/event_card.dart';
import 'package:myotherapp/presentation/home/widget/note_card.dart';

class ForYouEventsPage extends StatelessWidget {
  const ForYouEventsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.white,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          EventCard(
            title: 'Blender free 2 day',
            organizer: 'IEDC CET',
            tags: ['Workshop', 'Online', 'Paid', '2 Hours'],
            onTap: () {},
            imageUrl:
                "https://static.vecteezy.com/system/resources/previews/022/590/539/original/summer-party-poster-design-music-party-flyer-artwork-template-vector.jpg",
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20.0),
            child: Divider(
              thickness: 1,
              color: Colors.black,
              indent: 50,
              endIndent: 50,
            ),
          ),
          NoteCard(
            logoUrl:
                'https://avatars.githubusercontent.com/u/98015594?s=280&v=4',
            headerTitle: 'Tinkerhub HQ',
            headerSubtitle: '2 days ago',
            cardTitle: 'Another TinkerHub Card',
            description:
                'A longer description shows how the card automatically grows '
                'as the content increases.',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20.0),
            child: Divider(
              thickness: 1,
              color: Colors.black,
              indent: 50,
              endIndent: 50,
            ),
          ),
          EventCard(
            title: 'Blender free 2 day',
            organizer: 'IEDC CET',
            tags: ['Workshop', 'Online', 'Paid', '2 Hours'],
            onTap: () {},
            imageUrl:
                'https://fastly.picsum.photos/id/288/536/354.jpg?hmac=0_DALLGv6guhuEVpDdbFjlA-yvbIhMjnl1YhHtfhW10',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20.0),
            child: Divider(
              thickness: 1,
              color: Colors.black,
              indent: 50,
              endIndent: 50,
            ),
          ),
          EventCard(
            title: 'Blender free 2 day',
            organizer: 'IEDC CET',
            tags: ['Workshop', 'Online', 'Paid', '2 Hours'],
            onTap: () {},
            imageUrl:
                'https://fastly.picsum.photos/id/288/536/354.jpg?hmac=0_DALLGv6guhuEVpDdbFjlA-yvbIhMjnl1YhHtfhW10',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20.0),
            child: Divider(
              thickness: 1,
              color: Colors.black,
              indent: 50,
              endIndent: 50,
            ),
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
