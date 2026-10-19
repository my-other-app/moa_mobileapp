import 'package:flutter/material.dart';
import 'package:finnet/features/clubs/data/models/club_info.dart';
import 'package:finnet/shared/widgets/app_network_image.dart';

/// A section's heading on the club page: the title and one line under it.
class ClubSectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const ClubSectionTitle(
      {super.key, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 24,
              fontFamily: 'BebasNeue',
              color: Color(0xFF1E1E1E),
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

/// Initials on a colour that is always the same for the same name: a face
/// for someone without a photo, a logo for a partner without one.
class InitialsTile extends StatelessWidget {
  final String name;
  final double size;
  final bool circle;

  const InitialsTile({
    super.key,
    required this.name,
    required this.size,
    this.circle = true,
  });

  static const _palette = [
    (Color(0xFFE1C9FF), Color(0xFF4B2A7B)),
    (Color(0xFFB8DFF2), Color(0xFF0F4C68)),
    (Color(0xFFF9FFA1), Color(0xFF5B5A12)),
    (Color(0xFFFFDEDD), Color(0xFF7A2724)),
    (Color(0xFFB4E5BC), Color(0xFF155C2A)),
  ];

  static String initialsOf(String name) {
    final words =
        name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return '?';
    final first = words.first.characters.first;
    final last = words.length > 1 ? words.last.characters.first : '';
    return (first + last).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final (bg, ink) = _palette[
        name.codeUnits.fold<int>(0, (a, b) => a + b) % _palette.length];
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : BorderRadius.circular(8),
      ),
      child: Text(
        initialsOf(name),
        style: TextStyle(
          fontSize: size * 0.34,
          fontWeight: FontWeight.w700,
          color: ink,
        ),
      ),
    );
  }
}

/// "Team": the people behind the club, each with their role and only the
/// links they gave that are safe to follow.
class ClubTeamSection extends StatelessWidget {
  final String clubName;
  final List<ClubTeamMember> team;

  /// Open one of a person's links.
  final ValueChanged<String> onOpen;

  const ClubTeamSection({
    super.key,
    required this.clubName,
    required this.team,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClubSectionTitle(
          title: 'TEAM',
          subtitle: 'The people behind $clubName',
        ),
        SizedBox(
          height: 196,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: team.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) => _MemberCard(
              key: ValueKey('club-member-$index'),
              person: team[index],
              onOpen: onOpen,
            ),
          ),
        ),
      ],
    );
  }
}

class _MemberCard extends StatelessWidget {
  final ClubTeamMember person;
  final ValueChanged<String> onOpen;

  const _MemberCard({super.key, required this.person, required this.onOpen});

  static const _ink = Color(0xFF1E1E1E);

  @override
  Widget build(BuildContext context) {
    const size = 64.0;
    final face = InitialsTile(name: person.name, size: size);
    return Container(
      width: 140,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E2E2)),
      ),
      child: Column(
        children: [
          ClipOval(
            child: SizedBox(
              width: size,
              height: size,
              child: AppNetworkImage(
                url: person.photoUrl,
                width: size,
                height: size,
                placeholder: (_) => face,
                errorWidget: (_) => face,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            person.name,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
          if (person.role.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              person.role,
              maxLines: 1,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
          ],
          const Spacer(),
          if (person.links.isNotEmpty)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final (kind, url) in person.links)
                  _PersonLink(
                    kind: kind,
                    name: person.name,
                    onTap: () => onOpen(url),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _PersonLink extends StatelessWidget {
  final String kind;
  final String name;
  final VoidCallback onTap;

  const _PersonLink({
    required this.kind,
    required this.name,
    required this.onTap,
  });

  static const _labels = {
    'instagram': 'Instagram',
    'linkedin': 'LinkedIn',
    'x': 'X',
    'website': 'Website',
  };

  static const _assets = {
    'instagram': 'assets/images/Instagram.png',
    'linkedin': 'assets/images/LinkedIn.png',
    'website': 'assets/images/Website.png',
  };

  @override
  Widget build(BuildContext context) {
    final asset = _assets[kind];
    return Semantics(
      button: true,
      label: '$name on ${_labels[kind] ?? kind}',
      excludeSemantics: true,
      child: InkWell(
        key: ValueKey('member-link-$kind'),
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          // The padding is the tap target.
          padding: const EdgeInsets.all(6),
          child: SizedBox(
            width: 20,
            height: 20,
            child: asset != null
                ? Image.asset(asset, fit: BoxFit.contain)
                : const Center(
                    child: Text(
                      'X',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: Color(0xFF1E1E1E),
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// "Partners": who backs the club, logo first, with what they do for it.
class ClubPartnersSection extends StatelessWidget {
  final String clubName;
  final List<ClubPartner> partners;

  const ClubPartnersSection({
    super.key,
    required this.clubName,
    required this.partners,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClubSectionTitle(
          title: 'PARTNERS',
          subtitle: 'Who backs $clubName',
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            const gap = 12.0;
            final width = (constraints.maxWidth - gap) / 2;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final (index, partner) in partners.indexed)
                  SizedBox(
                    width: width,
                    child: _PartnerTile(
                      key: ValueKey('club-partner-$index'),
                      partner: partner,
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _PartnerTile extends StatelessWidget {
  final ClubPartner partner;

  const _PartnerTile({super.key, required this.partner});

  @override
  Widget build(BuildContext context) {
    final fallback = InitialsTile(name: partner.name, size: 56, circle: false);
    final detail = [
      if (partner.role.isNotEmpty) partner.role,
      if (partner.since != null) 'Since ${partner.since}',
    ].join(' · ');
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E2E2)),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 56,
            child: AppNetworkImage(
              url: partner.logoUrl,
              height: 56,
              fit: BoxFit.contain,
              placeholder: (_) => fallback,
              errorWidget: (_) => fallback,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            partner.name,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E1E1E),
            ),
          ),
          if (detail.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              detail,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
          ],
        ],
      ),
    );
  }
}
