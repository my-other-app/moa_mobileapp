import 'package:flutter/material.dart';
import 'package:myotherapp/presentation/home/widget/explore_more_club_card.dart';
import '../../widget/event_card.dart';

class PastEventsPage extends StatelessWidget {
  const PastEventsPage({super.key});

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
          SizedBox(
            height: 10,
          ),
          ExploreMoreClubCard()
        ],
      ),
    );
  }
}
