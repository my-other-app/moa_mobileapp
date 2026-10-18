import 'package:finnet/common/models/events/event_model.dart';
import 'package:finnet/core/error/either.dart';
import 'package:finnet/core/error/failures.dart';
import 'package:finnet/features/events/presentation/utils/registration_refusal.dart';
import 'package:finnet/features/payments/domain/payment_failures.dart';

/// What finishing the payment for a registration came to.
enum FinishPaymentResult {
  /// Paid: verified now, or already paid before. Refresh the event and its
  /// ticket.
  paid,

  /// The checkout was closed or the payment failed. The registration is
  /// still there, waiting.
  notCompleted,

  /// The event asks questions (or the profile lacks the details the
  /// registration needs), so the registration form has to be filled in to
  /// get back to the payment.
  needsForm,

  /// Registering again was refused -- the event filled up, say.
  /// [FinishPaymentOutcome.refusal] says how to say so.
  refused,

  /// The server won't take the payment because registration has closed.
  /// Only the server decides this: the deadline passing isn't enough, as an
  /// existing registration can still be paid for until the event ends.
  /// [FinishPaymentOutcome.refusal] has the words.
  closed,

  /// No order could be made. [FinishPaymentOutcome.failure] says why; an
  /// `UpdateAppToPayFailure` carries the website link and a
  /// `NothingToPayFailure` means nothing is owed after all.
  failed,
}

class FinishPaymentOutcome {
  final FinishPaymentResult result;
  final RegistrationRefusal? refusal;
  final Failure? failure;

  const FinishPaymentOutcome._(this.result, {this.refusal, this.failure});

  static const paid = FinishPaymentOutcome._(FinishPaymentResult.paid);
  static const notCompleted =
      FinishPaymentOutcome._(FinishPaymentResult.notCompleted);
  static const needsForm =
      FinishPaymentOutcome._(FinishPaymentResult.needsForm);

  factory FinishPaymentOutcome.refused(RegistrationRefusal refusal) =>
      FinishPaymentOutcome._(
        refusal.closed
            ? FinishPaymentResult.closed
            : FinishPaymentResult.refused,
        refusal: refusal,
      );

  factory FinishPaymentOutcome.failed(Failure failure) =>
      FinishPaymentOutcome._(FinishPaymentResult.failed, failure: failure);
}

/// `POST /events/registration/{eventId}/register` with [body]; the response
/// body.
typedef RegisterCall = Future<Map<String, dynamic>> Function(
  int eventId,
  Map<String, dynamic> body,
);

/// `RegistrationCheckout.pay`, bound to the payments repository.
typedef PayCall = Future<Result<bool>> Function({
  required int eventId,
  required String registrationId,
  required String name,
  required String email,
  required String phone,
});

/// Paying for a registration that already exists.
///
/// The order is `{source: "event_registration", payload: {event_id,
/// event_registration_id}}` on `?checkout=2`, as after a first registration,
/// and needs the registration's id. `/events/info/{id}` sends it as
/// `registration_id`; with it, the order is made straight away.
///
/// A server older than that field says a registration is unpaid but not
/// which one. Registering again gets it, the way the website does: for a
/// signed-in person's unpaid registration on a paid event the server answers
/// with that same registration -- `event_registration_id` and `pay_amount`
/// included -- instead of refusing, and changes nothing about it (the shelf
/// picks are kept when `store` is left out). That server checks the event's
/// required questions before it looks for the registration, so on that path
/// an event that asks any goes back through the form.
class FinishPayment {
  final RegisterCall register;
  final PayCall pay;

  const FinishPayment({required this.register, required this.pay});

  /// Whether the registration form has to be filled in to get to the payment.
  static bool needsForm({
    required List<AdditionalDetail> questions,
    required String name,
    required String email,
  }) =>
      questions.any((q) => q.requiredField) ||
      name.trim().length < 3 ||
      email.trim().isEmpty;

  Future<FinishPaymentOutcome> run({
    required int eventId,
    required List<AdditionalDetail> questions,
    required String name,
    required String email,
    String? phone,
    String? registrationId,
  }) async {
    final phoneNumber = phone?.trim() ?? '';
    final known = registrationId?.trim() ?? '';
    if (known.isNotEmpty) {
      // `registration_id` from /events/info: no need to register again, so
      // no questions to answer either.
      return _pay(
        eventId: eventId,
        registrationId: known,
        name: name.trim(),
        email: email.trim(),
        phone: phoneNumber,
      );
    }

    if (needsForm(questions: questions, name: name, email: email)) {
      return FinishPaymentOutcome.needsForm;
    }

    final Map<String, dynamic> registration;
    try {
      registration = await register(eventId, {
        'full_name': name.trim(),
        'email': email.trim(),
        if (phoneNumber.isNotEmpty) 'phone': phoneNumber,
        'additional_details': <String, String>{},
      });
    } catch (e) {
      final refusal = describeRegistrationError(e);
      // ALREADY_REGISTERED is the server's answer for a registration that is
      // paid (or free): there's a ticket, so the page only needs refreshing.
      if (refusal.action == RegistrationAction.viewTicket) {
        return FinishPaymentOutcome.paid;
      }
      return FinishPaymentOutcome.refused(refusal);
    }

    final due = registration['pay_amount'];
    final owed = due is num ? due.toDouble() : 0.0;
    if (owed <= 0) return FinishPaymentOutcome.paid;

    final found = registration['event_registration_id'];
    if (found is! String || found.isEmpty) {
      return FinishPaymentOutcome.failed(const ServerFailure(
        message: "We couldn't start the payment. Try again in a moment.",
      ));
    }

    return _pay(
      eventId: eventId,
      registrationId: found,
      name: _string(registration['full_name'], name),
      email: _string(registration['email'], email),
      phone: _string(registration['phone'], phoneNumber),
    );
  }

  Future<FinishPaymentOutcome> _pay({
    required int eventId,
    required String registrationId,
    required String name,
    required String email,
    required String phone,
  }) async {
    final paid = await pay(
      eventId: eventId,
      registrationId: registrationId,
      name: name,
      email: email,
      phone: phone,
    );
    if (paid.isLeft) {
      final failure = paid.left;
      if (failure is AlreadyPaidFailure) return FinishPaymentOutcome.paid;
      if (failure.code == RegistrationErrorCodes.registrationsClosed) {
        return FinishPaymentOutcome.refused(RegistrationRefusal(
          title: 'Registrations are closed',
          message: failure.message,
          closed: true,
        ));
      }
      return FinishPaymentOutcome.failed(failure);
    }
    return paid.right
        ? FinishPaymentOutcome.paid
        : FinishPaymentOutcome.notCompleted;
  }

  static String _string(Object? value, String fallback) =>
      value is String && value.trim().isNotEmpty ? value.trim() : fallback;
}
