// Answers from `/discover/*` as the backend's schemas have them
// (`app/api/discover/schemas.py`), cut down.

Map<String, dynamic> eventCard(
  int id, {
  String? name,
  String startsAt = '2030-10-24T12:30:00Z',
  bool online = false,
  bool hasFee = false,
  num? fee,
  String status = 'upcoming',
  num? distanceKm,
  int going = 0,
}) =>
    {
      'id': id,
      'name': name ?? 'Event $id',
      'slug': 'event-$id',
      'poster': null,
      'starts_at': startsAt,
      'ends_at': '2030-10-24T15:30:00Z',
      'location_name': online ? null : 'Technopark, Thiruvananthapuram',
      'is_online': online,
      'lat': online ? null : 8.55,
      'lng': online ? null : 76.88,
      'distance_km': distanceKm,
      'has_fee': hasFee,
      'fee': fee,
      'category': {'id': 2, 'name': 'Workshop'},
      'club': {
        'id': 3,
        'name': 'Tinkerhub',
        'slug': 'tinkerhub',
        'logo': null,
      },
      'going': going,
      'capacity': 100,
      'status': status,
      'url': 'https://myotherapp.in/events/event-$id',
      'summary': 'A hands-on evening.',
      'topics': [
        {
          'id': 2,
          'slug': 'development',
          'name': 'Development',
          'color': '#2563EB'
        },
      ],
    };

Map<String, dynamic> clubCard(int id, {String? name, num? distanceKm}) => {
      'id': id,
      'name': name ?? 'Club $id',
      'slug': 'club-$id',
      'logo': null,
      'cover': null,
      'tagline': 'We build things',
      'location_name': 'Kochi',
      'followers': 1200,
      'upcoming_events': 2,
      'interests': ['Coding', 'Robotics', 'Music', 'Film'],
      'distance_km': distanceKm,
      'website_url': null,
      'topics': [],
    };

Map<String, dynamic> threadOut(String id,
        {String body = 'Hello from the club'}) =>
    {
      'id': id,
      'club': {'id': 3, 'name': 'Tinkerhub', 'slug': 'tinkerhub', 'logo': null},
      'body': body,
      'image': null,
      'kind': 'post',
      'poll': null,
      'pinned': false,
      'notify_followers': false,
      'likes': 4,
      'comments': 1,
      'views': 20,
      'liked': false,
      'created_at': '2026-10-18T10:00:00Z',
    };

const whereTvm = {
  'city': 'Thiruvananthapuram',
  'region': 'Kerala',
  'lat': 8.52,
  'lng': 76.94,
  'source': 'ip',
};

const whereNowhere = {
  'city': null,
  'region': null,
  'lat': null,
  'lng': null,
  'source': 'none',
};

Map<String, dynamic> homeBody({
  Map<String, dynamic> where = whereTvm,
  List<Map<String, dynamic>>? near,
  List<Map<String, dynamic>>? thisWeek,
  List<Map<String, dynamic>>? online,
  List<Map<String, dynamic>>? popular,
  List<Map<String, dynamic>>? clubs,
  List<Map<String, dynamic>>? clubsMore,
  List<Map<String, dynamic>>? threads,
}) =>
    {
      'where': where,
      'near': near ?? [eventCard(1, name: 'Hack Night', distanceKm: 3.2)],
      'this_week': thisWeek ?? [eventCard(2, name: 'Design Jam')],
      'online': online ?? [eventCard(3, name: 'Rust Webinar', online: true)],
      'popular': popular ?? [eventCard(4, name: 'Big Fest', going: 340)],
      'categories': [
        {'id': 2, 'name': 'Workshop', 'icon': null, 'upcoming': 9},
      ],
      'clubs': clubs ?? [clubCard(5, name: 'Tinkerhub', distanceKm: 2.1)],
      // Only from a server that sends it.
      if (clubsMore != null) 'clubs_more': clubsMore,
      'threads': threads ?? [threadOut('t-1')],
      'stats': {'upcoming_events': 40, 'clubs': 12, 'cities': 3},
    };

Map<String, dynamic> emptyHomeBody() => homeBody(
      where: whereNowhere,
      near: const [],
      thisWeek: const [],
      online: const [],
      popular: const [],
      clubs: const [],
      threads: const [],
    );

Map<String, dynamic> eventsPage(
  List<Map<String, dynamic>> items, {
  int? total,
  String? nextCursor,
  bool cursored = true,
  bool capped = false,
  int offset = 0,
  Map<String, dynamic> where = whereTvm,
}) =>
    {
      'items': items,
      'total': total ?? items.length,
      'total_capped': capped,
      'offset': offset,
      'limit': 20,
      'where': where,
      'categories': [
        {'id': 2, 'name': 'Workshop', 'upcoming': 9},
        {'id': 5, 'name': 'Talk', 'upcoming': 4},
      ],
      'topics': [
        {
          'id': 2,
          'slug': 'development',
          'name': 'Development',
          'color': '#2563EB',
          'upcoming': 12
        },
        {
          'id': 4,
          'slug': 'arts',
          'name': 'Arts',
          'color': '#EA580C',
          'upcoming': 3
        },
      ],
      if (cursored) 'next_cursor': nextCursor,
    };

Map<String, dynamic> clubsPage(
  List<Map<String, dynamic>> items, {
  int? total,
  String? nextCursor,
  Map<String, dynamic> where = whereTvm,
}) =>
    {
      'items': items,
      'total': total ?? items.length,
      'total_capped': false,
      'offset': 0,
      'limit': 20,
      'where': where,
      'interests': [
        {'id': 6, 'name': 'Coding', 'clubs': 7},
        {'id': 15, 'name': 'Photography', 'clubs': 2},
      ],
      'next_cursor': nextCursor,
    };

Map<String, dynamic> threadsPage(List<Map<String, dynamic>> items,
        {String? nextCursor}) =>
    {
      'items': items,
      'total': items.length,
      'limit': 20,
      'offset': 0,
      'total_capped': false,
      'next_cursor': nextCursor,
    };

/// `/interests/topics/{slug}`.
const developmentTopicBody = {
  'id': 2,
  'slug': 'development',
  'name': 'Development',
  'icon': '💻',
  'icon_type': 'emoji',
  'color': '#2563EB',
  'description': 'Build software',
  'upcoming_events': 12,
  'clubs': 30,
  'interests': [
    {
      'id': 3,
      'slug': 'web-development',
      'name': 'Web Development',
      'upcoming_events': 4
    },
    {'id': 6, 'slug': 'coding', 'name': 'Coding', 'upcoming_events': 8},
  ],
};
