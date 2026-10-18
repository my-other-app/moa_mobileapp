import 'package:finnet/core/network/api_exception.dart';
import 'package:finnet/core/utils/error_utils.dart';

/// Thrown when an email sign-in turns out to be a club's account.
///
/// `/auth/token` gives a club's email and password a session in the app as
/// readily as anyone's, and the app then failed at the profile check with
/// "Profile error: Not Authorized" over a spinner that never stopped. Club
/// accounts run the clubs dashboard; the app is for attendees.
class ClubAccountSignIn implements Exception {
  const ClubAccountSignIn();
}

const String clubAccountMessage =
    'This is a club account. Club accounts sign in on the clubs dashboard, '
    'not in the app. To attend events, sign in with your personal account.';

const String twoStepMessage =
    "This account uses two-step verification, which the app doesn't support "
    'yet.';

const String signInFailedMessage = "We couldn't sign you in. Please try again.";

/// What the sign-in screen says when signing in failed.
///
/// The codes sign-in can meet get a sentence that says what to do; anything
/// else reads as the server's own message, or friendly copy for a dropped
/// connection or a server error -- never the exception's `toString()`, which
/// is what the screen used to show ("Error: ApiException: ...").
String signInErrorMessage(
  Object? error, {
  String defaultMessage = signInFailedMessage,
}) {
  if (error is ClubAccountSignIn) return clubAccountMessage;
  switch (errorCodeOf(error)) {
    case 'ACCOUNT_SUSPENDED':
      return ApiException.accountSuspendedMessage;
    case 'CLUB_NOT_VERIFIED':
    case 'CLUB_UNAVAILABLE':
      return clubAccountMessage;
    // The app has no field for the code. TOTP_INVALID cannot happen while it
    // sends none, but would mean the same thing.
    case 'TOTP_REQUIRED':
    case 'TOTP_INVALID':
      return twoStepMessage;
  }
  return extractErrorMessage(error, defaultMessage: defaultMessage);
}
