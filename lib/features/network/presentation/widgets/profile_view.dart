import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:finnet/core/themes/app_colors.dart';
import 'package:finnet/features/network/domain/profile.dart';
import 'package:finnet/features/topics/presentation/widgets/topic_chips.dart';
import 'package:finnet/shared/utils/external_links.dart';
import 'package:finnet/shared/widgets/app_network_image.dart';
import 'package:finnet/shared/widgets/toast.dart';

const _muted = Color(0xFF6B7280);

IconData profileLinkIcon(String type) => switch (type) {
      'linkedin' => Icons.work_outline,
      'github' => Icons.code,
      'behance' => Icons.palette_outlined,
      'dribbble' => Icons.sports_basketball_outlined,
      'medium' => Icons.article_outlined,
      'youtube' => Icons.play_circle_outline,
      'x' => Icons.alternate_email,
      'instagram' => Icons.camera_alt_outlined,
      'portfolio' => Icons.collections_outlined,
      _ => Icons.link,
    };

/// A person's picture, or their initials on grey.
class PersonAvatar extends StatelessWidget {
  const PersonAvatar({
    super.key,
    required this.picture,
    required this.initials,
    this.radius = 24,
  });

  final String? picture;
  final String initials;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final url = picture;
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFFEDEFF2),
      foregroundImage: url == null
          ? null
          : appImageProvider(url,
              privacy: ImagePrivacy.private,
              decodeWidth: decodeWidthFor(radius * 2, radius * 2,
                  MediaQuery.devicePixelRatioOf(context))),
      onForegroundImageError: url == null ? null : (_, __) {},
      child: Text(
        initials,
        style: TextStyle(
            fontSize: radius * 0.66,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF4B5563)),
      ),
    );
  }
}

/// The top of a profile: picture, name, headline, where they are from.
class ProfileHeader extends StatelessWidget {
  const ProfileHeader({super.key, required this.profile});

  final PublicProfile profile;

  @override
  Widget build(BuildContext context) {
    final where = [
      if (profile.org != null && !profile.hiddenSections.contains('org'))
        profile.org!.name,
      if (profile.city != null) profile.city!,
    ].join(' · ');
    return Column(
      children: [
        PersonAvatar(
            picture: profile.picture, initials: profile.initials, radius: 48),
        const SizedBox(height: 12),
        Text(
          profile.fullName,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        if (profile.headline != null) ...[
          const SizedBox(height: 4),
          Text(
            profile.headline!,
            key: const ValueKey('profile-headline'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, color: Color(0xFF374151)),
          ),
        ],
        if (where.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(where,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: _muted)),
        ],
        const SizedBox(height: 4),
        Text('@${profile.handle}',
            style: const TextStyle(fontSize: 13, color: _muted)),
      ],
    );
  }
}

/// Everything below the header that this viewer may see: bio, interests,
/// links, projects, what MyOtherApp vouches for, shared contact details.
class ProfileBody extends ConsumerWidget {
  const ProfileBody({super.key, required this.profile});

  final PublicProfile profile;

  static const lockedKey = ValueKey('profile-locked');
  static const hiddenKey = ValueKey('profile-hidden-sections');

  Future<void> _open(BuildContext context, WidgetRef ref, Uri uri) async {
    final opened = await ref.read(linkLauncherProvider)(uri);
    if (!opened && context.mounted) {
      showToast(context, "Couldn't open that link", icon: Icons.error_outline);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (profile.locked) {
      return Padding(
        key: lockedKey,
        padding: const EdgeInsets.only(top: 20),
        child: _Note(
          emoji: '🔒',
          text: profile.relation?.savedByMe == true
              ? "Saved. You'll see more if ${_first(profile)} saves you back."
              : '${_first(profile)} keeps their profile private. You\'ll see '
                  'more once they save you.',
        ),
      );
    }
    final achievements = profile.achievements;
    final email = profile.email;
    final phone = profile.phone;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (profile.bio != null) ...[
          const SizedBox(height: 20),
          SelectableText(profile.bio!,
              style: const TextStyle(fontSize: 15, height: 1.5)),
        ],
        if (email != null || phone != null) ...[
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (email != null)
                OutlinedButton.icon(
                  key: const ValueKey('profile-email'),
                  onPressed: () =>
                      _open(context, ref, Uri(scheme: 'mailto', path: email)),
                  icon: const Icon(Icons.mail_outline, size: 18),
                  label: Text(email),
                  style: _linkStyle,
                ),
              if (phone != null)
                OutlinedButton.icon(
                  key: const ValueKey('profile-phone'),
                  onPressed: () =>
                      _open(context, ref, Uri(scheme: 'tel', path: phone)),
                  icon: const Icon(Icons.call_outlined, size: 18),
                  label: Text(phone),
                  style: _linkStyle,
                ),
            ],
          ),
        ],
        if (profile.links.isNotEmpty) ...[
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final link in profile.links)
                OutlinedButton.icon(
                  key: ValueKey('profile-link-${link.type}-${link.uri}'),
                  onPressed: () => _open(context, ref, link.uri),
                  icon: Icon(profileLinkIcon(link.type), size: 18),
                  label: Text(link.title),
                  style: _linkStyle,
                ),
            ],
          ),
        ],
        if (profile.interests.isNotEmpty) ...[
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (i, interest) in profile.interests.indexed)
                InterestTag(
                  label: interest.name,
                  glyph: interest.emoji,
                  color: InterestTag.pastelAt(i),
                ),
            ],
          ),
        ],
        if (profile.projects.isNotEmpty) ...[
          const _Heading('PROJECTS'),
          for (final project in profile.projects)
            _ProjectCard(
              project: project,
              onOpen: project.uri == null
                  ? null
                  : () => _open(context, ref, project.uri!),
            ),
        ],
        if (!achievements.isEmpty) ...[
          const _Heading('ON MYOTHERAPP'),
          if ((achievements.eventsAttended ?? 0) > 0)
            _Fact(
              emoji: '🎟️',
              text: achievements.eventsAttended == 1
                  ? '1 event attended'
                  : '${achievements.eventsAttended} events attended',
            ),
          for (final talk in achievements.talks ?? const <ProfileTalk>[])
            _Fact(
              emoji: '🎤',
              text: talk.title == null
                  ? 'Spoke at ${talk.eventName}'
                  : '“${talk.title}” at ${talk.eventName}',
              onTap: talk.eventRoute == null
                  ? null
                  : () => context.push(talk.eventRoute!),
            ),
          for (final cert
              in achievements.certificates ?? const <ProfileCertificate>[])
            _Fact(
              emoji: '🏆',
              text: 'Certificate, ${cert.eventName}',
              onTap: cert.uri == null
                  ? null
                  : () => _open(context, ref, cert.uri!),
            ),
          for (final club in achievements.clubs ?? const <ProfileClub>[])
            _Fact(
              emoji: '🏛️',
              text: club.name,
              onTap:
                  club.route == null ? null : () => context.push(club.route!),
            ),
        ],
        if (profile.hiddenSections.isNotEmpty && !profile.isMe) ...[
          const SizedBox(height: 20),
          _Note(
            key: hiddenKey,
            emoji: '👀',
            text: profile.relation?.mutual == true
                ? 'Some parts are only for ${_first(profile)}.'
                : 'Some parts are only for people ${_first(profile)} has saved.',
          ),
        ],
      ],
    );
  }

  static String _first(PublicProfile p) => p.fullName.split(' ').first;

  static final _linkStyle = OutlinedButton.styleFrom(
    foregroundColor: AppColors.ink,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    textStyle: const TextStyle(fontSize: 14),
  );
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 8),
        child: Text(text,
            style: const TextStyle(fontFamily: 'BebasNeue', fontSize: 22)),
      );
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({required this.project, this.onOpen});

  final ProfileProject project;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final month = project.month;
    final line = [
      if (project.role != null) project.role!,
      if (month != null) DateFormat('MMM yyyy').format(month),
    ].join(' · ');
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('profile-project-${project.id ?? project.title}'),
        onTap: onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (project.image != null)
              AspectRatio(
                aspectRatio: 16 / 9,
                child: AppNetworkImage(
                  url: project.image,
                  fit: BoxFit.cover,
                  errorWidget: (_) => Container(color: AppColors.softGrey),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(project.title,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700)),
                      ),
                      if (onOpen != null)
                        const Icon(Icons.open_in_new, size: 18, color: _muted),
                    ],
                  ),
                  if (project.summary != null) ...[
                    const SizedBox(height: 2),
                    Text(project.summary!,
                        style: const TextStyle(fontSize: 14, height: 1.35)),
                  ],
                  if (line.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(line,
                        style: const TextStyle(fontSize: 12.5, color: _muted)),
                  ],
                  if (project.tags.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final tag in project.tags) TagPill(tag),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A small grey tag: a project's, or one of the owner's private tags.
class TagPill extends StatelessWidget {
  const TagPill(this.text, {super.key, this.onDeleted});

  final String text;
  final VoidCallback? onDeleted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(10, 4, onDeleted == null ? 10 : 4, 4),
      decoration: BoxDecoration(
        color: AppColors.softGrey,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text, style: const TextStyle(fontSize: 12.5)),
          if (onDeleted != null)
            InkResponse(
              onTap: onDeleted,
              radius: 14,
              child: const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Icon(Icons.close, size: 14, color: _muted),
              ),
            ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.emoji, required this.text, this.onTap});

  final String emoji;
  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
            if (onTap != null)
              const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF)),
          ],
        ),
      ),
    );
  }
}

/// A quiet line with an emoji: a private profile, hidden parts.
class _Note extends StatelessWidget {
  const _Note({super.key, required this.emoji, required this.text});

  final String emoji;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
      decoration: BoxDecoration(
        color: AppColors.softGrey,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
              child: Text(text,
                  style: const TextStyle(fontSize: 13.5, height: 1.3))),
        ],
      ),
    );
  }
}
