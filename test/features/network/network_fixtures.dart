/// Feature 4's answers, as the contract shapes them
/// (feature-register `profiles-networking-contract.md`).
library;

Map<String, dynamic> publicProfileJson({
  String handle = 'ananya',
  String name = 'Ananya Iyer',
  int userId = 42,
  bool private = false,
  bool isMe = false,
  Map<String, dynamic>? relation,
  List<String> hidden = const [],
  String? email,
  String? phone,
  List<Map<String, dynamic>>? links,
  List<Map<String, dynamic>>? projects,
}) =>
    {
      'handle': handle,
      'user_id': userId,
      'full_name': name,
      'picture': null,
      'headline': 'Flutter dev · CET \'27',
      'bio': 'I build apps for clubs.',
      'city': 'Kochi',
      'org': {'id': 3, 'name': 'CET Trivandrum'},
      'interests': [
        {'id': 1, 'name': 'Flutter', 'emoji': '💙'},
      ],
      'links': links ??
          [
            {'type': 'github', 'url': 'https://github.com/ananya', 'label': null},
            {'type': 'website', 'url': 'ananya.dev', 'label': 'My blog'},
            {'type': 'other', 'url': 'javascript:alert(1)'},
          ],
      'projects': projects ??
          [
            {
              'id': 7,
              'title': 'Club app',
              'summary': 'Tickets for 40 clubs',
              'url': 'https://github.com/ananya/club-app',
              'image': {'medium': 'https://media.myotherapp.in/p/7.jpg'},
              'tags': ['flutter', 'firebase'],
              'role': 'Lead',
              'month': '2026-08-01',
            },
          ],
      'achievements': {
        'events_attended': 12,
        'certificates': [
          {'event_name': 'DevFest', 'url': 'https://myotherapp.in/certificates/ab'},
        ],
        'talks': [
          {'event_name': 'Hack Night', 'title': 'State in Flutter', 'event_slug': 'hack-night'},
        ],
        'clubs': null,
      },
      'contact': {'email': email, 'phone': phone},
      'hidden_sections': hidden,
      'private': private,
      'indexable': false,
      'is_me': isMe,
      'relation': relation,
    };

Map<String, dynamic> myProfileJson({
  String handle = 'asha',
  Map<String, dynamic>? settings,
  int score = 50,
  List<String> missing = const ['links', 'projects'],
  List<Map<String, dynamic>> links = const [],
  List<Map<String, dynamic>> projects = const [],
}) =>
    {
      ...publicProfileJson(
          handle: handle,
          name: 'Asha Menon',
          userId: 1,
          isMe: true,
          links: links,
          projects: projects),
      'settings': settings ??
          {
            'visibility': {
              'links': 'everyone',
              'projects': 'met',
              'achievements': 'everyone',
              'interests': 'everyone',
              'org': 'everyone',
            },
            'share_email': 'mutual',
            'share_phone': 'nobody',
            'is_private': false,
            'indexable': false,
            'notify_saves': true,
            'recap_emails': true,
            'scanning_enabled': true,
            'show_events': false,
            'show_certificates': true,
            'show_talks': true,
            'show_clubs': false,
          },
      'completeness': {'score': score, 'missing': missing},
      'email': 'asha@example.com',
      'phone': '9876543210',
    };

Map<String, dynamic> personBriefJson({
  int userId = 42,
  String handle = 'ananya',
  String name = 'Ananya Iyer',
}) =>
    {
      'user_id': userId,
      'handle': handle,
      'full_name': name,
      'picture': null,
      'headline': 'Flutter dev',
      'org_name': 'CET',
    };

Map<String, dynamic> devFest({int id = 9}) => {
      'id': id,
      'slug': 'devfest-2026',
      'name': 'DevFest',
      'starts_at': '2026-11-28T09:00:00+05:30',
    };

Map<String, dynamic> networkPersonJson({
  int id = 5,
  int userId = 42,
  String handle = 'ananya',
  String name = 'Ananya Iyer',
  bool mutual = false,
  String? note,
  List<String> tags = const [],
  bool atEvent = true,
}) =>
    {
      'id': id,
      'person': personBriefJson(userId: userId, handle: handle, name: name),
      'mutual': mutual,
      'saved_me': mutual,
      'note': note,
      'tags': tags,
      'first_met_at': '2026-11-28T10:00:00+05:30',
      'last_met_at': '2026-11-28T10:00:00+05:30',
      'encounters': [
        {
          'event': atEvent ? devFest() : null,
          'method': 'qr',
          'met_at': '2026-11-28T10:00:00+05:30',
        },
      ],
    };

Map<String, dynamic> networkListJson(List<Map<String, dynamic>> items) => {
      'items': items,
      'total': items.length,
      'events': [
        {'event': devFest(), 'count': items.length},
      ],
      'tags': [
        {'tag': 'flutter', 'count': 1},
      ],
    };

Map<String, dynamic> saveResultJson({bool created = true, bool mutual = false}) => {
      'person': networkPersonJson(mutual: mutual),
      'created': created,
      'new_encounter': true,
      'profile': publicProfileJson(
          relation: {
            'saved_by_me': true,
            'saved_me': mutual,
            'mutual': mutual,
            'network_id': 5,
          }),
    };
