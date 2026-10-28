import 'package:intl/intl.dart';
import 'package:finnet/core/utils/json_read.dart';
import 'package:finnet/features/events/domain/registration_request.dart';
import 'package:finnet/features/events/domain/ticketing.dart';
import 'package:finnet/features/events/presentation/utils/event_errors.dart';

/// What a refused registration offers next.
enum RegistrationAction {
  /// Already registered: open the ticket.
  viewTicket,

  /// Registered for a paid event and not paid yet: pay for it.
  finishPayment,

  /// Sold out, with its waiting list open: join it instead.
  joinWaitlist,
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

  /// The event confirms each registration ("Confirm each registration"):
  /// the club declined this person's request, or the request wasn't sent
  /// as one ([ApprovalErrorCodes]).
  static const requestDeclined = ApprovalErrorCodes.requestDeclined;
  static const approvalRequired = ApprovalErrorCodes.approvalRequired;

  /// Add-ons sent with a request (422): the club turned "Confirm each
  /// registration" on after the form loaded its shelf.
  static const addOnsNotAllowed = ApprovalErrorCodes.addOnsNotAllowed;
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
        RegistrationAction.joinWaitlist => 'Join the waiting list',
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
///
/// [approval]: the form sent a request (the club confirms each place).
/// Such an event has no waiting list, so none is offered, whatever the
/// refusal says.
RegistrationRefusal describeRegistrationError(Object? error,
    {bool approval = false}) {
  final code = errorCodeOf(error);
  final said = serverMessageOf(error);

  if (isCancelledRefusal(error)) return cancelledRefusal;
  final ticketing = _ticketingRefusal(error, code, approval: approval);
  if (ticketing != null) return ticketing;

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
      return offersWaitlist(error, approval: approval)
          ? _fullWithWaitlist
          : _full;
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
    case RegistrationErrorCodes.requestDeclined:
      return requestDeclinedRefusal;
    case RegistrationErrorCodes.approvalRequired:
      return approvalRequiredRefusal;
    case RegistrationErrorCodes.addOnsNotAllowed:
      return addOnsNotAllowedRefusal;
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

const _fullWithWaitlist = RegistrationRefusal(
  title: 'This event is full',
  message: "Every place has been taken. Join the waiting list and we'll tell "
      'you if one opens up.',
  action: RegistrationAction.joinWaitlist,
);

/// The club declined this person's request for a place before (409
/// REQUEST_DECLINED): asking again is refused unless the club reopens it.
const requestDeclinedRefusal = RegistrationRefusal(
  title: "The club couldn't offer you a place",
  message: "The club confirms each place at this event, and couldn't offer "
      "you one this time, so you can't ask again.",
  closed: true,
);

/// The event confirms each place, and the registration wasn't sent as a
/// request (409 APPROVAL_REQUIRED). This app always says it takes one, so
/// it is said for the odd path that doesn't (paying an older registration).
const approvalRequiredRefusal = RegistrationRefusal(
  title: 'The club confirms each place',
  message: 'This event needs the club to confirm each place. Go back to the '
      'event and tap Request a place.',
);

/// Add-ons sent with a request (422 ADD_ONS_NOT_ALLOWED): the club now
/// confirms each place, and a request holds no add-ons. The form takes the
/// picks off and asks for a place when this comes back.
const addOnsNotAllowedRefusal = RegistrationRefusal(
  title: 'The club confirms each place now',
  message: "A request for a place can't include add-ons, so they've been "
      'taken off. Send the form again to ask for a place.',
);

/// The club called the event off: registering (REGISTRATIONS_CLOSED with
/// `closed_reason: "cancelled"`) and paying (EVENT_CANCELLED) are refused.
const cancelledRefusal = RegistrationRefusal(
  title: 'This event was cancelled',
  message: "The organisers called it off, so it isn't taking registrations "
      'or payments. Nothing was charged.',
  closed: true,
);

/// A refusal about the ticket type (docs/TICKETING.md §6); null for any
/// other. A discount code's refusal is said under its field instead
/// ([discountCodeProblem]); here it is the dialog's words for a screen
/// without one.
RegistrationRefusal? _ticketingRefusal(Object? error, String? code,
    {bool approval = false}) {
  switch (code) {
    case TicketingErrorCodes.ticketTypeRequired:
      return const RegistrationRefusal(
        title: 'Choose a ticket',
        message: 'This event sells more than one kind of ticket. Choose one, '
            'then register.',
      );
    case TicketingErrorCodes.ticketTypeNotFound:
      return const RegistrationRefusal(
        title: "That ticket isn't on sale",
        message: 'It may have been taken off sale. Choose another ticket.',
      );
    case TicketingErrorCodes.ticketTypeNotOnSale:
      final errors = apiExceptionOf(error)?.errors;
      final opens = jsonDate(errors?['opens_at']);
      if (errors?['closed_reason'] == 'not_started') {
        return RegistrationRefusal(
          title: "This ticket isn't on sale yet",
          message: opens == null
              ? 'Come back once it goes on sale.'
              : 'It goes on sale '
                  '${DateFormat("EEE d MMM 'at' h:mm a").format(opens.toLocal())}.',
        );
      }
      return const RegistrationRefusal(
        title: 'Sales for this ticket have ended',
        message: 'Choose another ticket, if there is one.',
      );
    case TicketingErrorCodes.ticketTypeSoldOut:
      return offersWaitlist(error, approval: approval)
          ? const RegistrationRefusal(
              title: 'This ticket is sold out',
              message: "Join its waiting list and we'll tell you if a place "
                  'opens up.',
              action: RegistrationAction.joinWaitlist,
            )
          : const RegistrationRefusal(
              title: 'This ticket is sold out',
              message: 'Choose another ticket, if there is one.',
            );
    case TicketingErrorCodes.ticketTypeLimit:
      return const RegistrationRefusal(
        title: "You've reached this ticket's limit",
        message: 'You already hold as many of these tickets as one person can.',
      );
  }
  final problem = discountCodeProblem(error);
  if (problem != null && code != null) {
    return RegistrationRefusal(title: 'Check your discount code', message: problem);
  }
  return null;
}

/// "Hack Night tee M is sold out" -> "Hack Night tee M is sold out."
String _sentence(String text) {
  final t = text.trim();
  return RegExp(r'[.!?]$').hasMatch(t) ? t : '$t.';
}
