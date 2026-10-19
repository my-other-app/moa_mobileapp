import 'package:flutter/material.dart';
import 'package:finnet/core/error/failures.dart';
import 'package:finnet/features/events/presentation/utils/registration_refusal.dart';
import 'package:finnet/features/payments/domain/payment_failures.dart';
import 'package:finnet/shared/utils/external_links.dart';

/// Says why a registration was refused, with its one way forward when there
/// is one. Resolves to that action when the person takes it.
Future<RegistrationAction?> showRegistrationRefusal(
  BuildContext context,
  RegistrationRefusal refusal,
) {
  return showDialog<RegistrationAction>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(refusal.title),
      content: Text(refusal.message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(refusal.action == null ? 'OK' : 'Not now'),
        ),
        if (refusal.action != null)
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF2C333D),
            ),
            onPressed: () => Navigator.of(context).pop(refusal.action),
            child: Text(refusal.actionLabel!),
          ),
      ],
    ),
  );
}

/// No order could be made, so nothing was charged. An event this build
/// can't pay (409 UPDATE_APP_TO_PAY) also offers its page on the website.
///
/// The words are [paymentFailureMessage]'s: the server's refusals (full,
/// ended, paused, sold out) in plain words.
void showPaymentFailure(BuildContext context, Failure failure) {
  final webUrl = failure is UpdateAppToPayFailure ? failure.webUrl : null;
  final uri = webUrl == null ? null : Uri.tryParse(webUrl);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(paymentFailureMessage(failure)),
      showCloseIcon: uri != null,
      action: uri == null
          ? null
          : SnackBarAction(
              label: 'Open website',
              // Paying on the website stays in the browser, where the
              // payment apps it hands over to are reachable. Never throws.
              onPressed: () => openExternally(uri),
            ),
    ),
  );
}
