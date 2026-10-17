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
