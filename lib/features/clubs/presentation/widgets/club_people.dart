import 'package:flutter/material.dart';
import 'package:finnet/common/models/events/event_page_model.dart'
    show PersonLink, PersonLinkKind;
import 'package:finnet/features/clubs/data/models/club_info.dart';
import 'package:finnet/shared/widgets/app_network_image.dart';
import 'package:finnet/shared/widgets/detail_sheet.dart';
import 'package:finnet/shared/widgets/pressable.dart';

const _ink = Color(0xFF1E1E1E);
const _edge = Color(0xFFE2E2E2);
const _muted = Color(0xFF6B7280);

/// A section's heading on the club page: the title and, when there is one,
/// a line under it.
class ClubSectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;

  const ClubSectionTitle({super.key, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 24,
                fontFamily: 'BebasNeue',
                color: _ink,
              ),
            ),
          ),
          if (subtitle != null)
            Text(
              subtitle!,
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
        borderRadius: circle ? null : BorderRadius.circular(size * 0.16),
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

/// A person's round photo, over their initials while it loads and if it
/// never does.
class _Face extends StatelessWidget {
  final ClubTeamMember person;
  final double size;

  const _Face({required this.person, required this.size});

  @override
  Widget build(BuildContext context) {
    final initials = InitialsTile(name: person.name, size: size);
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: AppNetworkImage(
          url: person.photoUrl,
          width: size,
          height: size,
          placeholder: (_) => initials,
          errorWidget: (_) => initials,
        ),
      ),
    );
  }
}

/// A partner's logo, whole: [height] tall and as wide as it is, up to
/// [maxWidth] -- many are wordmarks, far wider than tall. Their initials
/// without one.
class _Logo extends StatelessWidget {
  final ClubPartner partner;
  final double height;
  final double maxWidth;

  const _Logo({
    required this.partner,
    required this.height,
    required this.maxWidth,
  });

  @override
  Widget build(BuildContext context) {
    final initials =
        InitialsTile(name: partner.name, size: height, circle: false);
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: height),
      child: AppNetworkImage(
        url: partner.logoUrl,
        height: height,
        fit: BoxFit.contain,
        placeholder: (_) => initials,
        errorWidget: (_) => initials,
      ),
    );
  }
}

/// A card that opens a sheet: the whole card is the tap, and one button to
/// a screen reader ([label], and what a tap does); pressed in under a
/// finger.
class _OpeningCard extends StatelessWidget {
  final String label;
  final String name;
  final VoidCallback onOpen;
  final Widget child;

  const _OpeningCard({
    super.key,
    required this.label,
    required this.name,
    required this.onOpen,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      hint: 'Shows more about $name',
      onTap: onOpen,
      excludeSemantics: true,
      child: Pressable(
        child: Material(
          color: Colors.white,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: _edge),
          ),
          child: InkWell(onTap: onOpen, child: child),
        ),
      ),
    );
  }
}

PersonLinkKind _kindOf(String kind) => switch (kind) {
      'instagram' => PersonLinkKind.instagram,
      'linkedin' => PersonLinkKind.linkedin,
      'x' => PersonLinkKind.x,
      'youtube' => PersonLinkKind.youtube,
      _ => PersonLinkKind.website,
    };

/// [url] as a link for a sheet, or null when it will not parse.
PersonLink? _link(String kind, String url) {
  final uri = Uri.tryParse(url);
  return uri == null ? null : PersonLink(_kindOf(kind), uri);
}

/// One of the club's team, in the event page's sheet: their photo, name,
/// role and links (and their bio, once the club can write one).
Future<void> showClubMemberSheet(
  BuildContext context, {
  required ClubTeamMember person,
  required String clubName,
}) {
  return showDetailSheet(
    context,
    DetailSheet(
      key: const ValueKey('club-member-sheet'),
      picture: _Face(person: person, size: 88),
      name: person.name,
      role: person.role.isEmpty ? null : person.role,
      note: '$clubName team',
      body: person.bio,
      links: [
        for (final (kind, url) in person.links)
          if (_link(kind, url) case final link?) link,
      ],
    ),
  );
}

/// One of the club's partners, in the same sheet: their logo, name, what
/// they do for the club and since when (and their website and a word about
/// them, once the club can give those).
Future<void> showClubPartnerSheet(
  BuildContext context, {
  required ClubPartner partner,
  required String clubName,
}) {
  final website = partner.website;
  return showDetailSheet(
    context,
    DetailSheet(
      key: const ValueKey('club-partner-sheet'),
      picture: _Logo(partner: partner, height: 88, maxWidth: 240),
      name: partner.name,
      role: partner.role.isEmpty ? null : partner.role,
      note: partner.since == null
          ? 'Partner of $clubName'
          : 'Partner of $clubName since ${partner.since}',
      body: partner.description,
      links: [
        if (website != null)
          if (_link('website', website) case final link?) link,
      ],
    ),
  );
}

/// "Team": the people behind the club. A card each -- photo, name, role --
/// that opens their sheet on a tap, as the event page's people do.
class ClubTeamSection extends StatelessWidget {
  final String clubName;
  final List<ClubTeamMember> team;

  const ClubTeamSection({
    super.key,
    required this.clubName,
    required this.team,
  });

  @override
  Widget build(BuildContext context) {
    // Tall enough for a two-line name and role at the phone's text size.
    final height = 117 + MediaQuery.textScalerOf(context).scale(70);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClubSectionTitle(
          title: 'TEAM',
          subtitle: 'The people behind $clubName',
        ),
        SizedBox(
          height: height,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: team.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final person = team[index];
              return _OpeningCard(
                key: ValueKey('club-member-$index'),
                name: person.name,
                label: [person.name, if (person.role.isNotEmpty) person.role]
                    .join(', '),
                onOpen: () => showClubMemberSheet(context,
                    person: person, clubName: clubName),
                child: _MemberCard(person: person),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MemberCard extends StatelessWidget {
  final ClubTeamMember person;

  const _MemberCard({required this.person});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 148,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 18, 12, 14),
        child: Column(
          children: [
            _Face(person: person, size: 72),
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
                height: 1.25,
              ),
            ),
            if (person.role.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                person.role,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 12, color: _muted, height: 1.3),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// "Partners": who backs the club, two to a row: the logo, the name, what
/// they do for it. Each opens its sheet.
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
            // Every tile the same height, so the rows line up: room for a
            // two-line name and a two-line role at the phone's text size.
            final height = 101 + MediaQuery.textScalerOf(context).scale(70);
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final (index, partner) in partners.indexed)
                  SizedBox(
                    width: width,
                    height: height,
                    child: _OpeningCard(
                      key: ValueKey('club-partner-$index'),
                      name: partner.name,
                      label: [
                        partner.name,
                        if (partner.role.isNotEmpty) partner.role,
                      ].join(', '),
                      onOpen: () => showClubPartnerSheet(context,
                          partner: partner, clubName: clubName),
                      child: _PartnerTile(partner: partner),
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

  const _PartnerTile({required this.partner});

  @override
  Widget build(BuildContext context) {
    final detail = [
      if (partner.role.isNotEmpty) partner.role,
      if (partner.since != null) 'Since ${partner.since}',
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 14),
      child: Column(
        children: [
          SizedBox(
            height: 56,
            child: Center(
              child: LayoutBuilder(
                builder: (context, constraints) => _Logo(
                  partner: partner,
                  height: 56,
                  maxWidth: constraints.maxWidth,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            partner.name,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _ink,
              height: 1.25,
            ),
          ),
          if (detail.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              detail,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: _muted, height: 1.3),
            ),
          ],
        ],
      ),
    );
  }
}
