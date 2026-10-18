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
