import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:finnet/core/themes/app_colors.dart';
import 'package:finnet/features/events/domain/networking.dart';
import 'package:finnet/features/events/domain/registration_status.dart';
import 'package:finnet/features/events/presentation/providers/networking_provider.dart';
import 'package:finnet/features/events/presentation/utils/event_errors.dart';
import 'package:finnet/shared/widgets/pressable.dart';

/// Where People Like You opens for an event: `/events/{id}/people`.
String peopleLikeYouLocation(int eventId) => '/events/$eventId/people';

/// People Like You on the event page, near the top.
///
/// - Checked in, during the event and the hour after: a card into the
///   list, with how many here share your interests.
/// - Registered, before the event: "On the day, check in to see who shares
///   your interests."
/// - Registered, during it, not checked in: "Check in at the door to meet
///   people who share your interests."
/// - Anything else -- not registered, no ticket yet, the event doesn't
///   have it, or it has closed -- nothing at all.
///
/// It changes by itself when the event starts and when the list closes.
class PeopleLikeYouCard extends ConsumerStatefulWidget {
  const PeopleLikeYouCard({
    super.key,
    required this.eventId,
    required this.eventName,
    required this.status,
    required this.networking,
    required this.startsAt,
    required this.durationHours,
    this.revoked = false,
    this.now,
  });

  final int? eventId;
  final String? eventName;
  final RegistrationStatus status;

  /// The event's `networking`: whether its club's plan has People Like You.
  final bool? networking;
  final DateTime? startsAt;
  final double? durationHours;
  final bool revoked;

  /// The clock, for tests.
  final DateTime Function()? now;

  static const openKey = ValueKey('people-like-you-card');
  static const hintKey = ValueKey('people-like-you-hint');

  @override
  ConsumerState<PeopleLikeYouCard> createState() => _PeopleLikeYouCardState();
}

class _PeopleLikeYouCardState extends ConsumerState<PeopleLikeYouCard> {
  Timer? _next;

  DateTime _now() => (widget.now ?? DateTime.now)();

  @override
  void dispose() {
    _next?.cancel();
    super.dispose();
  }

  /// Wake up when the event starts or the list closes, whichever is next.
  void _wakeAtNextChange() {
    _next?.cancel();
    final now = _now();
    final changes = [
      widget.startsAt,
      networkingClosesAt(widget.startsAt, widget.durationHours),
    ].whereType<DateTime>().where((t) => t.isAfter(now)).toList()..sort();
    if (changes.isEmpty) return;
    final wait = changes.first.difference(now) + const Duration(seconds: 1);
    // A timer days long is pointless: the page is reopened long before.
    if (wait > const Duration(hours: 12)) return;
    _next = Timer(wait, () {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.eventId;
    if (id == null || id <= 0) return const SizedBox.shrink();
    final moment = networkingMomentFor(
      status: widget.status,
      networking: widget.networking,
      startsAt: widget.startsAt,
      durationHours: widget.durationHours,
      now: _now(),
      revoked: widget.revoked,
    );
    _wakeAtNextChange();
    switch (moment) {
      case NetworkingMoment.none:
        return const SizedBox.shrink();
      case NetworkingMoment.beforeEvent:
        return const _Hint(
          emoji: '🤝',
          text: 'On the day, check in to see who shares your interests.',
        );
      case NetworkingMoment.checkInNow:
        return const _Hint(
          emoji: '🚪',
          text: 'Check in at the door to meet people who share your '
              'interests.',
        );
      case NetworkingMoment.open:
        return _OpenCard(eventId: id, eventName: widget.eventName ?? '');
    }
  }
}

/// A quiet line for someone registered: what to do on the day.
class _Hint extends StatelessWidget {
  const _Hint({required this.emoji, required this.text});

  final String emoji;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Container(
        key: PeopleLikeYouCard.hintKey,
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
        decoration: BoxDecoration(
          color: AppColors.softGrey,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            _EmojiDisc(emoji),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                    fontSize: 13.5, height: 1.3, color: Color(0xFF1E1E1E)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Checked in, and the list is open: the way in, and how many are here.
class _OpenCard extends ConsumerWidget {
  const _OpenCard({required this.eventId, required this.eventName});

  final int eventId;
  final String eventName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final answer = ref.watch(networkingPeopleProvider(eventId));
    // The list says the event doesn't have it, or that it has closed: no
    // way in to a page that would only say so.
    final code = answer.hasError ? errorCodeOf(answer.error) : null;
    if (code == networkingUnavailableCode || code == networkingClosedCode) {
      return const SizedBox.shrink();
    }
    final people = answer.valueOrNull;
    final matches = people?.sharing.length;
    final line = switch (matches) {
      null => 'See who here shares your interests',
      0 => 'No one here shares your interests yet',
      1 => '1 person here shares your interests',
      _ => '$matches people here share your interests',
    };

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Pressable(
        child: Material(
          color: AppColors.paleYellow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppColors.border),
          ),
          child: InkWell(
            key: PeopleLikeYouCard.openKey,
            customBorder: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            onTap: () => context.push(peopleLikeYouLocation(eventId),
                extra: {'eventName': eventName}),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
              child: Row(
                children: [
                  const _EmojiDisc('🤝', fill: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'People like you',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E1E1E),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          line,
                          key: const ValueKey('people-like-you-count'),
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFF3D3D3D)),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward, color: AppColors.ink),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmojiDisc extends StatelessWidget {
  const _EmojiDisc(this.emoji, {this.fill = Colors.white});

  final String emoji;
  final Color fill;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
      child: Text(emoji,
          textScaler: TextScaler.noScaling,
          style: const TextStyle(fontSize: 19)),
    );
  }
}
