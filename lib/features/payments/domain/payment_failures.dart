import 'package:finnet/core/error/failures.dart';

/// The server's `error_code` for an order this build cannot pay.
const updateAppToPayCode = 'UPDATE_APP_TO_PAY';

/// 409 UPDATE_APP_TO_PAY: the event is paid into its club's own Razorpay
/// account and the request did not say it can open checkout with the order's
/// own key. This build always says so (`?checkout=2`), so it should never see
/// this; an older build does, and is pointed at the website.
class UpdateAppToPayFailure extends Failure {
  /// The event's page on the website, where it can be paid instead.
  final String? webUrl;

  const UpdateAppToPayFailure({
    super.message =
        'Update the MyOtherApp app to pay for this event, or pay on the website.',
    this.webUrl,
  }) : super(code: updateAppToPayCode);

  @override
  List<Object?> get props => [message, code, webUrl];
}

/// The server's `error_code` for an order on a registration already paid.
const alreadyPaidCode = 'ALREADY_PAID';

/// The server's `error_code` for an order with nothing left to pay.
const nothingToPayCode = 'NOTHING_TO_PAY';

/// 409 ALREADY_PAID: the registration was paid -- in another tab, on the
/// website, or by a checkout whose answer this phone never heard. Nothing is
/// owed, so a caller treats it as a payment that went through and refreshes.
class AlreadyPaidFailure extends Failure {
  const AlreadyPaidFailure({
    super.message = 'This registration is already paid for.',
  }) : super(code: alreadyPaidCode);
}

/// 422 NOTHING_TO_PAY: the registration owes nothing, so there is no order to
/// open checkout with.
class NothingToPayFailure extends Failure {
  const NothingToPayFailure({
    super.message = "There's nothing left to pay for this registration.",
  }) : super(code: nothingToPayCode);
}

/// The server's `error_code` when an order's event has ended.
const eventEndedCode = 'EVENT_ENDED';

/// The server's `error_code` when the club cancelled the event (409): its
/// tickets can no longer be paid for.
const eventCancelledCode = 'EVENT_CANCELLED';

/// The server's `error_code` when the event's paid places are all taken.
const eventFullCode = 'EVENT_FULL';

/// The server's `error_code` when something picked from the shelf went.
const soldOutCode = 'SOLD_OUT';

/// The server's `error_code` while the club's own payment account is
/// paused or broken (503).
const gatewayUnavailableCode = 'GATEWAY_UNAVAILABLE';

/// The server's `error_code` for an order on a registration it can't find.
const registrationNotFoundCode = 'REGISTRATION_NOT_FOUND';

/// The server's `error_code` for a payment it can't find at Razorpay.
const paymentNotFoundCode = 'PAYMENT_NOT_FOUND';

/// The `code` of [InAppSaleBlockedFailure].
const inAppSaleBlockedCode = 'IN_APP_SALE_BLOCKED';

/// A paid online event on an iPhone: the app doesn't sell it, so no order
/// is made and no checkout opens (see `canSellInApp`).
class InAppSaleBlockedFailure extends Failure {
  const InAppSaleBlockedFailure({
    super.message = "This online event can't be bought in the iOS app",
  }) : super(code: inAppSaleBlockedCode);
}

/// What a person reads when a payment couldn't start: the server's refusals
/// in plain words, by their `error_code`; anything else as it came.
String paymentFailureMessage(Failure failure) {
  switch (failure.code) {
    case eventFullCode:
      return 'This event is full: every paid place has been taken.';
    case eventEndedCode:
      return 'This event is over, so it can no longer be paid for.';
    case eventCancelledCode:
      return 'This event was cancelled, so it can no longer be paid for. '
          'Nothing was charged.';
    case soldOutCode:
      // The server names what went: "Hack Night tee M is sold out".
      final said = failure.message.trim();
      if (said.toLowerCase().contains('sold out')) {
        final sentence = RegExp(r'[.!?]$').hasMatch(said) ? said : '$said.';
        return '$sentence Change your picks and try again.';
      }
      return 'Something you picked has sold out. Change your picks and try again.';
    case gatewayUnavailableCode:
      return 'Payments for this event are paused right now. Try again in a '
          'little while.';
    case registrationNotFoundCode:
      return "We couldn't find your registration. Register again to pay.";
    case paymentNotFoundCode:
      return "We couldn't confirm that payment yet. If money left your account, "
          "it will show here once it's confirmed.";
    case alreadyPaidCode:
      return const AlreadyPaidFailure().message;
    case nothingToPayCode:
      return const NothingToPayFailure().message;
  }
  return failure.message;
}
