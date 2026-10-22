import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
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
import 'package:finnet/shared/widgets/club_logo.dart';
import 'package:finnet/shared/widgets/error_view.dart';
import 'package:finnet/shared/widgets/shimmer_widgets.dart';
import 'package:finnet/core/utils/error_utils.dart';
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
/// Its logo and name, how many follow it and its events to come and held,
/// its tagline, interests and place, follow (and join, when it says where),
/// the club's website, what it is about, its events, the people who run it,
/// who backs it, its links and how to reach it. No cover banner and
/// no topics (the website has both): the page opens on the club itself, and
/// its interests say what it is about. Works signed out from the club's
/// slug (the public page); following asks to sign in first.
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
    // Never below nought, whatever an unfollow raced against.
    final counted = club.followersCount + _followerDelta;
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
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _header(club, name: name, followers: followers),
            const SizedBox(height: 16),
            _actions(club, following: following, website: website),
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

  /// The top of the page: the logo on the left; beside it, left-aligned,
  /// the name, the numbers (followers, events to come, events held), the
  /// tagline, the interests and where the club is (a tap opens the map).
  Widget _header(
    ClubInfo club, {
    required String name,
    required int followers,
  }) {
    final place = club.locationName.trim();
    return Row(
      key: const ValueKey('club-header'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClubLogo(
          key: const ValueKey('club-logo'),
          url: imageUrlFrom(club.logo),
          size: 64,
          radius: 10,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  name,
                  key: const ValueKey('club-name'),
                  style: const TextStyle(
                    fontSize: 22,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                    color: AppColors.border,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              _ClubNumbers(
                followers: followers,
                upcoming: club.upcomingEvents,
                held: club.eventsHeld,
              ),
              if (club.tagline.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  club.tagline,
                  key: const ValueKey('club-tagline'),
                  style: TextStyle(
                    fontSize: 13.5,
                    color: Colors.grey[700],
                    height: 1.35,
                  ),
                ),
              ],
              // What the club is about: its interests, as plain pastel
              // tags. Its topics ("Development", "Deep Tech") are left to
              // Discover.
              if (club.interests.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  key: const ValueKey('club-interests'),
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final (index, interest) in club.interests.indexed)
                      InterestTag(
                        label: interest.name,
                        color: _chipColors[index % _chipColors.length],
                        fontSize: 13,
                      ),
                  ],
                ),
              ],
              if (place.isNotEmpty)
                _PlaceLine(place: place, onTap: () => _showLocationPopup(club))
              else
                const SizedBox(height: 4),
            ],
          ),
        ),
      ],
    );
  }

  /// FOLLOW, and JOIN THE TEAM beside it when the club has somewhere to
  /// join; then the club's website. JOIN THE TEAM once sat here with
  /// nothing behind it -- a dead button is a review rejection -- so it shows
  /// only with a link to follow ([ClubInfo.joinUrl]).
  Widget _actions(
    ClubInfo club, {
    required bool following,
    required String? website,
  }) {
    final join = club.joinUrl;
    final follow = Pressable(
      child: FilledButton(
        key: const ValueKey('club-follow'),
        onPressed: () => _toggleFollow(club),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.ink,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        // FOLLOW turns into UNFOLLOW, and back, rather than flicking
        // between them.
        child: SwapLabel(
          following ? 'UNFOLLOW' : 'FOLLOW',
          style: const TextStyle(fontSize: 24, fontFamily: 'BebasNeue'),
        ),
      ),
    );
    return Column(
      children: [
        if (join != null)
          Row(
            children: [
              Expanded(
                child: _outlineButton(
                  key: 'club-join',
                  label: 'JOIN THE TEAM',
                  onPressed: () => _open(join),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: follow),
            ],
          )
        else
          SizedBox(width: double.infinity, child: follow),
        if (website != null) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: _outlineButton(
              key: 'club-website',
              label: 'VISIT WEBSITE · ${hostLabel(website).toUpperCase()}',
              icon: Icons.open_in_new,
              // The club's address is long: smaller, so it is read whole.
              fontSize: 18,
              onPressed: () => _open(website),
            ),
          ),
        ],
      ],
    );
  }

  /// White, with an ink edge: JOIN THE TEAM, VISIT WEBSITE.
  Widget _outlineButton({
    required String key,
    required String label,
    required VoidCallback onPressed,
    IconData? icon,
    double fontSize = 24,
  }) {
    final text = Text(
      label,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: fontSize, fontFamily: 'BebasNeue'),
    );
    final style = OutlinedButton.styleFrom(
      foregroundColor: AppColors.ink,
      backgroundColor: Colors.white,
      side: const BorderSide(color: AppColors.ink),
      minimumSize: const Size.fromHeight(56),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
    return Pressable(
      child: icon == null
          ? OutlinedButton(
              key: ValueKey(key),
              onPressed: onPressed,
              style: style,
              child: text,
            )
          : OutlinedButton.icon(
              key: ValueKey(key),
              onPressed: onPressed,
              style: style,
              icon: Icon(icon, size: 18),
              label: text,
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

/// Where the club is, under its interests: a pin and the place. A tap
/// opens the map; the whole line is the tap target, a full 48 points tall.
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
            padding: const EdgeInsets.only(right: 8, top: 6, bottom: 6),
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

/// The interest tags' fills, in turn: blue, yellow, rose, green, peach,
/// pink, lilac.
const _chipColors = [
  Color(0xFFB8DFF2),
  Color(0xFFF9FFA1),
  Color(0xFFFFDEDD),
  Color(0xFFB4E5BC),
  Color(0xFFFFE0C2),
  Color(0xFFFFD1E8),
  Color(0xFFE1C9FF),
];

final _grouped = NumberFormat.decimalPattern('en_IN');

/// One line of numbers under the name: "2,560 followers  3 upcoming
/// 3 events held", the numbers bold and the words grey. The followers are
/// always there, 0 too, ticking over as the person follows or unfollows;
/// the others only when the server says and they are more than none. On a
/// narrow phone the line wraps between the parts, never inside one.
class _ClubNumbers extends StatelessWidget {
  final int followers;
  final int? upcoming;
  final int? held;

  const _ClubNumbers({
    required this.followers,
    required this.upcoming,
    required this.held,
  });

  static const _number = TextStyle(
    fontSize: 13,
    height: 1.35,
    fontWeight: FontWeight.w700,
    color: AppColors.border,
  );

  @override
  Widget build(BuildContext context) {
    final words =
        TextStyle(fontSize: 13, height: 1.35, color: Colors.grey[600]);
    final soon = upcoming ?? 0;
    final past = held ?? 0;
    final parts = [
      (
        'club-followers',
        followers,
        followers == 1 ? 'follower' : 'followers',
        followers == 1 ? 'follower' : 'followers',
      ),
      if (soon > 0)
        (
          'club-upcoming',
          soon,
          'upcoming',
          soon == 1 ? 'upcoming event' : 'upcoming events',
        ),
      if (past > 0)
        (
          'club-events-held',
          past,
          past == 1 ? 'event held' : 'events held',
          past == 1 ? 'event held' : 'events held',
        ),
    ];
    return Semantics(
      label: [
        for (final (_, n, _, spoken) in parts) '${_grouped.format(n)} $spoken',
      ].join(', '),
      excludeSemantics: true,
      child: Wrap(
        key: const ValueKey('club-stats'),
        spacing: 12,
        runSpacing: 2,
        children: [
          for (final (key, n, word, _) in parts)
            Row(
              key: ValueKey(key),
              mainAxisSize: MainAxisSize.min,
              children: [
                if (key == 'club-followers')
                  AnimatedCount(
                    value: n,
                    format: _grouped.format,
                    style: _number,
                  )
                else
                  Text(_grouped.format(n), style: _number),
                const SizedBox(width: 4),
                Text(word, style: words),
              ],
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
