import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:finnet/core/themes/app_colors.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/events/domain/entities/saved_ticket.dart';
import 'package:finnet/features/events/domain/networking.dart';
import 'package:finnet/features/events/domain/registration_status.dart';
import 'package:finnet/features/events/presentation/providers/networking_provider.dart';
import 'package:finnet/features/events/presentation/providers/saved_tickets_provider.dart';
import 'package:finnet/features/events/presentation/widgets/networking/people_like_you_card.dart';
import 'package:finnet/shared/widgets/pressable.dart';

/// How early someone checked in counts as being at the event.
const _early = Duration(hours: 2);

/// The ticket of the event the reader is checked in to, that is on at
/// [now] (or starts within [_early]) and whose People Like You is open, if
/// any: what the phone already knows from their saved tickets, so it costs
/// no request to find.
SavedTicket? checkedInNow(List<SavedTicket> tickets, DateTime now) {
  for (final ticket in tickets) {
    final starts = ticket.startsAt;
    if (ticket.revoked ||
        ticket.status != RegistrationStatus.attended ||
        starts == null ||
        now.isBefore(starts.subtract(_early))) {
      continue;
    }
    final moment = networkingMomentFor(
      status: ticket.status,
      networking: null,
      startsAt: ticket.startsAt,
      durationHours: ticket.durationHours,
      now: now,
    );
    if (moment == NetworkingMoment.open) return ticket;
  }
  return null;
}

/// "You're at {event} · People like you", slim, at the top of DISCOVER --
/// while the reader is checked in to an event that is on.
///
/// Shown once the list has answered, so it never leads to a page that only
/// says the event doesn't have People Like You. Nothing signed out, and
/// nothing on any other day.
class AtEventBanner extends ConsumerWidget {
  const AtEventBanner({super.key, this.now});

  /// The clock, for tests.
  final DateTime Function()? now;

  static const bannerKey = ValueKey('at-event-banner');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(isAuthenticatedProvider)) return const SizedBox.shrink();
    final ticket = checkedInNow(
        ref.watch(savedTicketsProvider), (now ?? DateTime.now)());
    if (ticket == null) return const SizedBox.shrink();
    final people =
        ref.watch(networkingPeopleProvider(ticket.eventId)).valueOrNull;
    if (people == null) return const SizedBox.shrink();
    final matches = people.sharing.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Pressable(
        child: Material(
          color: AppColors.paleYellow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.border),
          ),
          child: InkWell(
            key: bannerKey,
            customBorder:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onTap: () => context.push(peopleLikeYouLocation(ticket.eventId),
                extra: {'eventName': ticket.eventName}),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
              child: Row(
                children: [
                  const Text('📍',
                      textScaler: TextScaler.noScaling,
                      style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text.rich(
                      TextSpan(children: [
                        const TextSpan(text: 'You’re at '),
                        TextSpan(
                          text: ticket.eventName,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        TextSpan(
                          text: matches > 0
                              ? ' · $matches ${matches == 1 ? 'person' : 'people'} like you'
                              : ' · People like you',
                        ),
                      ]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13.5, color: Color(0xFF1E1E1E)),
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.ink),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
