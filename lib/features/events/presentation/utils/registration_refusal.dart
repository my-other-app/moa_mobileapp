import 'package:intl/intl.dart';
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

  /// Signed in, the email sent wasn't the account's.
  static const emailMismatch = 'EMAIL_MISMATCH';

  /// The shelf: the event stopped selling merchandise, an item went or is
  /// not for this person, a size is missing, or an item is there twice.
  static const storeClosed = 'STORE_CLOSED';
  static const itemUnavailable = 'ITEM_UNAVAILABLE';
  static const sizeRequired = 'SIZE_REQUIRED';
  static const itemRepeated = 'ITEM_REPEATED';

  /// An answer to the event's own questions was refused: required and
  /// missing, not one of the options, or not a number, email address, web
  /// address or date where the question asks for one. `errors` maps each
  /// question's key to what is wrong with its answer.
  static const invalidAnswers = 'INVALID_ANSWERS';
}

/// What the server said is wrong with each answer, by question key, when it
/// refused the registration for its answers (INVALID_ANSWERS) -- only the
/// questions in [questionKeys], the ones this form shows. Null when the
/// refusal is something else, or names no question the form can point at
/// (an answer set too large, say), which is then said as any other refusal.
Map<String, String>? invalidAnswersOf(
    Object? error, Iterable<String> questionKeys) {
  if (errorCodeOf(error) != RegistrationErrorCodes.invalidAnswers) return null;
  final errors = apiExceptionOf(error)?.errors;
  if (errors == null) return null;
  final asked = questionKeys.toSet();
  final found = <String, String>{
    for (final entry in errors.entries)
      if (asked.contains(entry.key) &&
          entry.value is String &&
          (entry.value as String).trim().isNotEmpty)
        entry.key: (entry.value as String).trim(),
  };
  return found.isEmpty ? null : found;
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
      // Not open yet: `errors.closed_reason` is "not_started", with when it
      // opens. Asking again later will work, so it isn't "closed".
      final opens = _notStartedUntil(error);
      if (opens != null) {
        return RegistrationRefusal(
          title: "Registration hasn't opened yet",
          message: 'Registration opens ${DateFormat("EEE d MMM 'at' h:mm a").format(opens.toLocal())}. '
              'Come back then to register.',
        );
      }
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
    case RegistrationErrorCodes.emailMismatch:
      return const RegistrationRefusal(
        title: "That email isn't your account's",
        message:
            'Register with the email you signed in with, or sign in with the other account.',
      );
    case RegistrationErrorCodes.storeClosed:
      return const RegistrationRefusal(
        title: 'Merchandise is off sale',
        message:
            "This event isn't selling merchandise any more. Take your picks off and register.",
      );
    case RegistrationErrorCodes.itemUnavailable:
    case RegistrationErrorCodes.sizeRequired:
    case RegistrationErrorCodes.itemRepeated:
      return RegistrationRefusal(
        title: 'Check your picks',
        message: said != null
            ? '${_sentence(said)} Change your picks and try again.'
            : 'One of your picks needs changing. Change it and try again.',
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

/// When registration opens, for a refusal because it hasn't
/// (`errors: {closed_reason: "not_started", opens_at}`); null otherwise.
DateTime? _notStartedUntil(Object? error) {
  final errors = apiExceptionOf(error)?.errors;
  if (errors == null || errors['closed_reason'] != 'not_started') return null;
  final at = errors['opens_at'];
  return at is String ? DateTime.tryParse(at) : null;
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
