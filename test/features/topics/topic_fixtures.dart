import 'package:finnet/features/profile/domain/entities/profile_entity.dart';
import 'package:finnet/features/topics/domain/entities/topic.dart';

/// `/interests/list` as production answers before the topics migration: one
/// category, "arts", holding everything -- no slug, colour or order.
const productionListBody = [
  {
    'id': 1,
    'name': 'arts',
    'icon': null,
    'icon_type': null,
    'interests': [
      {'id': 6, 'name': 'Coding', 'icon': '💻', 'icon_type': 'emoji'},
      {'id': 7, 'name': 'UI/UX', 'icon': '🎨', 'icon_type': 'emoji'},
      {'id': 15, 'name': 'Photography', 'icon': '📸', 'icon_type': 'emoji'},
      {'id': 16, 'name': 'Music', 'icon': '🎵', 'icon_type': 'emoji'},
    ],
  },
];

/// `/interests/list` as the contract has it, deliberately out of order.
const contractListBody = [
  {
    'id': 4,
    'slug': 'arts',
    'name': 'Arts',
    'icon': '🎭',
    'icon_type': 'emoji',
    'color': '#EA580C',
    'description': 'Make things',
    'sort_order': 4,
    'interests': [
      {
        'id': 16,
        'slug': 'music',
        'name': 'Music',
        'icon': '🎵',
        'icon_type': 'emoji',
        'category_id': 4,
        'sort_order': 2,
      },
      {
        'id': 15,
        'slug': 'photography',
        'name': 'Photography',
        'icon': '📸',
        'icon_type': 'emoji',
        'category_id': 4,
        'sort_order': 1,
      },
    ],
  },
  {
    'id': 2,
    'slug': 'development',
    'name': 'Development',
    'icon': '💻',
    'icon_type': 'emoji',
    'color': '#2563EB',
    'description': 'Build software',
    'sort_order': 1,
    'interests': [
      {
        'id': 3,
        'slug': 'web-development',
        'name': 'Web Development',
        'icon': null,
        'icon_type': null,
        'category_id': 2,
        'sort_order': 1,
      },
      {
        'id': 6,
        'slug': 'coding',
        'name': 'Coding',
        'icon': '💻',
        'icon_type': 'emoji',
        'category_id': 2,
        'sort_order': 2,
      },
    ],
  },
  {
    'id': 9,
    'slug': 'community',
    'name': 'Community',
    'color': '#0D9488',
    'sort_order': 7,
    'interests': [],
  },
];

/// `/interests/topics` as the contract has it.
const contractTopicsBody = [
  {
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
        'upcoming_events': 4,
      },
      {'id': 6, 'slug': 'coding', 'name': 'Coding', 'upcoming_events': 8},
    ],
  },
  {
    'id': 4,
    'slug': 'arts',
    'name': 'Arts',
    'color': '#EA580C',
    'upcoming_events': 3,
    'clubs': 5,
    'interests': [
      {'id': 15, 'slug': 'photography', 'name': 'Photography'},
    ],
  },
];

const development = Topic(
  id: 2,
  slug: 'development',
  name: 'Development',
  icon: '💻',
  iconType: 'emoji',
  color: '#2563EB',
  sortOrder: 1,
  interests: [
    Interest(id: 3, name: 'Web Development', categoryId: 2),
    Interest(id: 6, name: 'Coding', icon: '💻', categoryId: 2),
    Interest(id: 13, name: 'Cybersecurity', categoryId: 2),
  ],
);

const deepTech = Topic(
  id: 3,
  slug: 'deep-tech',
  name: 'Deep Tech',
  color: '#7C3AED',
  sortOrder: 2,
  interests: [
    Interest(id: 2, name: 'Artificial Intelligence', categoryId: 3),
    Interest(id: 22, name: 'Blockchain', categoryId: 3),
  ],
);

const arts = Topic(
  id: 4,
  slug: 'arts',
  name: 'Arts',
  color: '#EA580C',
  sortOrder: 4,
  interests: [
    Interest(id: 15, name: 'Photography', categoryId: 4),
    Interest(id: 16, name: 'Music', categoryId: 4),
    Interest(id: 17, name: 'Film', categoryId: 4),
  ],
);

/// The contract's tree, cut down.
const catalogue = [development, deepTech, arts];

/// Production before the migration: everything under "arts".
const productionCatalogue = [
  Topic(
    id: 1,
    slug: 'arts',
    name: 'arts',
    interests: [
      Interest(id: 6, name: 'Coding', icon: '💻', categoryId: 1),
      Interest(id: 7, name: 'UI/UX', icon: '🎨', categoryId: 1),
      Interest(id: 15, name: 'Photography', icon: '📸', categoryId: 1),
      Interest(id: 16, name: 'Music', icon: '🎵', categoryId: 1),
    ],
  ),
];
