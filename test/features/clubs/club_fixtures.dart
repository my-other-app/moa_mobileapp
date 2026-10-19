/// A club as the two endpoints describe it, shaped like production's
/// answers (`clubs/schemas.py` ClubPublicDetailResponse, `discover/schemas.py`
/// ClubPage).
///
/// Pictures are given as [picture] URLs: real https addresses for the model
/// tests, or paths the image widget never fetches for the widget tests.
library;

Map<String, dynamic> clubInfoJson({
  String picture = 'https://media.myotherapp.in',
  bool following = false,
  List<Map<String, dynamic>>? team,
  List<Map<String, dynamic>>? partners,
}) =>
    {
      'id': 12,
      'name': 'Robotics Club',
      'slug': 'robotics-club',
      'logo': {
        'thumbnail': '$picture/logo-t.png',
        'original': '$picture/logo.png',
      },
      'cover': {
        'thumbnail': '$picture/cover-t.jpg',
        'medium': '$picture/cover-m.jpg',
        'large': '$picture/cover-l.jpg',
        'original': '$picture/cover.jpg',
      },
      'tagline': '  We build robots that play football.  ',
      'location_name': 'CET, Trivandrum',
      'location_link': 'https://maps.example/cet',
      'about': 'Robots, every weekend.',
      'rating': 4.5,
      'total_ratings': 20,
      'total_events': 9,
      'socials': {
        'instagram': 'https://instagram.com/robotics',
        'linkedin': null,
        'youtube': null,
        'website': 'robotics.example.org',
      },
      'interests': [
        {'id': 3, 'name': 'Robotics', 'category_id': 2},
      ],
      'followers_count': 120,
      'contact_phone': '+911234567890',
      'contact_email': 'hello@robotics.example.org',
      'user_data': {'is_following': following, 'is_pinned': false},
      'org': {
        'id': 1,
        'name': 'CET',
        'type': 'college',
        'address': 'Trivandrum',
      },
      'team': team ??
          [
            {
              'id': 2,
              'name': 'Rahul Nair',
              'role': 'Design lead',
              'sort_order': 2,
              'instagram': 'javascript:alert(1)',
              'linkedin': 'linkedin.com/in/rahul',
              'x': null,
              'website': null,
              'photo': null,
            },
            {
              'id': 1,
              'name': 'Asha Menon',
              'role': 'President',
              'sort_order': 1,
              'instagram': 'https://instagram.com/asha',
              'linkedin': null,
              'x': 'https://x.com/asha',
              'website': 'https://asha.dev',
              'photo': {
                'thumbnail': '$picture/asha-t.jpg',
                'medium': '$picture/asha-m.jpg',
              },
            },
          ],
      'partners': partners ??
          [
            {
              'id': 5,
              'name': 'Acme Robotics',
              'role': 'Title sponsor',
              'since': 2022,
              'sort_order': 0,
              'logo': {'medium': '$picture/acme-m.png'},
            },
            {
              'id': 6,
              'name': 'Maker Space',
              'role': null,
              'since': null,
              'sort_order': 1,
              'logo': null,
            },
          ],
    };

Map<String, dynamic> clubPublicJson({
  String picture = 'https://media.myotherapp.in',
  String? websiteUrl = 'https://robotics-club.myotherapp.in',
}) =>
    {
      'club': {
        'id': 12,
        'name': 'Robotics Club',
        'slug': 'robotics-club',
        'logo': '$picture/logo-t.png',
        'cover': '$picture/cover.jpg',
        'tagline': 'We build robots that play football.',
        'location_name': 'CET, Trivandrum',
        'followers': 120,
        'upcoming_events': 2,
        'interests': ['Robotics', 'Electronics'],
        'distance_km': null,
        'website_url': websiteUrl,
        'topics': [
          {'id': 2, 'slug': 'development', 'name': 'Development'},
        ],
        'about': 'Robots, every weekend.',
        'contact_email': 'hello@robotics.example.org',
        'socials': {
          'instagram': 'https://instagram.com/robotics',
          'linkedin': null,
          'youtube': null,
          'website': null,
        },
        'events_held': 9,
      },
      'upcoming': [],
      'past': [],
      'threads': [],
      'team': [
        {
          'name': 'Asha Menon',
          'role': 'President',
          'photo': '$picture/asha-m.jpg',
          'links': {
            'instagram': 'https://instagram.com/asha',
            'linkedin': null,
            'x': 'https://x.com/asha',
            'website': null,
          },
        },
      ],
      'partners': [
        {
          'name': 'Acme Robotics',
          'role': 'Title sponsor',
          'logo': '$picture/acme-m.png',
        },
      ],
    };
