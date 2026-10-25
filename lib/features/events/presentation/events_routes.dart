import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:finnet/common/models/events/event_model.dart';
import 'package:finnet/features/events/domain/event_page_rules.dart';
import 'package:finnet/features/events/presentation/pages/claim_offer_page.dart';
import 'package:finnet/features/events/presentation/pages/competition_page.dart';
import 'package:finnet/features/events/presentation/pages/event_form_page.dart';
import 'package:finnet/features/events/presentation/pages/feedback_survey_page.dart';
import 'package:finnet/features/events/presentation/pages/individual_event_page.dart';
import 'package:finnet/features/events/presentation/pages/networking_page.dart';
import 'package:finnet/shared/widgets/poster_hero.dart';

// The event routes batch B adds, and the builders for the two event routes
// app_router.dart (batch D's) already has.
//
// Batch D: spread [eventsRoutes] into the router's top-level `routes`, and
// use [buildEventPage] and [buildEventRegisterPage] as the builders of
// `/events/:eventId` and `/events/:eventId/register`, so a slug opens its
// event rather than event 0.

/// The `:eventId` (or `:eventRef`) path parameter: an event's id or slug.
String eventRefOf(GoRouterState state) {
  final params = state.pathParameters;
  return (params['eventId'] ?? params['eventRef'] ?? '').trim();
}

/// `/events/:eventId`: the event page, by id (`/events/42`) or by slug
/// (`/events/hack-night`).
///
/// extra (from a card): `status` ('registered', 'attended',
/// 'awaitingPayment', 'finishPayment'), `ticketUrl`, `certificateUrl`;
/// `posterHero` and `posterHint`, for the card's poster to fly in.
/// `?live=room|quiz|poll` (a "join now" push) opens the live room at once.
/// `?ticket_type={id}` (a link to a hidden ticket type) shows that type too.
Widget buildEventPage(BuildContext context, GoRouterState state) {
  final ref = eventRefOf(state);
  final extra = state.extra is Map ? state.extra as Map : const {};
  return IndividualEventPage(
    // A new page for a new event: the state of one is not the next one's.
    key: ValueKey('event-$ref'),
    eventId: eventIdOf(ref),
    eventRef: ref,
    initialStatus: extra['status'] as String?,
    initialTicketUrl: extra['ticketUrl'] as String?,
    initialCertificateUrl: extra['certificateUrl'] as String?,
    openLiveRoom: state.uri.queryParameters.containsKey('live'),
    posterHero: extra['posterHero'] as String?,
    posterHint: extra['posterHint'] as PosterHint?,
    linkedTicketTypeId: linkedTicketTypeOf(state),
  );
}

/// The hidden ticket type a link names (`?ticket_type=`), or the one the
/// event page hands the form (extra `linkedTicketType`); null for none.
int? linkedTicketTypeOf(GoRouterState state) {
  final extra = state.extra is Map ? state.extra as Map : const {};
  final given = extra['linkedTicketType'];
  if (given is int) return given;
  return int.tryParse(state.uri.queryParameters['ticket_type'] ?? '');
}

/// `/events/:eventId/register`: the registration form.
///
/// extra (from the event page): `additionalDetails` (the questions),
/// `hasFee`, `isOnline`, and the club's `clubName` and `clubUpdates` (it
/// offers "Get updates from `<club>` on WhatsApp"). Without them -- a link
/// straight to the form -- the form reads the event itself.
Widget buildEventRegisterPage(BuildContext context, GoRouterState state) {
  final ref = eventRefOf(state);
  final extra = state.extra is Map ? state.extra as Map : const {};
  final questions = extra['additionalDetails'];
  return EventFormPage(
    eventId: eventIdOf(ref),
    eventRef: ref,
    additionalDetails: questions is List<AdditionalDetail> ? questions : null,
    hasFee: extra['hasFee'] as bool?,
    isOnline: extra['isOnline'] as bool?,
    clubName: extra['clubName'] is String ? extra['clubName'] as String : null,
    offersClubUpdates:
        extra['clubUpdates'] is bool ? extra['clubUpdates'] as bool : null,
    linkedTicketTypeId: linkedTicketTypeOf(state),
  );
}

/// Route names, unique in the app's router.
abstract final class EventRouteNames {
  static const competition = 'eventCompetition';
  static const feedback = 'eventFeedback';
  static const people = 'eventPeople';
  static const claim = 'waitlistClaim';
}

/// Batch B's new routes, top level (each opens over the tabs):
///
/// - `/events/:eventRef/compete` -- "Your team" (the website's address too);
///   needs an account.
/// - `/feedback/:eventId/:registrationId?k=…` -- the feedback survey, from
///   the link in the email (the website's address too); needs no account,
///   the link's key is the proof.
/// - `/events/:eventRef/people` -- People Like You: from the event page's
///   card, Home's "You're at" banner and the check-in push (`open:
///   people`); needs an account. extra: `eventName`, shown while it loads.
/// - `/claim/:token` -- a place offered from a waiting list (the website's
///   address too: the offer's email, WhatsApp and push link to it); needs
///   no account, the token is the proof.
final List<RouteBase> eventsRoutes = [
  GoRoute(
    path: '/claim/:token',
    name: EventRouteNames.claim,
    builder: (context, state) {
      final token = state.pathParameters['token'] ?? '';
      return ClaimOfferPage(key: ValueKey('claim-$token'), token: token);
    },
  ),
  GoRoute(
    path: '/events/:eventRef/compete',
    name: EventRouteNames.competition,
    builder: (context, state) {
      final extra = state.extra is Map ? state.extra as Map : const {};
      return CompetitionPage(
        eventRef: eventRefOf(state),
        eventName: extra['eventName'] as String?,
      );
    },
  ),
  GoRoute(
    path: '/events/:eventRef/people',
    name: EventRouteNames.people,
    builder: (context, state) {
      final ref = eventRefOf(state);
      final extra = state.extra is Map ? state.extra as Map : const {};
      return NetworkingPage(
        key: ValueKey('people-$ref'),
        eventId: eventIdOf(ref) ?? 0,
        eventRef: ref,
        eventName: extra['eventName'] as String? ?? '',
      );
    },
  ),
  GoRoute(
    path: '/feedback/:eventId/:registrationId',
    name: EventRouteNames.feedback,
    builder: (context, state) => FeedbackSurveyPage(
      eventId: eventIdOf(state.pathParameters['eventId'] ?? '') ?? 0,
      registrationId: state.pathParameters['registrationId'] ?? '',
      surveyKey: state.uri.queryParameters['k'] ?? '',
    ),
  ),
];
