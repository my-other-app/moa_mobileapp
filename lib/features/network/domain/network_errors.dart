import 'package:finnet/core/utils/error_utils.dart';

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

/// Words for a save that didn't happen.
String saveErrorMessage(Object? error) {
  switch (errorCodeOf(error)) {
    case cannotSaveSelfCode:
      return "That's your own code.";
    case profileCodeInactiveCode:
      return 'This code is no longer active. Ask them to show their '
          'current code.';
    case profileScanningOffCode:
      return "They've switched saving by QR off.";
    case rateLimitedCode:
      return "You're saving people very fast. Wait a minute, then try again.";
  }
  final status = statusCodeOf(error);
  if (status == 404) return "We couldn't find this person.";
  if (status == 410) {
    return 'This code is no longer active. Ask them to show their current '
        'code.';
  }
  if (status == 429) {
    return "You're saving people very fast. Wait a minute, then try again.";
  }
  return extractErrorMessage(error,
      defaultMessage: "Couldn't save them. Try again.");
}

/// Words for a handle the server refused.
String? handleErrorMessage(Object? error) => switch (errorCodeOf(error)) {
      handleTakenCode => 'Someone already has that handle.',
      handleReservedCode => 'That one is reserved.',
      handleInvalidCode => 'Letters, numbers, dots, dashes and underscores; '
          '3 to 30 characters.',
      _ => null,
    };
