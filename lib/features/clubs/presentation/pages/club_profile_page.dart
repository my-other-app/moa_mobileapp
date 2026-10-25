import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:finnet/shared/widgets/rating_stars.dart';
import 'package:finnet/core/resources/asset_resources.dart';
import 'package:finnet/core/themes/app_colors.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/auth/presentation/sign_in_gate.dart';
import 'package:finnet/features/clubs/data/club_follow_service.dart';
import 'package:finnet/features/clubs/data/models/club_info.dart';
import 'package:finnet/features/clubs/presentation/cubits/club_follow_cubit.dart';
import 'package:finnet/features/clubs/presentation/pages/club_events_page.dart';
import 'package:finnet/features/clubs/presentation/providers/club_page_provider.dart';
import 'package:finnet/features/clubs/presentation/widgets/club_people.dart';
import 'package:finnet/features/clubs/presentation/widgets/club_updates_tile.dart';
import 'package:finnet/shared/utils/external_links.dart';
import 'package:finnet/shared/utils/image_url.dart';
import 'package:finnet/shared/widgets/club_logo.dart';
import 'package:finnet/shared/widgets/error_view.dart';
import 'package:finnet/shared/widgets/shimmer_widgets.dart';
import 'package:finnet/core/utils/error_utils.dart';
import 'package:finnet/features/topics/domain/topic_emoji.dart';
import 'package:finnet/features/topics/presentation/widgets/topic_chips.dart';
import 'package:finnet/shared/motion.dart';
import 'package:finnet/shared/widgets/animated_count.dart';
import 'package:finnet/shared/widgets/pressable.dart';
import 'package:finnet/shared/widgets/swap_label.dart';
import 'package:finnet/shared/widgets/fade_switch.dart';

export 'package:finnet/features/clubs/data/models/club_info.dart'
    show ClubInfo, ClubTeamMember, ClubPartner, Interest, Org;

/// A club's PROFILE tab: the website's club page, in the app.
///
/// Its logo, name, tagline and place, how many follow it, its interests,
/// follow, the club's website, what it is about, its events, the people who
/// run it, who backs it, its links and how to reach it. No cover banner and
/// no topics (the website has both): the page opens on the club itself, and
/// its interests say what it is about. Works signed out from the club's
/// slug (the public page); following asks to sign in first. For a club that
/// can broadcast on WhatsApp, "Get updates from `<club>` on WhatsApp" sits
/// under FOLLOW for a signed-in person (ClubFollowCubit).
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
  /// Follow (as tapped, until the server's copy of the club says
  /// otherwise) and the follower's yes to the club's updates on WhatsApp.
  /// Made with the first copy of the club.
  ClubFollowCubit? _follow;
  bool _expanded = false;

  ClubKey get _key => ClubKey(widget.id, widget.slug);

  ClubFollowCubit _followFor(ClubInfo club) {
    return _follow ??= ClubFollowCubit(
      service: ref.read(clubFollowServiceProvider),
      clubId: club.id,
      following: club.isFollowing,
      updates: club.clubUpdatesWhatsapp,
    )..onStateChanged = (_) {
        if (mounted) setState(() {});
      };
  }

  @override
  void dispose() {
    _follow?.dispose();
    super.dispose();
  }

  Future<void> _toggleFollow(ClubInfo club) async {
    final name = club.name.trim().isEmpty ? 'clubs' : club.name.trim();
    if (!ensureSignedIn(context, ref, 'Sign in to follow $name.')) return;

    final follow = _followFor(club);
    final was = follow.state.following;
    Haptics.light();
    final error = await follow.toggleFollow();
    if (error == null || !mounted) return;
    debugPrint('Follow/Unfollow failed: $error');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(extractErrorMessage(
        error,
        defaultMessage: was
            ? "Couldn't unfollow $name. Please try again."
            : "Couldn't follow $name. Please try again.",
      )),
    ));
  }

  /// The box under FOLLOW: before following, a tick for the follow to take
  /// along; once following, the follower's switch.
  Future<void> _setClubUpdates(ClubInfo club, bool on) async {
    final follow = _followFor(club);
    if (!follow.state.following) {
      follow.tickBeforeFollow(on);
      return;
    }
    final error = await follow.setUpdates(on);
    if (error == null || !mounted) return;
    debugPrint('Club updates on WhatsApp failed: $error');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(extractErrorMessage(
        error,
        defaultMessage: on
            ? "Couldn't turn on WhatsApp updates. Please try again."
            : "Couldn't turn off WhatsApp updates. Please try again.",
      )),
    ));
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
      final club = next.valueOrNull;
      if (club != null && previous?.valueOrNull != club) {
        _follow?.sync(
          clubId: club.id,
          following: club.isFollowing,
          updates: club.clubUpdatesWhatsapp,
        );
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
    final follow = _followFor(club).state;
    final following = follow.following;
    // Never below nought, whatever an unfollow raced against.
    final counted = club.followersCount + follow.delta;
    final followers = counted < 0 ? 0 : counted;
    final website = club.website;
    final hasCollege = club.org.name.trim().isNotEmpty;
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
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ..._header(club, name: name, followers: followers),
            const SizedBox(height: 20),
            // FOLLOW, the full width. "JOIN THE TEAM" sat beside it with
            // nothing behind it -- a dead button is a review rejection.
            SizedBox(
              width: double.infinity,
              child: Pressable(
                child: FilledButton(
                  key: const ValueKey('club-follow'),
                  onPressed: () => _toggleFollow(club),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.ink,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
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
            // Only for a club that can send its updates on WhatsApp, and
            // only signed in: following asks for an account first.
            if (club.whatsappUpdates &&
                ref.watch(isAuthenticatedProvider)) ...[
              const SizedBox(height: 4),
              ClubUpdatesTile(
                clubName: name,
                value: follow.boxTicked,
                following: following,
                enabled: !follow.busy && !follow.updatesBusy,
                onChanged: (on) => _setClubUpdates(club, on),
              ),
            ],
            if (website != null) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  key: const ValueKey('club-website'),
                  onPressed: () => _open(website),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.ink,
                    side: const BorderSide(color: AppColors.ink),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
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
            const SizedBox(height: 28),
            const ClubSectionTitle(title: 'ABOUT'),
            _buildDescriptionSection(club),
            if (hasCollege) ...[
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => _showOrganizationPopup(club.org),
                child: _infoCard(
                  icon: AssetResources.college,
                  title: 'College',
                  value: club.org.name,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _eventRedirectCard(
                    key: 'club-past-events',
                    value: 'PAST EVENTS',
                    onTap: () => _navigateToClubEvents(club, isPast: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _eventRedirectCard(
                    key: 'club-upcoming-events',
                    value: 'UPCOMING EVENTS',
                    onTap: () => _navigateToClubEvents(club, isPast: false),
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

  /// The top of the page, centred: the logo, the name, the tagline, where
  /// the club is (a tap opens the map), how many follow it and how many
  /// events it has held, then its interests.
  List<Widget> _header(
    ClubInfo club, {
    required String name,
    required int followers,
  }) {
    final place = club.locationName.trim();
    return [
      Container(
        key: const ValueKey('club-logo'),
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: ClubLogo(url: imageUrlFrom(club.logo), size: 88, radius: 19),
      ),
      const SizedBox(height: 14),
      Semantics(
        header: true,
        child: Text(
          name,
          key: const ValueKey('club-name'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 36,
            height: 1.0,
            fontFamily: 'BebasNeue',
            color: AppColors.border,
          ),
        ),
      ),
      if (club.tagline.isNotEmpty) ...[
        const SizedBox(height: 6),
        Text(
          club.tagline,
          key: const ValueKey('club-tagline'),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Colors.grey[700], height: 1.35),
        ),
      ],
      if (place.isNotEmpty) ...[
        const SizedBox(height: 2),
        _PlaceLine(place: place, onTap: () => _showLocationPopup(club)),
      ] else
        const SizedBox(height: 14),
      _ClubStats(followers: followers, eventsHeld: club.eventsHeld),
      // What the club is about: its interests, as the app's tags. Its
      // topics ("Development", "Deep Tech") are left to Discover.
      if (club.interests.isNotEmpty) ...[
        const SizedBox(height: 16),
        Wrap(
          key: const ValueKey('club-interests'),
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (index, interest) in club.interests.indexed)
              InterestTag(
                label: interest.name,
                glyph: interest.toEntity().emoji,
                color: InterestTag.pastelAt(index),
                fontSize: 13,
              ),
          ],
        ),
      ],
    ];
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
      width: double.infinity,
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

  Widget _eventRedirectCard({
    required String key,
    required String value,
    required VoidCallback onTap,
  }) {
    return Pressable(
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AppColors.border, width: 0.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey(key),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.all(8.0),
            alignment: Alignment.center,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontFamily: 'BebasNeue',
                overflow: TextOverflow.ellipsis,
              ),
            ),
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

/// Where the club is, under its tagline: a pin and the place. A tap opens
/// the map; the whole line is the tap target, a full 48 points tall.
class _PlaceLine extends StatelessWidget {
  final String place;
  final VoidCallback onTap;

  const _PlaceLine({required this.place, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: place,
      hint: 'Opens the map',
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        key: const ValueKey('club-place'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.location_on_outlined,
                    size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    place,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[700],
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// How many follow the club, and how many events it has held when the
/// server says: big numbers on the app's yellow. Always there -- "0
/// FOLLOWERS" too -- and ticking over as the person follows or unfollows.
class _ClubStats extends StatelessWidget {
  final int followers;
  final int? eventsHeld;

  const _ClubStats({required this.followers, required this.eventsHeld});

  @override
  Widget build(BuildContext context) {
    final held = eventsHeld;
    return Container(
      key: const ValueKey('club-stats'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.paleYellow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: _Stat(
                key: const ValueKey('club-followers'),
                value: followers,
                label: followers == 1 ? 'FOLLOWER' : 'FOLLOWERS',
                spoken: followers == 1 ? 'follower' : 'followers',
              ),
            ),
            if (held != null) ...[
              const VerticalDivider(
                width: 1,
                thickness: 0.5,
                indent: 6,
                endIndent: 6,
                color: AppColors.border,
              ),
              Expanded(
                child: _Stat(
                  key: const ValueKey('club-events-held'),
                  value: held,
                  label: held == 1 ? 'EVENT HELD' : 'EVENTS HELD',
                  spoken: held == 1 ? 'event held' : 'events held',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

final _grouped = NumberFormat.decimalPattern('en_IN');

class _Stat extends StatelessWidget {
  final int value;
  final String label;

  /// What a screen reader says after the number.
  final String spoken;

  const _Stat({
    super.key,
    required this.value,
    required this.label,
    required this.spoken,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${_grouped.format(value)} $spoken',
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedCount(
            value: value,
            format: _grouped.format,
            style: const TextStyle(
              fontSize: 30,
              height: 1.1,
              fontFamily: 'BebasNeue',
              color: AppColors.border,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
        ],
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
