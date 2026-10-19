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

/// Asked for after the password, for an account with two-step verification.
const String twoStepMessage =
    'This account uses two-step verification. Enter the code from your '
    'authenticator app.';

/// The authenticator code (or recovery code) was not right.
const String twoStepWrongCodeMessage =
    "That code isn't right. Check your authenticator app and try again, or "
    'use a recovery code.';

/// An email and password that do not go together. Said without saying which
/// one is wrong, as the server does.
const String wrongPasswordMessage =
    "That email and password don't match. Check them and try again, or tap "
    'Forgot password.';

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
    // The email sign-in asks for the code itself (LoginNeedsTwoStep); these
    // are the words for anywhere else they turn up.
    case 'TOTP_REQUIRED':
      return twoStepMessage;
    case 'TOTP_INVALID':
      return twoStepWrongCodeMessage;
  }
  return extractErrorMessage(error, defaultMessage: defaultMessage);
}

/// What the sign-in screen says when an email sign-in failed: as
/// [signInErrorMessage], except that a plain 401 -- the password check --
/// reads as [wrongPasswordMessage] rather than the server's "Incorrect
/// username or password".
String emailSignInErrorMessage(Object? error) {
  if (statusCodeOf(error) == 401 && errorCodeOf(error) == null) {
    return wrongPasswordMessage;
  }
  return signInErrorMessage(error);
}
