import 'package:finnet/core/utils/error_utils.dart';
import 'package:finnet/core/utils/json_read.dart';

/// The server's `error_code`s for profiles and the network
/// (feature-register `profiles-networking-contract.md`).
const handleTakenCode = 'HANDLE_TAKEN';
const handleInvalidCode = 'HANDLE_INVALID';
const handleReservedCode = 'HANDLE_RESERVED';
const linkInvalidCode = 'LINK_INVALID';
const cannotSaveSelfCode = 'CANNOT_SAVE_SELF';
const profileCodeInactiveCode = 'PROFILE_CODE_INACTIVE';
const profileScanningOffCode = 'PROFILE_SCANNING_OFF';
const rateLimitedCode = 'RATE_LIMITED';

// Beyond the contract (its "Backend notes").
const orgNotFoundCode = 'ORG_NOT_FOUND';
const projectLimitCode = 'PROJECT_LIMIT';
const orderInvalidCode = 'ORDER_INVALID';
const notAnImageCode = 'NOT_AN_IMAGE';
const notFoundCode = 'NOT_FOUND';

/// "Wait a minute", or the seconds the server said (`errors.retry_after`).
String _wait(Object? error) {
  final seconds = jsonInt(apiExceptionOf(error)?.errors?['retry_after']);
  if (seconds == null || seconds <= 0 || seconds >= 90) return 'Wait a minute';
  return 'Wait $seconds seconds';
}

/// Words for a save that didn't happen.
String saveErrorMessage(Object? error) {
  switch (errorCodeOf(error)) {
    case cannotSaveSelfCode:
      return "That's your own code.";
    case profileCodeInactiveCode:
      return 'This code is no longer active. Ask them to show their '
          'current code.';
    case profileScanningOffCode:
      // Only saves by code or QR are refused: their profile link still works.
      return "They've turned off saving by QR. Ask for their profile link "
          'instead.';
    case rateLimitedCode:
      return "You're saving people very fast. ${_wait(error)}, then try again.";
  }
  final status = statusCodeOf(error);
  if (status == 404) return "We couldn't find this person.";
  if (status == 410) {
    return 'This code is no longer active. Ask them to show their current '
        'code.';
  }
  if (status == 429) {
    return "You're saving people very fast. ${_wait(error)}, then try again.";
  }
  return extractErrorMessage(error,
      defaultMessage: "Couldn't save them. Try again.");
}

/// Words for a change to the person's own profile -- links, projects,
/// their pictures and order -- that didn't happen.
String profileEditErrorMessage(Object? error, {required String fallback}) {
  switch (errorCodeOf(error)) {
    case linkInvalidCode:
      return "A link isn't allowed: use an https:// web link of up to 500 "
          'characters, at most 10 links.';
    case projectLimitCode:
      return 'A profile holds 12 projects. Delete one to add another.';
    case orderInvalidCode:
      return 'Your projects changed meanwhile. Here they are as saved; try '
          'again.';
    case notAnImageCode:
      return "That file isn't a picture. Choose a photo.";
    case orgNotFoundCode:
      return "We couldn't find that organisation. Pick it again.";
    case notFoundCode:
      return "That isn't there any more. Pull down to refresh.";
    case rateLimitedCode:
      return 'Too many changes at once. ${_wait(error)}, then try again.';
  }
  return handleErrorMessage(error) ??
      extractErrorMessage(error, defaultMessage: fallback);
}

/// Words for a handle the server refused.
String? handleErrorMessage(Object? error) => switch (errorCodeOf(error)) {
      handleTakenCode => 'Someone already has that handle.',
      handleReservedCode => 'That one is reserved.',
      handleInvalidCode => 'Letters, numbers, dots, dashes and underscores; '
          '3 to 30 characters.',
      _ => null,
    };
