import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:finnet/core/api/api_helper.dart';
import 'package:finnet/core/themes/app_colors.dart';
import 'package:finnet/core/utils/json_read.dart';
import 'package:finnet/features/events/domain/networking.dart';
import 'package:finnet/features/events/presentation/providers/networking_provider.dart';
import 'package:finnet/features/events/presentation/utils/event_errors.dart';
import 'package:finnet/features/events/presentation/widgets/networking/networking_visibility_switch.dart';
import 'package:finnet/features/threads/domain/entities/moderation.dart';
import 'package:finnet/features/threads/presentation/providers/moderation_provider.dart';
import 'package:finnet/features/threads/presentation/widgets/moderation_actions.dart';
import 'package:finnet/features/topics/domain/topic_emoji.dart';
import 'package:finnet/features/topics/presentation/widgets/topic_chips.dart';
import 'package:finnet/shared/widgets/app_network_image.dart';

export 'package:finnet/features/events/domain/networking.dart'
    show NetworkingAttendee, SharedInterest;

const _ink = Color(0xFF1E1E1E);
const _muted = Color(0xFF6B6B6B);

/// "People Like You": the others checked in at an event, those who share
/// your interests first.
///
/// At the top, your own "Show me in People Like You", to turn off on the
/// spot. Pull to refresh as more people arrive. Each person can be reported
/// or blocked from their card, with the same report (`POST /reports`, a
/// `user`) and block (`/user/blocks`) as in Threads; someone blocked leaves
/// the list at once.
///
/// Opened from the event page's card, Home's "You're at" banner and the
/// check-in push, as `/events/{id}/people`. A slug there is read as its
/// event first.
class NetworkingPage extends ConsumerStatefulWidget {
  final int eventId;
  final String eventName;

  /// The event as the address had it, when that was a slug: read for its
  /// id before the list is asked for.
  final String? eventRef;

  const NetworkingPage({
    super.key,
    required this.eventId,
    this.eventName = '',
    this.eventRef,
  });

  @override
  ConsumerState<NetworkingPage> createState() => _NetworkingPageState();
}

class _NetworkingPageState extends ConsumerState<NetworkingPage> {
  late int _eventId = widget.eventId;
  Object? _resolveError;

  @override
  void initState() {
    super.initState();
    if (_eventId <= 0 && (widget.eventRef ?? '').trim().isNotEmpty) {
      _resolve();
    }
  }

  /// A slug in the address: the event's id from its page.
  Future<void> _resolve() async {
    setState(() => _resolveError = null);
    try {
      final res = await APIService.instance.request(
        '/events/info/${Uri.encodeComponent(widget.eventRef!.trim())}',
        DioMethod.get,
      );
      final id = jsonInt(jsonObject(res.data)?['id']) ?? 0;
      if (!mounted) return;
      setState(() => _eventId = id);
    } catch (e) {
      if (mounted) setState(() => _resolveError = e);
    }
  }

  Future<void> _refresh() async {
    if (_eventId <= 0) return _resolve();
    ref.invalidate(networkingPeopleProvider(_eventId));
    try {
      await ref.read(networkingPeopleProvider(_eventId).future);
    } catch (_) {
      // The screen shows why.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        scrolledUnderElevation: 0,
        title: const Text(
          'People Like You',
          style: TextStyle(fontSize: 24, fontFamily: 'BebasNeue'),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: _body(),
      ),
    );
  }

  Widget _body() {
    if (_eventId <= 0) {
      if (_resolveError != null || (widget.eventRef ?? '').trim().isEmpty) {
        return _scrolling([
          _Problem(
            emoji: '🔍',
            title: "We couldn't find this event",
            message: readableError(_resolveError,
                fallback: 'Check the link, or open the event from Home.'),
            onRetry: (widget.eventRef ?? '').trim().isEmpty ? null : _resolve,
          ),
        ]);
      }
      return const Center(child: CircularProgressIndicator());
    }

    // The visibility the list reports is the server's latest word.
    ref.listen<AsyncValue<NetworkingPeople>>(
      networkingPeopleProvider(_eventId),
      (_, next) => next.whenData((people) => ref
          .read(networkingVisibilityProvider.notifier)
          .known(people.visible)),
    );
    final answer = ref.watch(networkingPeopleProvider(_eventId));
    final people = answer.valueOrNull;
    if (people == null) {
      if (answer.hasError) return _problem(answer.error);
      return const Center(child: CircularProgressIndicator());
    }
    return _list(people);
  }

  /// [children] in a list that can always be pulled, so an empty or
  /// failed screen refreshes too.
  Widget _scrolling(List<Widget> children) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: children,
      );

  Widget _problem(Object? error) {
    final copy = NetworkingProblem.of(error);
    return _scrolling([
      // Hidden, with the two-way rule on: the switch is the way back in.
      if (copy.showSwitch) ...[
        const NetworkingVisibilityBanner(),
        const SizedBox(height: 8),
      ],
      _Problem(
        emoji: copy.emoji,
        title: copy.title,
        message: copy.message,
        onRetry: copy.canRetry ? _refresh : null,
        retryLabel: copy.retryLabel,
        // Nothing more here: the event itself, in this page's place.
        onOpenEvent: copy.offerEvent
            ? () => context.pushReplacement('/events/$_eventId')
            : null,
      ),
    ]);
  }

  Widget _list(NetworkingPeople people) {
    // Blocked -- here or anywhere else this session -- they are not shown.
    final hidden = ref.watch(moderationProvider).hiddenUserIds;
    bool shown(NetworkingAttendee a) => !hidden.contains(a.userId);
    final sharing = people.sharing.where(shown).toList();
    final alsoHere = people.alsoHere.where(shown).toList();
    final name = people.eventName.isNotEmpty ? people.eventName : widget.eventName;

    return _scrolling([
      const NetworkingVisibilityBanner(),
      const SizedBox(height: 16),
      _Heading(eventName: name, closesAt: people.closesAt),
      const SizedBox(height: 12),
      if (sharing.isEmpty)
        const _Empty()
      else ...[
        _SectionTitle(
          sharing.length == 1
              ? '1 person shares your interests'
              : '${sharing.length} people share your interests',
        ),
        for (final a in sharing) _PersonCard(attendee: a),
      ],
      if (alsoHere.isNotEmpty) ...[
        const SizedBox(height: 8),
        const _SectionTitle('Also here'),
        for (final a in alsoHere) _PersonCard(attendee: a),
      ],
    ]);
  }
}

/// What the page says when the list can't be shown, by the server's code.
class NetworkingProblem {
  const NetworkingProblem({
    required this.emoji,
    required this.title,
    required this.message,
    this.canRetry = false,
    this.retryLabel = 'Try again',
    this.showSwitch = false,
    this.offerEvent = false,
  });

  final String emoji;
  final String title;
  final String message;
  final bool canRetry;
  final String retryLabel;
  final bool showSwitch;

  /// Nothing to try again: offer the event's page instead.
  final bool offerEvent;

  factory NetworkingProblem.of(Object? error) {
    switch (errorCodeOf(error)) {
      case networkingUnavailableCode:
        // The club's plan: trying again won't change that.
        return const NetworkingProblem(
          emoji: '🤝',
          title: "This event doesn't have People Like You",
          message: 'The organisers haven’t turned it on for this event.',
          offerEvent: true,
        );
      case networkingNotCheckedInCode:
        return const NetworkingProblem(
          emoji: '🚪',
          title: 'Check in first',
          message: 'People Like You opens once you’re checked in at the '
              'door. Show your ticket at the entrance, then come back here.',
          canRetry: true,
          retryLabel: 'I’ve checked in',
        );
      case networkingClosedCode:
        return const NetworkingProblem(
          emoji: '🌙',
          title: 'People Like You has closed',
          message: 'It’s open during the event and for an hour after it ends.',
          offerEvent: true,
        );
      case networkingHiddenCode:
        return const NetworkingProblem(
          emoji: '🙈',
          title: 'You’re hidden here',
          message: 'Turn on “Show me in People Like You” to see who else is '
              'here.',
          canRetry: true,
          showSwitch: true,
        );
    }
    return NetworkingProblem(
      emoji: '📡',
      title: "Couldn't load who's here",
      message: networkingErrorMessage(error),
      canRetry: true,
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading({required this.eventName, required this.closesAt});

  final String eventName;
  final DateTime? closesAt;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (eventName.isNotEmpty)
          Text(
            eventName,
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.w700, color: _ink),
          ),
        if (closesAt != null) ...[
          const SizedBox(height: 2),
          Row(
            children: [
              const Icon(Icons.schedule, size: 14, color: _muted),
              const SizedBox(width: 4),
              Text(
                'Open until ${openUntil(closesAt!)}',
                key: const ValueKey('networking-open-until'),
                style: const TextStyle(fontSize: 12.5, color: _muted),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// "9:30 PM" today, "Sat 9:30 PM" on another day: when the list closes, in
/// the phone's time.
String openUntil(DateTime closesAt, {DateTime? now}) {
  final local = closesAt.toLocal();
  final today = (now ?? DateTime.now()).toLocal();
  final sameDay = local.year == today.year &&
      local.month == today.month &&
      local.day == today.day;
  final time = DateFormat('h:mm a').format(local);
  return sameDay ? time : '${DateFormat('EEE').format(local)} $time';
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
            fontSize: 14, fontWeight: FontWeight.w700, color: _ink),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('networking-empty'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      decoration: BoxDecoration(
        color: AppColors.softGrey,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Column(
        children: [
          Text('🌱', style: TextStyle(fontSize: 40)),
          SizedBox(height: 10),
          Text(
            'No one else here shares your interests yet.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w600, color: _ink),
          ),
          SizedBox(height: 4),
          Text(
            'Check back as more people arrive.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: _muted),
          ),
        ],
      ),
    );
  }
}

class _PersonCard extends ConsumerWidget {
  const _PersonCard({required this.attendee});

  final NetworkingAttendee attendee;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final org = attendee.organization?.trim() ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE6E6E6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Avatar(attendee: attendee),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 2),
                Text(
                  attendee.name,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600, color: _ink),
                ),
                if (org.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(org,
                      style: const TextStyle(fontSize: 12.5, color: _muted)),
                ],
                if (attendee.sharedInterests.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final interest in attendee.sharedInterests)
                        InterestChip(
                          label: interest.name,
                          // Its emoji: the server's, else the app's --
                          // never the server's placeholder word.
                          glyph: interestEmoji(
                              icon: interest.icon,
                              iconType: interest.iconType,
                              name: interest.name),
                          plain: true,
                          selected: true,
                          compact: true,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          _PersonMenu(
            attendee: attendee,
            onReport: () => reportContent(
              context,
              ref,
              target: ReportTarget.user(attendee.userId),
              what: 'person',
            ),
            onBlock: () => confirmAndBlock(
              context,
              ref,
              userId: attendee.userId,
              name: attendee.name.isEmpty ? 'this person' : attendee.name,
              avatarUrl: attendee.profilePicUrl,
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.attendee});

  final NetworkingAttendee attendee;

  @override
  Widget build(BuildContext context) {
    final picture = attendee.profilePicUrl;
    return CircleAvatar(
      radius: 24,
      backgroundColor: AppColors.softGrey,
      backgroundImage: picture != null
          ? appImageProvider(
              picture,
              privacy: ImagePrivacy.private,
              decodeWidth:
                  decodeWidthFor(48, 48, MediaQuery.devicePixelRatioOf(context)),
            )
          : null,
      onBackgroundImageError: picture != null ? (_, __) {} : null,
      child: picture == null
          ? Text(
              attendee.name.isNotEmpty ? attendee.name[0].toUpperCase() : '?',
              style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink),
            )
          : null,
    );
  }
}

/// Report or block someone, from their card.
class _PersonMenu extends StatelessWidget {
  final NetworkingAttendee attendee;
  final VoidCallback onReport;
  final VoidCallback onBlock;

  const _PersonMenu({
    required this.attendee,
    required this.onReport,
    required this.onBlock,
  });

  @override
  Widget build(BuildContext context) {
    // Without an id there is no one to report or block.
    if (attendee.userId <= 0) return const SizedBox.shrink();
    return PopupMenuButton<String>(
      key: ValueKey('person-menu-${attendee.userId}'),
      tooltip: 'More for ${attendee.name}',
      icon: const Icon(Icons.more_vert, color: Color(0xFF6B7280)),
      onSelected: (choice) {
        if (choice == 'report') onReport();
        if (choice == 'block') onBlock();
      },
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: 'report',
          child: ListTile(
            leading: Icon(Icons.flag_outlined),
            title: Text('Report'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: 'block',
          child: ListTile(
            leading: Icon(Icons.block),
            title: Text('Block'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }
}

/// Why the page has no one to show, and a way on when one could help.
class _Problem extends StatelessWidget {
  final String emoji;
  final String title;
  final String message;
  final VoidCallback? onRetry;
  final String retryLabel;
  final VoidCallback? onOpenEvent;

  const _Problem({
    required this.emoji,
    required this.title,
    required this.message,
    this.onRetry,
    this.retryLabel = 'Try again',
    this.onOpenEvent,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 48)),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 17, fontWeight: FontWeight.w700, color: _ink),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: _muted, height: 1.35),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 20),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.ink,
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                textStyle: const TextStyle(
                    fontFamily: 'DMSans',
                    fontSize: 15,
                    fontWeight: FontWeight.w600),
              ),
              child: Text(retryLabel),
            ),
          ],
          if (onOpenEvent != null) ...[
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onOpenEvent,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.ink,
                side: const BorderSide(color: AppColors.ink),
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                textStyle: const TextStyle(
                    fontFamily: 'DMSans',
                    fontSize: 15,
                    fontWeight: FontWeight.w600),
              ),
              child: const Text('Open the event'),
            ),
          ],
        ],
      ),
    );
  }
}
