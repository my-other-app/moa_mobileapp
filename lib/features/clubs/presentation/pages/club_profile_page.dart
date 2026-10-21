import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:finnet/shared/widgets/rating_stars.dart';
import 'package:finnet/core/api/api_helper.dart';
import 'package:finnet/core/resources/asset_resources.dart';
import 'package:finnet/core/themes/app_colors.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/auth/presentation/sign_in_gate.dart';
import 'package:finnet/features/clubs/data/models/club_info.dart';
import 'package:finnet/features/clubs/presentation/pages/club_events_page.dart';
import 'package:finnet/features/clubs/presentation/providers/club_page_provider.dart';
import 'package:finnet/features/clubs/presentation/widgets/club_people.dart';
import 'package:finnet/shared/utils/external_links.dart';
import 'package:finnet/shared/utils/image_url.dart';
import 'package:finnet/shared/widgets/app_network_image.dart';
import 'package:finnet/shared/widgets/club_logo.dart';
import 'package:finnet/shared/widgets/error_view.dart';
import 'package:finnet/shared/widgets/shimmer_widgets.dart';
import 'package:finnet/core/utils/error_utils.dart';
import 'package:finnet/features/topics/domain/topic_emoji.dart';
import 'package:finnet/features/topics/presentation/widgets/topic_chips.dart';
import 'package:finnet/features/topics/presentation/widgets/topic_tag_strip.dart';
import 'package:finnet/features/discover/presentation/discover_navigation.dart';
import 'package:finnet/shared/motion.dart';
import 'package:finnet/shared/widgets/pressable.dart';
import 'package:finnet/shared/widgets/swap_label.dart';
import 'package:finnet/shared/widgets/fade_switch.dart';

export 'package:finnet/features/clubs/data/models/club_info.dart'
    show ClubInfo, ClubTeamMember, ClubPartner, Interest, Org;

/// A club's PROFILE tab: the website's club page, in the app.
///
/// Cover and tagline, who they are and where, follow, the club's website,
/// what it is about, its events, the people who run it, who backs it, its
/// links and how to reach it. Works signed out from the club's slug (the
/// public page); following asks to sign in first.
class ClubProfilePage extends ConsumerStatefulWidget {
  final int id;

  /// The club's slug, when the way in knew it. Signed out, it is what the
  /// page is read by.
  final String slug;

  const ClubProfilePage({super.key, required this.id, this.slug = ''});

  @override
  ConsumerState<ClubProfilePage> createState() => _ClubProfilePageState();
}

class _ClubProfilePageState extends ConsumerState<ClubProfilePage> {
  /// Follow, as tapped, until the server's copy of the club says otherwise.
  bool? _following;
  int _followerDelta = 0;
  bool _expanded = false;

  ClubKey get _key => ClubKey(widget.id, widget.slug);

  Future<void> _toggleFollow(ClubInfo club) async {
    final name = club.name.trim().isEmpty ? 'clubs' : club.name.trim();
    if (!ensureSignedIn(context, ref, 'Sign in to follow $name.')) return;

    final was = _following ?? club.isFollowing;
    final endpoint =
        was ? '/clubs/unfollow/${club.id}' : '/clubs/follow/${club.id}';

    setState(() {
      _following = !was;
      _followerDelta += was ? -1 : 1;
    });
    Haptics.light();

    try {
      await APIService.instance.request(endpoint, DioMethod.post);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _following = was;
        _followerDelta += was ? 1 : -1;
      });
      debugPrint('Follow/Unfollow failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(extractErrorMessage(
          e,
          defaultMessage: was
              ? "Couldn't unfollow $name. Please try again."
              : "Couldn't follow $name. Please try again.",
        )),
      ));
    }
  }

  Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    final opened = uri != null && await ref.read(linkLauncherProvider)(uri);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't open that link")),
      );
    }
  }

  void _navigateToClubEvents(ClubInfo club, {required bool isPast}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ClubEventsPage(
          clubId: club.id > 0 ? club.id : widget.id,
          clubSlug: club.slug.isNotEmpty ? club.slug : widget.slug,
          clubName: club.name.isEmpty ? 'Club' : club.name,
          clubLogo: imageUrlFrom(club.logo) ?? '',
          isPastEvents: isPast,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // A fresh copy of the club is the truth about following again.
    ref.listen(clubInfoProvider(_key), (previous, next) {
      if (next.hasValue && previous?.valueOrNull != next.valueOrNull) {
        if (_following != null || _followerDelta != 0) {
          setState(() {
            _following = null;
            _followerDelta = 0;
          });
        }
      }
    });
    final club = ref.watch(clubInfoProvider(_key));

    return Scaffold(
      backgroundColor: Colors.white,
      // The skeleton gives way to the club with a cross-fade.
      body: FadeSwitch(
        phase: club.when(
          skipLoadingOnReload: true,
          loading: () => ScreenPhase.loading,
          error: (_, __) => ScreenPhase.error,
          data: (_) => ScreenPhase.content,
        ),
        child: club.when(
          skipLoadingOnReload: true,
          loading: () => const ShimmerClubDetail(),
          error: (error, _) => _failure(error),
          data: _page,
        ),
      ),
    );
  }

  Widget _failure(Object error) {
    final signedIn = ref.watch(isAuthenticatedProvider);
    if (!signedIn && statusCodeOf(error) == 401) {
      return _Notice(
        key: const ValueKey('club-sign-in-to-see'),
        title: 'Sign in to see this club',
        message: 'Sign in to see its page, follow it and read its posts.',
        actionLabel: 'SIGN IN',
        onAction: () => startSignIn(context, ref),
      );
    }
    if (statusCodeOf(error) == 404) {
      return _Notice(
        key: const ValueKey('club-not-found'),
        title: "We couldn't find that club",
        message: 'The link may be old, or the club may have changed its '
            'address.',
        actionLabel: 'GO BACK',
        onAction: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/');
          }
        },
      );
    }
    return ErrorView(
      message: extractErrorMessage(
        error,
        defaultMessage: 'Could not load this club.',
      ),
      onRetry: () => ref.invalidate(clubInfoProvider(_key)),
    );
  }

  Widget _page(ClubInfo club) {
    final following = _following ?? club.isFollowing;
    final followers = club.followersCount + _followerDelta;
    final website = club.website;
    final hasCollege = club.org.name.trim().isNotEmpty;
    final hasPlace = club.locationName.trim().isNotEmpty;
    final name = club.name.isEmpty ? 'Club' : club.name;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(clubInfoProvider(_key));
        try {
          await ref.read(clubInfoProvider(_key).future);
        } catch (_) {
          // The error is on the page already, or the saved copy stays.
        }
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ClubCoverBanner(
              key: const ValueKey('club-cover'),
              url: club.coverUrl,
              seed: club.id,
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClubLogo(url: imageUrlFrom(club.logo), size: 56),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (club.tagline.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          club.tagline,
                          key: const ValueKey('club-tagline'),
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[700],
                            height: 1.3,
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        [
                          '$followers ${followers == 1 ? 'Follower' : 'Followers'}',
                          if (club.eventsHeld != null)
                            '${club.eventsHeld} '
                                '${club.eventsHeld == 1 ? 'event held' : 'events held'}',
                        ].join(' · '),
                        style: const TextStyle(fontSize: 12),
                      ),
                      // Its topics in their colours, above its interests.
                      // A topic opens its own page, as on the site.
                      TopicTagStrip(
                        topGap: 8,
                        declared: club.topics,
                        interests: [
                          for (final i in club.interests) i.toEntity(),
                        ],
                        onTopicTap: (topic) =>
                            context.push(topicLocation(topic.slug)),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final (index, interest)
                              in club.interests.indexed)
                            InterestTag(
                              label: interest.name,
                              glyph: interest.toEntity().emoji,
                              color: InterestTag.pastelAt(index),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // FOLLOW, the full width. "JOIN THE TEAM" sat beside it with
            // nothing behind it -- a dead button is a review rejection.
            SizedBox(
              width: double.infinity,
              child: Pressable(
                child: FilledButton(
                  key: const ValueKey('club-follow'),
                  onPressed: () => _toggleFollow(club),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2C333D),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  // FOLLOW turns into UNFOLLOW, and back, rather than
                  // flicking between them.
                  child: SwapLabel(
                    following ? 'UNFOLLOW' : 'FOLLOW',
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
              ),
            ),
            if (website != null) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  key: const ValueKey('club-website'),
                  onPressed: () => _open(website),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2C333D),
                    side: const BorderSide(color: Color(0xFF2C333D)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: Text(
                    'VISIT WEBSITE · ${hostLabel(website).toUpperCase()}',
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(fontSize: 18, fontFamily: 'BebasNeue'),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 30),
            _buildDescriptionSection(club),
            if (hasCollege || hasPlace) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  if (hasCollege)
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _showOrganizationPopup(club.org),
                        child: _infoCard(
                          icon: AssetResources.college,
                          title: 'College',
                          value: club.org.name,
                        ),
                      ),
                    ),
                  if (hasCollege && hasPlace) const SizedBox(width: 12),
                  if (hasPlace)
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _showLocationPopup(club),
                        child: _infoCard(
                          icon: AssetResources.location,
                          title: 'Location',
                          value: club.locationName,
                        ),
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _navigateToClubEvents(club, isPast: true),
                    child: _eventRedirectCard(value: 'PAST EVENTS'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _navigateToClubEvents(club, isPast: false),
                    child: _eventRedirectCard(value: 'UPCOMING EVENTS'),
                  ),
                ),
              ],
            ),
            if (club.team.isNotEmpty) ...[
              const SizedBox(height: 28),
              ClubTeamSection(
                key: const ValueKey('club-team'),
                clubName: name,
                team: club.team,
                onOpen: _open,
              ),
            ],
            if (club.partners.isNotEmpty) ...[
              const SizedBox(height: 28),
              ClubPartnersSection(
                key: const ValueKey('club-partners'),
                clubName: name,
                partners: club.partners,
              ),
            ],
            ..._socials(club),
            const SizedBox(height: 24),
            // The average rating of the club's events.
            if (club.rating > 0) ...[
              _buildRatingSection(club),
              const SizedBox(height: 24),
            ],
            ..._contact(club),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  /// The club's links that lead anywhere; nothing at all when there are
  /// none (four dead buttons used to show regardless).
  List<Widget> _socials(ClubInfo club) {
    final links = [
      for (final (key, asset) in const [
        ('instagram', 'assets/images/Instagram.png'),
        ('linkedin', 'assets/images/LinkedIn.png'),
        ('youtube', 'assets/images/YouTube.png'),
        ('website', 'assets/images/Website.png'),
      ])
        if (safeWebUrl(club.socials[key] is String
                ? club.socials[key] as String
                : null)
            case final url?)
          (key, asset, url),
    ];
    if (links.isEmpty) return const [];
    return [
      const SizedBox(height: 28),
      Row(
        key: const ValueKey('club-socials'),
        children: [
          for (final (index, (key, asset, url)) in links.indexed) ...[
            if (index > 0) const SizedBox(width: 16),
            Expanded(
              child: _buildSocialCard(url, asset, key),
            ),
          ],
          // Keeps a lone link the size of a quarter, as in a full row.
          for (var i = links.length; i < 4; i++) ...[
            const SizedBox(width: 16),
            const Expanded(child: SizedBox.shrink()),
          ],
        ],
      ),
    ];
  }

  List<Widget> _contact(ClubInfo club) {
    final phone = club.contactPhone.trim();
    final email = club.contactEmail.trim();
    if (phone.isEmpty && email.isEmpty) return const [];
    return [
      const Text(
        'Need Help?',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
      ),
      const SizedBox(height: 8),
      const Text(
        "Got any questions? We're here to help—hit us up!",
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 8),
      if (email.isNotEmpty)
        _contactLink(
          key: 'club-email',
          label: 'Email $email',
          onTap: () => openExternally(Uri(scheme: 'mailto', path: email)),
        ),
      if (phone.isNotEmpty)
        _contactLink(
          key: 'club-call',
          label: 'Call Committee',
          // Never throws: a phone without a dialler (a tablet) used to
          // raise a PlatformException from this tap.
          onTap: () => openExternally(Uri(scheme: 'tel', path: phone)),
        ),
    ];
  }

  Widget _contactLink({
    required String key,
    required String label,
    required Future<bool> Function() onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: GestureDetector(
        key: ValueKey(key),
        onTap: () async {
          if (!await onTap() && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Couldn't open that")),
            );
          }
        },
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.blue,
            decoration: TextDecoration.underline,
          ),
        ),
      ),
    );
  }

  Widget _buildDescriptionSection(ClubInfo club) {
    final description = club.about.trim().isEmpty
        ? '${club.name.isEmpty ? 'This club' : club.name} is on MyOtherApp.'
        : club.about;
    final maxLines = _expanded ? null : 7;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          description,
          maxLines: maxLines,
          overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
          style: const TextStyle(height: 1.4, fontSize: 14),
        ),
        if (description.length > 200)
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Text(
              _expanded ? 'Show Less' : 'Read More',
              style: const TextStyle(
                color: Color(0xFF17A58F),
                fontWeight: FontWeight.bold,
                decoration: TextDecoration.underline,
                fontSize: 14,
              ),
            ),
          ),
      ],
    );
  }

  /// Show organization details popup (matching event page style)
  void _showOrganizationPopup(Org org) {
    showDialog(
      context: context,
      builder: (context) => _InfoDialog(
        icon: AssetResources.college,
        label: 'Organization',
        title: org.name,
        lines: [
          if (org.type.isNotEmpty) org.type,
          if (org.address.isNotEmpty) org.address,
        ],
        buttonLabel: 'CLOSE',
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  /// Show location details popup (matching event page style)
  void _showLocationPopup(ClubInfo club) {
    showDialog(
      context: context,
      builder: (dialogContext) => _InfoDialog(
        icon: AssetResources.location,
        label: 'Location',
        title: club.locationName,
        buttonLabel: 'OPEN MAPS',
        onPressed: () async {
          Navigator.pop(dialogContext);
          // The club's own map link first, else a search for the place.
          final link = club.locationLink.isNotEmpty
              ? club.locationLink
              : 'https://www.google.com/maps/search/?api=1&query='
                  '${Uri.encodeComponent(club.locationName)}';
          final uri = Uri.tryParse(link);
          if (uri != null) await openExternally(uri);
        },
      ),
    );
  }

  /// The average rating of all the club's events.
  Widget _buildRatingSection(ClubInfo club) {
    return Column(
      children: [
        RatingStars(rating: club.rating, size: 28),
        const SizedBox(height: 8),
        Text(
          '${club.rating.toStringAsFixed(1)} RATED',
          style: const TextStyle(
            fontSize: 28,
            fontFamily: 'BebasNeue',
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          'Rated by ${club.totalRatings} Participants',
          style: const TextStyle(fontSize: 14, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _infoCard({
    required String icon,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.white,
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xffF3F3F3),
            radius: 24,
            child: Image.asset(icon, height: 25, width: 25),
          ),
          const SizedBox(height: 5),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontFamily: 'BebasNeue',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _eventRedirectCard({required String value}) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.white,
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Center(
        child: Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontFamily: 'BebasNeue',
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  Widget _buildSocialCard(String url, String assetPath, String kind) {
    return InkWell(
      key: ValueKey('club-social-$kind'),
      onTap: () => _open(url),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade400, width: 1),
        ),
        child: Center(
          child: Image.asset(assetPath, fit: BoxFit.contain),
        ),
      ),
    );
  }
}

/// The club's banner: its cover photo, or a band in a colour of its own
/// when it has none (as on the website).
class ClubCoverBanner extends StatelessWidget {
  final String? url;
  final int seed;

  const ClubCoverBanner({super.key, required this.url, required this.seed});

  static const _bands = [
    [Color(0xFFE1C9FF), Color(0xFFB8DFF2)],
    [Color(0xFFF9FFA1), Color(0xFFFFC84A)],
    [Color(0xFFB4E5BC), Color(0xFF17A58F)],
    [Color(0xFFFFDEDD), Color(0xFFE1C9FF)],
  ];

  @override
  Widget build(BuildContext context) {
    final colors = _bands[seed.abs() % _bands.length];
    final band = DecoratedBox(
      key: const ValueKey('club-cover-fallback'),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        // The website's cover is three times as wide as it is tall.
        aspectRatio: 3,
        child: AppNetworkImage(
          url: url,
          fit: BoxFit.cover,
          placeholder: (_) => band,
          errorWidget: (_) => band,
        ),
      ),
    );
  }
}

/// A short notice in place of the page, with one way on.
class _Notice extends StatelessWidget {
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  const _Notice({
    super.key,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.groups_outlined, size: 56, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 26,
                fontFamily: 'BebasNeue',
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: onAction,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2C333D),
              ),
              child: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}

/// The college or location card's popup.
class _InfoDialog extends StatelessWidget {
  final String icon;
  final String label;
  final String title;
  final List<String> lines;
  final String buttonLabel;
  final VoidCallback onPressed;

  const _InfoDialog({
    required this.icon,
    required this.label,
    required this.title,
    this.lines = const [],
    required this.buttonLabel,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              backgroundColor: const Color(0xffF3F3F3),
              radius: 28,
              child: Image.asset(icon, height: 28, width: 28),
            ),
            const SizedBox(height: 16),
            Text(label,
                style: const TextStyle(fontSize: 14, color: Colors.grey)),
            const SizedBox(height: 8),
            Text(
              (title.isEmpty ? 'N/A' : title).toUpperCase(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                fontFamily: 'BebasNeue',
              ),
            ),
            for (final line in lines) ...[
              const SizedBox(height: 8),
              Text(line,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14)),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onPressed,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2C333D),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  buttonLabel,
                  style: const TextStyle(
                    fontSize: 16,
                    fontFamily: 'BebasNeue',
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
