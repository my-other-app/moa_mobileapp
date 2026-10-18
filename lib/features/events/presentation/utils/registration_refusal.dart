import 'package:finnet/features/events/presentation/utils/event_errors.dart';

/// What a refused registration offers next.
enum RegistrationAction {
  /// Already registered: open the ticket.
  viewTicket,

  /// Registered for a paid event and not paid yet: pay for it.
  finishPayment,
}

/// The `error_code`s `POST /events/registration/{id}/register` refuses with.
abstract final class RegistrationErrorCodes {
  static const alreadyRegistered = 'ALREADY_REGISTERED';
  static const awaitingPayment = 'REGISTRATION_AWAITING_PAYMENT';
  static const registrationsClosed = 'REGISTRATIONS_CLOSED';
  static const eventFull = 'EVENT_FULL';
  static const soldOut = 'SOLD_OUT';
  static const clubEmail = 'CLUB_EMAIL';
}

/// A refused registration, said for a person: what happened, and the one
/// thing to do about it when there is one.
class RegistrationRefusal {
  final String title;
  final String message;
  final RegistrationAction? action;

  /// Registration is closed: the deadline passed, or the club's plan stops
  /// it. Asking again won't change that.
  final bool closed;

  const RegistrationRefusal({
    required this.title,
    required this.message,
    this.action,
    this.closed = false,
  });

  /// The button for [action].
  String? get actionLabel => switch (action) {
        RegistrationAction.viewTicket => 'View ticket',
        RegistrationAction.finishPayment => 'Finish payment',
        null => null,
      };
}

final _eventFull = RegExp(r'event\s+is\s+full', caseSensitive: false);
final _alreadyRegistered =
    RegExp(r'already\s+registered', caseSensitive: false);
final _deadlinePassed = RegExp(
    r'deadline\s+has\s+passed|registrations?\s+(is\s+|are\s+)?closed',
    caseSensitive: false);

/// Sorts a refusal from the register call by its `error_code`.
///
/// "Event is full" has been refused without a code for as long as the app
/// has existed, so its words are matched too; so are "already registered"
/// and "Registration deadline has passed" from a server older than the
/// codes.
RegistrationRefusal describeRegistrationError(Object? error) {
  final code = errorCodeOf(error);
  final said = serverMessageOf(error);

  switch (code) {
    case RegistrationErrorCodes.alreadyRegistered:
      return const RegistrationRefusal(
        title: "You're already registered",
        message: 'You already have a ticket for this event.',
        action: RegistrationAction.viewTicket,
      );
    case RegistrationErrorCodes.awaitingPayment:
      return const RegistrationRefusal(
        title: 'Your registration is waiting for payment',
        message:
            "You've registered for this event but haven't paid yet. Finish the payment to get your ticket.",
        action: RegistrationAction.finishPayment,
      );
    case RegistrationErrorCodes.registrationsClosed:
      return const RegistrationRefusal(
        title: 'Registrations are closed',
        message: "This event isn't taking more registrations right now.",
        closed: true,
      );
    case RegistrationErrorCodes.eventFull:
      return _full;
    case RegistrationErrorCodes.soldOut:
      return RegistrationRefusal(
        title: 'Sold out',
        message: said != null
            ? '${_sentence(said)} Change your picks and try again.'
            : 'Something you picked has sold out. Change your picks and try again.',
      );
    case RegistrationErrorCodes.clubEmail:
      return const RegistrationRefusal(
        title: "This email belongs to a club",
        message:
            "This email belongs to a club's account. Sign in with your own account to register.",
      );
  }

  if (said != null && _eventFull.hasMatch(said)) return _full;
  if (said != null && _deadlinePassed.hasMatch(said)) {
    return RegistrationRefusal(
      title: 'Registrations are closed',
      message: _sentence(said),
      closed: true,
    );
  }
  if (said != null && _alreadyRegistered.hasMatch(said)) {
    return const RegistrationRefusal(
      title: "You're already registered",
      message: 'You already have a ticket for this event.',
      action: RegistrationAction.viewTicket,
    );
  }

  return RegistrationRefusal(
    title: "We couldn't register you",
    message: readableError(
      error,
      fallback: 'Registration failed. Please try again.',
    ),
  );
}

const _full = RegistrationRefusal(
  title: 'This event is full',
  message: 'Every place at this event has been taken.',
);

/// "Hack Night tee M is sold out" -> "Hack Night tee M is sold out."
String _sentence(String text) {
  final t = text.trim();
  return RegExp(r'[.!?]$').hasMatch(t) ? t : '$t.';
}
