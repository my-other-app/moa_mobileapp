import 'package:flutter/material.dart';
import 'package:finnet/features/payments/payment_confirmation.dart';

/// Shows [ConfirmingPaymentDialog] while [work] -- confirming a payment
/// Razorpay took -- runs, and answers what it came to. Paid or removed
/// close it at once; still confirming leaves it up, saying so, until OK.
Future<CheckoutResult> showConfirmingPayment(
    BuildContext context, Future<CheckoutResult> work) async {
  if (!context.mounted) return work;
  final navigator = Navigator.of(context, rootNavigator: true);
  final route = DialogRoute<void>(
    context: context,
    barrierDismissible: false,
    themes: InheritedTheme.capture(from: context, to: navigator.context),
    builder: (_) => ConfirmingPaymentDialog(work: work),
  );
  final closed = navigator.push(route);
  final CheckoutResult result;
  try {
    result = await work;
  } catch (_) {
    if (route.isActive) navigator.removeRoute(route);
    rethrow;
  }
  if (result == CheckoutResult.confirming) {
    // Up until the person has read it.
    await closed;
  } else if (route.isActive) {
    navigator.removeRoute(route);
  }
  return result;
}

/// "We're confirming your payment": over the screen while the app tells
/// the server about a payment Razorpay took, and keeps asking when the
/// answer doesn't come -- so nobody taps Pay again meanwhile. It can't be
/// dismissed while it waits; when the payment is still being confirmed at
/// the end it says so, with OK.
class ConfirmingPaymentDialog extends StatelessWidget {
  const ConfirmingPaymentDialog({super.key, required this.work});

  final Future<CheckoutResult> work;

  static const okKey = ValueKey('confirming-payment-ok');
  static const title = "We're confirming your payment";
  static const waiting = 'Razorpay says your payment went through. We are '
      "checking it now; this can take a few seconds. Please don't pay "
      'again.';

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CheckoutResult>(
      future: work,
      builder: (context, snapshot) {
        final stillConfirming =
            snapshot.connectionState == ConnectionState.done &&
                snapshot.data == CheckoutResult.confirming;
        final waitingNow = snapshot.connectionState != ConnectionState.done;
        return PopScope(
          canPop: stillConfirming,
          child: AlertDialog(
            title: const Text(title),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(stillConfirming ? paymentConfirmingMessage : waiting),
                if (waitingNow) ...[
                  const SizedBox(height: 20),
                  const Center(child: CircularProgressIndicator()),
                ],
              ],
            ),
            actions: [
              if (stillConfirming)
                FilledButton(
                  key: okKey,
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
            ],
          ),
        );
      },
    );
  }
}
